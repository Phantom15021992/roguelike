extends Node
## Кооператив (autoload «Net»): ключ, подключение, копирование мира хозяина гостям.
##
## Схема: всю игру считает компьютер хозяина (монстры, урон, боссы, состояние всех героев).
## Гости отправляют хозяину свои нажатия и видят копию мира.
##
## Подключение: хозяин регистрируется на сигнальном сервере PeerJS под именем из ключа,
## гость находит его по ключу; через сервер они обмениваются описаниями WebRTC-соединения,
## дальше данные идут напрямую между игроками (WebRTC). На ПК нужен addons/webrtc_native.
##
## Копия мира: у каждого узла в слоях Ground/Entities/FX, у которого есть метод net_props(),
## есть сетевой номер. Хозяин шлёт «появился» (сцена/скрипт + свойства), «исчез» и 20 раз
## в секунду — состояние (net_state()). Гость создаёт такие же узлы и применяет состояние
## (net_apply()); игровая логика в них при Net.is_guest() не работает.

signal status_changed(text: String)
signal players_changed
signal joined          # гость: соединение с хозяином установлено
signal left            # связь потеряна / вышли из коопа

const SIGNAL_URL := "wss://0.peerjs.com/peerjs"
const PEER_PREFIX := "rgl7-"
const KEY_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const KEY_LEN := 6
const MAX_PLAYERS := 4
const TICK := 0.05                     # 20 снимков мира в секунду
const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]}
const LAYERS := ["Ground", "Entities", "FX"]
const RUN_SCRIPT := preload("res://scripts/run.gd")

var mode := ""                         # "", "host", "guest"
var key := ""
var status := ""
## Игроки: peer_id -> {"name", "cls", "ready", "state" (у хозяина: состояние героя)}.
var players := {}

var _ws := WebSocketPeer.new()
var _ws_open := false
var _ws_id := ""
var _hb := 0.0
var _signal_url := SIGNAL_URL
var _rtc: WebRTCMultiplayerPeer
var _conns := {}                       # peer_id -> WebRTCPeerConnection
var _sig_ids := {}                     # хозяин: peer_id -> id гостя на сигнальном сервере
var _host_sig := ""                    # гость: id хозяина на сигнальном сервере

# --- Копия мира ---
var _next_nid := 1
var _nodes := {}                       # nid -> узел (у хозяина и у гостя)
var _tick_t := 0.0
var _scene_busy := false               # сцена сменяется: «исчезновения» не рассылаем
var _ready_peers := {}                 # хозяин: какие гости уже загрузили текущую сцену
var _pending_spawn: Array = []         # хозяин: узлы, появившиеся в этом кадре
var scene_data := {}                   # гость: что прислал хозяин для сцены (карта, этаж)
var _targets := {}                     # гость: nid -> целевая позиция (сглаживание)
var _map_edits: Array = []             # хозяин: изменения карты на этом этаже

# --- Ввод гостя ---
var _input_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--signal="):
			_signal_url = arg.get_slice("=", 1)
	# В браузере для проверок: index.html?signal=ws://127.0.0.1:9000/peerjs
	if OS.has_feature("web"):
		var s: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('signal') || ''")
		if typeof(s) == TYPE_STRING and s != "":
			_signal_url = s
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	get_tree().node_added.connect(_on_node_added)
	# Общие золото и материалы забега хранит Run хозяина — гости видят их в своём интерфейсе.
	Run.changed.connect(func() -> void:
		if is_host():
			send_all_states())
	Meta.changed.connect(func() -> void:
		if is_host():
			send_meta())


# ================= Режим =================

func active() -> bool:
	return mode != ""


func is_host() -> bool:
	return mode == "host"


func is_guest() -> bool:
	return mode == "guest"


func my_id() -> int:
	return multiplayer.get_unique_id() if _rtc != null else 1


func player_count() -> int:
	return players.size()


## Состояние героя игрока (у хозяина). Свой герой — Run.
func state_of(peer_id: int) -> Node:
	if peer_id == my_id() or not players.has(peer_id):
		return Run
	return players[peer_id]["state"]


## Все состояния героев (для опыта, итогов забега).
func all_states() -> Array:
	var out: Array = [Run]
	if is_host():
		for pid: int in players:
			if pid != 1:
				out.append(players[pid]["state"])
	return out


func _status(text: String) -> void:
	status = text
	status_changed.emit(text)


# ================= Создать / подключиться =================

func host_game(fixed_key := "") -> void:
	leave()
	mode = "host"
	key = fixed_key if fixed_key != "" else _make_key()
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_server()
	multiplayer.multiplayer_peer = _rtc
	players = {1: {"name": "Игрок 1", "cls": "", "ready": false}}
	_scene_busy = false
	_nodes.clear()
	_track_scene()
	_connect_signal(PEER_PREFIX + key)
	_status("Подключаемся к серверу...")
	players_changed.emit()


func join_game(join_key: String) -> void:
	leave()
	mode = "guest"
	key = join_key.strip_edges().to_upper()
	_host_sig = PEER_PREFIX + key
	_connect_signal(PEER_PREFIX + key + "-" + str(randi() % 1000000))
	_status("Ищем игру %s..." % key)


func leave() -> void:
	var was := mode
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
	_ws_open = false
	for c: WebRTCPeerConnection in _conns.values():
		c.close()
	_conns.clear()
	_sig_ids.clear()
	if _rtc:
		_rtc.close()
	_rtc = null
	multiplayer.multiplayer_peer = null
	mode = ""
	players = {}
	_nodes.clear()
	_targets.clear()
	_ready_peers.clear()
	scene_data = {}
	if was == "guest":
		Meta.restore_own()  # у гостя в коопе был лагерь хозяина — вернуть своё сохранение
	if was != "":
		left.emit()
		players_changed.emit()


func _make_key() -> String:
	var s := ""
	for i in KEY_LEN:
		s += KEY_CHARS[randi() % KEY_CHARS.length()]
	return s


func _connect_signal(my_sig_id: String) -> void:
	_ws_id = my_sig_id
	_ws = WebSocketPeer.new()
	var token := str(randi())
	var err := _ws.connect_to_url("%s?key=peerjs&id=%s&token=%s&version=1.5.4" % [_signal_url, my_sig_id, token])
	if err != OK:
		_status("Не удалось подключиться к серверу (%d)" % err)


func _sig_send(dst: String, type: String, payload: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"type": type, "dst": dst, "payload": payload}))


func _poll_signal(delta: float) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return
	_ws.poll()
	if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED and mode != "" and not _ws_open:
		_status("Сервер подключения недоступен")
		return
	_hb += delta
	if _ws_open and _hb > 5.0:
		_hb = 0.0
		_ws.send_text(JSON.stringify({"type": "HEARTBEAT"}))
	while _ws.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY:
			_on_signal(parsed)


func _on_signal(m: Dictionary) -> void:
	var type: String = m.get("type", "")
	var src: String = str(m.get("src", ""))
	var payload: Dictionary = m.get("payload", {}) if typeof(m.get("payload")) == TYPE_DICTIONARY else {}
	match type:
		"OPEN":
			_ws_open = true
			if is_host():
				_status("Игра создана. Ключ: %s" % key)
			else:
				_sig_send(_host_sig, "OFFER", {"t": "join"})
				_status("Стучимся к хозяину...")
		"ID-TAKEN":
			if is_host():
				key = _make_key()
				_connect_signal(PEER_PREFIX + key)
		"ERROR":
			_status("Ошибка сервера подключения")
		"EXPIRE":
			if is_guest():
				_status("Игра с ключом %s не найдена" % key)
		"OFFER", "ANSWER", "CANDIDATE":
			if is_host():
				_host_signal(src, payload)
			else:
				_guest_signal(payload)


# --- Хозяин: новый гость стучится, дальше обмен описаниями соединения ---
func _host_signal(src: String, p: Dictionary) -> void:
	var t: String = p.get("t", "")
	if t == "join":
		if players.size() + _conns.size() - _count_connected() >= MAX_PLAYERS:
			_sig_send(src, "ANSWER", {"t": "full"})
			return
		var pid := 2
		while players.has(pid) or _conns.has(pid):
			pid += 1
		_sig_ids[pid] = src
		var pc := _new_conn(pid, src)
		_rtc.add_peer(pc, pid)
		pc.create_offer()
		return
	var pid2 := _pid_by_sig(src)
	if pid2 == 0 or not _conns.has(pid2):
		return
	var conn: WebRTCPeerConnection = _conns[pid2]
	if t == "sdp":
		conn.set_remote_description(p["type"], p["sdp"])
	elif t == "ice":
		conn.add_ice_candidate(p["media"], int(p["index"]), p["name"])


func _count_connected() -> int:
	var n := 0
	for pid: int in _conns:
		if players.has(pid):
			n += 1
	return n


func _pid_by_sig(sig: String) -> int:
	for pid: int in _sig_ids:
		if _sig_ids[pid] == sig:
			return pid
	return 0


# --- Гость: получил номер и описание соединения от хозяина ---
func _guest_signal(p: Dictionary) -> void:
	var t: String = p.get("t", "")
	if t == "full":
		_status("В игре уже %d игрока" % MAX_PLAYERS)
		return
	if t == "sdp":
		if _rtc == null:
			_rtc = WebRTCMultiplayerPeer.new()
			_rtc.create_client(int(p["pid"]))
			multiplayer.multiplayer_peer = _rtc
			var pc := _new_conn(1, _host_sig)
			_rtc.add_peer(pc, 1)
		var conn: WebRTCPeerConnection = _conns[1]
		conn.set_remote_description(p["type"], p["sdp"])
		_status("Соединяемся...")
	elif t == "ice" and _conns.has(1):
		_conns[1].add_ice_candidate(p["media"], int(p["index"]), p["name"])


func _new_conn(pid: int, dst: String) -> WebRTCPeerConnection:
	var pc := WebRTCPeerConnection.new()
	pc.initialize(ICE)
	pc.session_description_created.connect(func(type: String, sdp: String) -> void:
		pc.set_local_description(type, sdp)
		_sig_send(dst, "OFFER" if type == "offer" else "ANSWER", {"t": "sdp", "type": type, "sdp": sdp, "pid": pid}))
	pc.ice_candidate_created.connect(func(media: String, index: int, cname: String) -> void:
		_sig_send(dst, "CANDIDATE", {"t": "ice", "media": media, "index": index, "name": cname}))
	_conns[pid] = pc
	return pc


func _on_peer_connected(pid: int) -> void:
	if is_host():
		var st: Node = RUN_SCRIPT.new()
		st.reset()
		players[pid] = {"name": "Игрок %d" % pid, "cls": "", "ready": false, "state": st}
		st.changed.connect(func() -> void: send_state(pid))
		_status("Подключился игрок %d. Игроков: %d" % [pid, players.size()])
		players_changed.emit()
		send_meta(pid)
		send_lobby()
		send_to(pid, "scene", _scene_message())
	elif pid == 1:
		_status("Подключено к игре %s" % key)
		joined.emit()


func _on_peer_disconnected(pid: int) -> void:
	if is_host():
		players.erase(pid)
		_conns.erase(pid)
		_sig_ids.erase(pid)
		_ready_peers.erase(pid)
		var hero := hero_of(pid)
		if hero:
			hero.queue_free()
		Game.banner("Игрок %d отключился" % pid)
		_status("Игроков: %d" % players.size())
		players_changed.emit()
		send_lobby()
	elif pid == 1:
		Game.banner("Связь с хозяином потеряна", 3.0)
		leave()
		Game.go_camp_offline()


# ================= Сообщения =================

@rpc("any_peer", "call_remote", "reliable")
func _r(kind: String, data: Variant) -> void:
	_on_msg(multiplayer.get_remote_sender_id(), kind, data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _u(kind: String, data: Variant) -> void:
	_on_msg(multiplayer.get_remote_sender_id(), kind, data)


func send_to(pid: int, kind: String, data: Variant, reliable := true) -> void:
	if _rtc == null or not _peer_open(pid):
		return
	if reliable:
		_r.rpc_id(pid, kind, data)
	else:
		_u.rpc_id(pid, kind, data)


## Хозяин → все гости.
func broadcast(kind: String, data: Variant, reliable := true) -> void:
	if not is_host():
		return
	for pid: int in players:
		if pid != 1:
			send_to(pid, kind, data, reliable)


## Хозяин → гости, которые уже загрузили сцену (для мира).
func _broadcast_ready(kind: String, data: Variant, reliable := true) -> void:
	for pid: int in _ready_peers:
		send_to(pid, kind, data, reliable)


func _peer_open(pid: int) -> bool:
	if _rtc == null:
		return false
	if is_guest():
		return pid == 1 and _rtc.has_peer(1) and _rtc.get_peer(1)["connected"]
	return _rtc.has_peer(pid) and _rtc.get_peer(pid)["connected"]


func _on_msg(from: int, kind: String, data: Variant) -> void:
	if is_host():
		_host_msg(from, kind, data)
	elif is_guest() and from == 1:
		_guest_msg(kind, data)


# ---------------- Хозяин принимает ----------------
func _host_msg(from: int, kind: String, data: Variant) -> void:
	if not players.has(from):
		return
	match kind:
		"ready":
			_ready_peers[from] = true
			_send_full_world(from)
			Game.on_guest_scene_ready(from)
		"input":
			var hero := hero_of(from)
			if hero:
				hero.set_remote_input(data)
		"press":
			var hero := hero_of(from)
			if hero:
				hero.press(str(data))
		"cmd":
			var st := state_of(from)
			var args: Array = data[1]
			match str(data[0]):
				"add_stat": st.add_stat(str(args[0]))
				"learn_skill": st.learn_skill(str(args[0]))
				"set_job": st.set_job(str(args[0]))
				"inv":
					var hero := hero_of(from)
					if hero:
						hero.inv(str(args[0]), args[1])
		"class":
			if typeof(data) == TYPE_DICTIONARY:
				players[from]["cls"] = str(data["cls"])
				players[from]["hero"] = data.get("hero", {})
			else:
				players[from]["cls"] = str(data)
			players[from]["ready"] = true
			players_changed.emit()
			send_lobby()
			Game.coop_try_start()
		"unready":
			players[from]["ready"] = false
			send_lobby()
		"restart":
			Game.coop_restart()


# ---------------- Гость принимает ----------------
func _guest_msg(kind: String, data: Variant) -> void:
	match kind:
		"meta":
			Meta.apply_host(data)
		"lobby":
			players = {}
			for row: Array in data:
				players[int(row[0])] = {"name": row[1], "cls": row[2], "ready": row[3]}
			players_changed.emit()
		"state":
			Run.apply_net(data)
		"scene":
			_scene_busy = true
			_nodes.clear()
			_targets.clear()
			scene_data = data
			if data.has("depth"):
				Run.depth = int(data["depth"])
			Game.guest_load_scene(str(data["kind"]))
		"spawn":
			for s: Array in data:
				_spawn_local(s)
		"despawn":
			for nid: int in data:
				if _nodes.has(nid):
					var n: Variant = _nodes[nid]
					_nodes.erase(nid)
					_targets.erase(nid)
					if is_instance_valid(n):
						n.queue_free()
		"snap":
			_apply_snapshot(data)
		"fx":
			Game.callv(str(data[0]), data[1])
		"cells":
			var scene := get_tree().current_scene
			if scene and scene.has_method("apply_cells"):
				scene.apply_cells(data)
		"ui":
			Game.guest_ui(data)
		"hero_save":
			Meta.save_hero(data)
		"hero_best":
			Meta.own_hero_best(int(data))


## Сцена начинает меняться: «исчезновения» старых узлов не рассылаем.
func scene_leaving() -> void:
	_scene_busy = true
	_pending_spawn.clear()


## Сцена загружена: гость просит мир у хозяина, хозяин начинает следить за слоями.
func scene_loaded() -> void:
	if is_guest():
		_scene_busy = false
		send_to(1, "ready", true)
	elif is_host():
		_scene_busy = false
		_ready_peers.clear()
		_map_edits.clear()
		_nodes.clear()
		_track_scene()
		host_scene_changed()


## Хозяин: что прислать гостям о текущей сцене.
func _scene_message() -> Dictionary:
	var scene := get_tree().current_scene
	if scene and scene.has_method("net_scene"):
		return scene.net_scene()
	return {"kind": "camp"}


## Хозяин: сцена сменилась — разослать гостям.
func host_scene_changed() -> void:
	broadcast("scene", _scene_message())


func send_meta(pid := 0) -> void:
	if not is_host():
		return
	var d := Meta.net_dict()
	if pid != 0:
		send_to(pid, "meta", d)
	else:
		broadcast("meta", d)


func send_lobby() -> void:
	var rows: Array = []
	for pid: int in players:
		rows.append([pid, players[pid]["name"], players[pid]["cls"], players[pid]["ready"]])
	broadcast("lobby", rows)


## Хозяин → гость: его герой (уровень, статы, навыки, снаряжение) + общие золото и материалы.
func send_state(pid: int) -> void:
	if is_host() and players.has(pid) and pid != 1:
		send_to(pid, "state", players[pid]["state"].net_dict())


## Хозяин: общие золото/материалы изменились — всем.
func send_all_states() -> void:
	for pid: int in players:
		if pid != 1:
			send_state(pid)


## Гость: изменение героя просит у хозяина (add_stat, learn_skill, set_job).
func cmd(method: String, args: Array) -> void:
	send_to(1, "cmd", [method, args])


## Изменение карты (ворота арены, лестница) — хозяин запоминает и рассылает.
func map_cells(cells: Array) -> void:
	if not is_host():
		return
	_map_edits.append_array(cells)
	_broadcast_ready("cells", cells)


## Эффект (вспышка, цифра урона, надпись) — повторить у гостей.
func fx(fname: String, args: Array) -> void:
	if is_host() and not _ready_peers.is_empty():
		_broadcast_ready("fx", [fname, args])


# ================= Копия мира: хозяин =================

func _track_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for layer_name: String in LAYERS:
		var layer := scene.get_node_or_null(layer_name)
		if layer:
			for c in layer.get_children():
				_register(c)


func _on_node_added(n: Node) -> void:
	if not is_host() or _scene_busy:
		return
	var parent := n.get_parent()
	if parent == null or not (String(parent.name) in LAYERS) or parent.get_parent() != get_tree().current_scene:
		return
	_register(n)
	if n.has_meta("nid"):
		_pending_spawn.append(n)


func _register(n: Node) -> void:
	if n.has_meta("nid") or not n.has_method("net_props"):
		return
	var nid := _next_nid
	_next_nid += 1
	n.set_meta("nid", nid)
	_nodes[nid] = n
	n.tree_exiting.connect(func() -> void:
		_nodes.erase(nid)
		if is_host() and not _scene_busy and not _ready_peers.is_empty():
			_broadcast_ready("despawn", [nid]))


func _spawn_record(n: Node) -> Array:
	var path: String = n.scene_file_path
	if path == "":
		path = (n.get_script() as Script).resource_path
	var props := {}
	for p: String in n.net_props():
		props[p] = n.get(p)
	return [n.get_meta("nid"), path, String(n.get_parent().name), props, n.position, n.rotation, n.scale]


func _send_full_world(pid: int) -> void:
	var batch: Array = []
	for nid: int in _nodes:
		var n: Variant = _nodes[nid]
		if is_instance_valid(n) and n.is_inside_tree():
			batch.append(_spawn_record(n))
			if batch.size() >= 40:
				send_to(pid, "spawn", batch)
				batch = []
	if not batch.is_empty():
		send_to(pid, "spawn", batch)
	if not _map_edits.is_empty():
		send_to(pid, "cells", _map_edits)


func _flush_spawns() -> void:
	if _pending_spawn.is_empty():
		return
	var batch: Array = []
	for n: Node in _pending_spawn:
		if is_instance_valid(n) and n.is_inside_tree():
			batch.append(_spawn_record(n))
	_pending_spawn.clear()
	if not batch.is_empty() and not _ready_peers.is_empty():
		_broadcast_ready("spawn", batch)


func _send_snapshot() -> void:
	if _ready_peers.is_empty():
		return
	var snap: Array = []
	for nid: int in _nodes:
		var n: Variant = _nodes[nid]
		if is_instance_valid(n) and n.has_method("net_state"):
			snap.append([nid, n.position, n.net_state()])
	if not snap.is_empty():
		_broadcast_ready("snap", snap, false)


# ================= Копия мира: гость =================

func _spawn_local(s: Array) -> void:
	var nid: int = s[0]
	if _nodes.has(nid):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var layer := scene.get_node_or_null(str(s[2]))
	if layer == null:
		return
	var path: String = s[1]
	var n: Node
	if path.ends_with(".tscn"):
		n = (load(path) as PackedScene).instantiate()
	else:
		n = (load(path) as Script).new()
	var props: Dictionary = s[3]
	for p: String in props:
		n.set(p, props[p])
	n.position = s[4]
	n.rotation = s[5]
	n.scale = s[6]
	n.set_meta("nid", nid)
	_nodes[nid] = n
	layer.add_child(n)


func _apply_snapshot(snap: Array) -> void:
	for row: Array in snap:
		var nid: int = row[0]
		if not _nodes.has(nid):
			continue
		var n: Variant = _nodes[nid]
		if not is_instance_valid(n):
			continue
		_targets[nid] = row[1]
		n.net_apply(row[2])


## Гость: плавно подтягивает узлы к позициям из снимков.
func _smooth(delta: float) -> void:
	var k := minf(1.0, delta * 18.0)
	for nid: int in _targets:
		var n: Variant = _nodes.get(nid)
		if not is_instance_valid(n):
			continue
		var target: Vector2 = _targets[nid]
		if n.position.distance_to(target) > 48.0:
			n.position = target  # телепорт / рывок — без размазывания
		else:
			n.position = n.position.lerp(target, k)


## Гость: свой герой (копия), чтобы камера и интерфейс знали, за кем следить.
func hero_of(pid: int) -> Node:
	for h in get_tree().get_nodes_in_group("player"):
		if h.peer_id == pid:
			return h
	return null


# ================= Каждый кадр =================

func _process(delta: float) -> void:
	_poll_signal(delta)
	if is_host():
		_flush_spawns()
		_tick_t += delta
		if _tick_t >= TICK:
			_tick_t = 0.0
			_send_snapshot()
	elif is_guest():
		_smooth(delta)
		_input_t += delta
		if _input_t >= 1.0 / 30.0:
			_input_t = 0.0
			_send_input()


## Гость: каждые 1/30 с — что зажато и куда смотрит мышь.
func _send_input() -> void:
	if _rtc == null or not _peer_open(1) or _scene_busy:
		return
	var hero := hero_of(my_id())
	var mouse := Vector2.ZERO
	if hero:
		mouse = hero.get_global_mouse_position()
	var blocked := Game.ui_blocks_input()
	send_to(1, "input", {
		"m": Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"a": not blocked and Input.is_action_pressed("attack"),
		"am": not blocked and Input.is_action_pressed("attack_mouse"),
		"mp": mouse,
		"mr": Game.mouse_recent(),
	}, false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_guest() or _scene_busy or Game.ui_blocks_input():
		return
	for action: String in ["skill_1", "skill_2", "skill_3", "interact"]:
		if event.is_action_pressed(action, false):
			send_to(1, "press", action)


# ================= Помощники для net_state() =================

## Анимированный спрайт: [анимация, кадр, отражение, цвет, масштаб, поворот, видимость, смещение, вспышка].
static func pack_sprite(s: AnimatedSprite2D) -> Array:
	var flash := 0.0
	if s.material is ShaderMaterial:
		flash = float((s.material as ShaderMaterial).get_shader_parameter("flash"))
	return [String(s.animation), s.frame, s.flip_h, s.modulate, s.scale, s.rotation, s.visible, s.position, flash]


static func unpack_sprite(s: AnimatedSprite2D, a: Array) -> void:
	var anim := StringName(a[0])
	if s.sprite_frames and s.sprite_frames.has_animation(anim):
		if s.animation != anim:
			s.play(anim)
		s.frame = int(a[1])
	s.flip_h = a[2]
	s.modulate = a[3]
	s.scale = a[4]
	s.rotation = a[5]
	s.visible = a[6]
	s.position = a[7]
	if s.material is ShaderMaterial:
		(s.material as ShaderMaterial).set_shader_parameter("flash", a[8])

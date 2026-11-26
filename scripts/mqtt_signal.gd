extends RefCounted
## Поиск игроков по ключу: «почтовые ящики» на открытых MQTT-серверах (через WebSocket).
## Подключаемся сразу к нескольким серверам: сообщение шлём во все, принимаем из любого,
## повторы отбрасываем по номеру сообщения (mid). Так игра работает, даже если какой-то сервер
## недоступен (у провайдера, в стране) или упал.
## Через сервер идёт только знакомство (описания WebRTC-соединения), сама игра — напрямую.

signal opened                      # подписались хотя бы на одном сервере
signal received(m: Dictionary)     # пришло сообщение в мой ящик

const BROKERS := [
	"wss://broker.emqx.io:8084/mqtt",
	"wss://broker.hivemq.com:8884/mqtt",
	"wss://test.mosquitto.org:8081/mqtt",
]
const KEEPALIVE := 50

var _conns: Array = []             # [{ws, url, state, buf}]
var _inbox := ""
var _seen := {}
var _open := false
var _ping_t := 0.0


## Подключиться ко всем серверам и слушать ящик my_topic.
func start(my_topic: String, urls: Array = BROKERS) -> void:
	close()
	_inbox = my_topic
	for url: String in urls:
		var ws := WebSocketPeer.new()
		ws.supported_protocols = PackedStringArray(["mqtt"])
		ws.inbound_buffer_size = 1 << 20
		ws.outbound_buffer_size = 1 << 20
		if ws.connect_to_url(url) == OK:
			_conns.append({"ws": ws, "url": url, "state": "connecting", "buf": PackedByteArray()})


func close() -> void:
	for c: Dictionary in _conns:
		var ws: WebSocketPeer = c["ws"]
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send(PackedByteArray([0xE0, 0x00]), WebSocketPeer.WRITE_MODE_BINARY)  # DISCONNECT
		ws.close()
	_conns.clear()
	_open = false
	_seen.clear()


func is_open() -> bool:
	return _open


## Сколько серверов сейчас на связи (для строки состояния).
func live_count() -> int:
	var n := 0
	for c: Dictionary in _conns:
		if c["state"] == "ready":
			n += 1
	return n


## Все серверы недоступны (проверили и закрылись).
func all_failed() -> bool:
	if _conns.is_empty():
		return true
	for c: Dictionary in _conns:
		if c["state"] != "dead":
			return false
	return true


## Отправить в ящик topic (через все серверы).
func send(topic: String, data: Dictionary) -> void:
	data["mid"] = "%08x%08x" % [randi(), randi()]
	var payload := JSON.stringify(data).to_utf8_buffer()
	var body := _str(topic)
	body.append_array(payload)
	var p := _packet(0x30, body)
	for c: Dictionary in _conns:
		if c["state"] == "ready":
			c["ws"].send(p, WebSocketPeer.WRITE_MODE_BINARY)


func poll(delta: float) -> void:
	_ping_t += delta
	var ping := _ping_t > 25.0
	if ping:
		_ping_t = 0.0
	for c: Dictionary in _conns:
		var ws: WebSocketPeer = c["ws"]
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_CLOSED:
			c["state"] = "dead"
			continue
		if st != WebSocketPeer.STATE_OPEN:
			continue
		if c["state"] == "connecting":
			c["state"] = "hello"
			var body := _str("MQTT")
			body.append_array(PackedByteArray([4, 2, KEEPALIVE >> 8, KEEPALIVE & 255]))
			body.append_array(_str("rgl%08x" % randi()))
			ws.send(_packet(0x10, body), WebSocketPeer.WRITE_MODE_BINARY)  # CONNECT
		if ping and c["state"] == "ready":
			ws.send(PackedByteArray([0xC0, 0x00]), WebSocketPeer.WRITE_MODE_BINARY)  # PINGREQ
		while ws.get_available_packet_count() > 0:
			var buf: PackedByteArray = c["buf"]
			buf.append_array(ws.get_packet())
			c["buf"] = buf
		_parse(c)


func _parse(c: Dictionary) -> void:
	var b: PackedByteArray = c["buf"]
	while b.size() >= 2:
		# Длина пакета: 1–4 байта по 7 бит.
		var n := 0
		var mul := 1
		var i := 1
		while true:
			if i >= b.size():
				return
			n += (b[i] & 127) * mul
			mul *= 128
			i += 1
			if b[i - 1] & 128 == 0:
				break
		if b.size() < i + n:
			return
		var body := b.slice(i, i + n)
		_on_packet(c, b[0], body)
		b = b.slice(i + n)
	c["buf"] = b


func _on_packet(c: Dictionary, head: int, body: PackedByteArray) -> void:
	match head >> 4:
		2:  # CONNACK
			if body.size() >= 2 and body[1] == 0:
				var sub := PackedByteArray([0, 1])
				sub.append_array(_str(_inbox))
				sub.append(0)
				c["ws"].send(_packet(0x82, sub), WebSocketPeer.WRITE_MODE_BINARY)  # SUBSCRIBE
			else:
				c["ws"].close()
		9:  # SUBACK
			c["state"] = "ready"
			if not _open:
				_open = true
				opened.emit()
		3:  # PUBLISH
			if body.size() < 2:
				return
			var tl := (body[0] << 8) | body[1]
			var off := 2 + tl
			if (head >> 1) & 3 > 0:
				off += 2  # номер пакета (QoS 1/2)
			var text := body.slice(off).get_string_from_utf8()
			var m: Variant = JSON.parse_string(text)
			if typeof(m) != TYPE_DICTIONARY:
				return
			var mid := str(m.get("mid", ""))
			if mid != "":
				if _seen.has(mid):
					return  # то же сообщение через другой сервер
				_seen[mid] = true
			received.emit(m)


func _str(s: String) -> PackedByteArray:
	var u := s.to_utf8_buffer()
	var out := PackedByteArray([u.size() >> 8, u.size() & 255])
	out.append_array(u)
	return out


func _packet(type: int, body: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([type])
	var n := body.size()
	while true:
		var d := n % 128
		n = n / 128
		if n > 0:
			d |= 128
		out.append(d)
		if n == 0:
			break
	out.append_array(body)
	return out

// Генератор блоков этажей (data/blocks.txt) по формам комнат из модульных наборов-референсов
// владельца: скошенные и скруглённые залы, круглые, крестовые, восьмиугольные, клеверные,
// ромб, капсула, L-зал; коридоры — прямые, с расширением, дугой, Т и крест.
// Правило владельца: внутри комнат НИКАКИХ стен — максимум колонны.
//   node tools/gen_blocks.js
const fs = require("fs");
const N = 15, C = 7;                      // блок 15x15, центр (7,7)
const DOORS = { N: [[6, 0], [7, 0], [8, 0]], S: [[6, 14], [7, 14], [8, 14]], W: [[0, 6], [0, 7], [0, 8]], E: [[14, 6], [14, 7], [14, 8]] };

let seed = 1;
const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;

// shape(dx, dy) — пол ли клетка (dx, dy от центра). doors — какие проходы у блока.
function block(name, tag, shape, doors = "NSWE", opts = {}) {
  const g = [];
  for (let y = 0; y < N; y++) {
    const row = [];
    for (let x = 0; x < N; x++) {
      const edge = x === 0 || y === 0 || x === N - 1 || y === N - 1;
      row.push(!edge && shape(x - C, y - C) ? "." : "#");
    }
    g.push(row);
  }
  // Проходы: от края к центру полосой 3 клетки, пока не упрёмся в пол комнаты.
  for (const d of doors) {
    for (const [x, y] of DOORS[d]) g[y][x] = "D";
    const step = { N: [0, 1], S: [0, -1], W: [1, 0], E: [-1, 0] }[d];
    for (const [sx, sy] of DOORS[d]) {
      let x = sx + step[0], y = sy + step[1], depth = 0;
      while (depth++ < 7 && x > 0 && y > 0 && x < N - 1 && y < N - 1 && g[y][x] === "#" && !(Math.abs(x - C) <= 1 && Math.abs(y - C) <= 1 && opts.stopCenter)) {
        g[y][x] = "."; x += step[0]; y += step[1];
      }
    }
  }
  // Колонны (только отдельные столбы, не стены).
  for (const e of opts.cols || []) {
    const cells = typeof e[0] === "number" ? [e] : e;   // одна клетка [x, y] или группа клеток
    for (const [x, y] of cells) if (g[y][x] === ".") g[y][x] = "#";
  }
  // Особые клетки: старт, лестница, наковальня — в центре.
  if (opts.mark) g[C][C] = opts.mark;
  // Места монстров: 3–5 клеток пола подальше от проходов.
  if (tag !== "start") {
    const cand = [];
    for (let y = 2; y < N - 2; y++) for (let x = 2; x < N - 2; x++)
      if (g[y][x] === "." && (Math.abs(x - C) > 1 || Math.abs(y - C) > 1)) cand.push([x, y]);
    const n = tag === "corridor" ? 2 : 4;
    for (let i = 0; i < n && cand.length; i++) { const k = Math.floor(rnd() * cand.length); const [x, y] = cand.splice(k, 1)[0]; g[y][x] = "M"; }
  }
  return `= ${name} ${tag}\n` + g.map((r) => r.join("")).join("\n") + "\n";
}

// Помощники форм.
const rect = (w, h) => (dx, dy) => Math.abs(dx) <= w && Math.abs(dy) <= h;
const chamfer = (w, h, c) => (dx, dy) => Math.abs(dx) <= w && Math.abs(dy) <= h && Math.abs(dx) + Math.abs(dy) <= w + h - c;
const round = (r) => (dx, dy) => dx * dx + dy * dy <= r * r;
const rrect = (w, h, r) => (dx, dy) => {                 // прямоугольник со скруглёнными углами
  const ax = Math.abs(dx), ay = Math.abs(dy);
  if (ax > w || ay > h) return false;
  if (ax > w - r && ay > h - r) return (ax - (w - r)) ** 2 + (ay - (h - r)) ** 2 <= r * r + 0.5;
  return true;
};
const union = (...fs) => (dx, dy) => fs.some((f) => f(dx, dy));
const minus = (a, b) => (dx, dy) => a(dx, dy) && !b(dx, dy);
const shift = (f, ox, oy) => (dx, dy) => f(dx - ox, dy - oy);
const sym = (pts) => { const out = []; for (const [x, y] of pts) for (const [sx, sy] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) out.push([C + x * sx, C + y * sy]); return out; };
const col2 = (x, y) => [[[x, y], [x + 1, y], [x, y + 1], [x + 1, y + 1]]];      // колонна 2x2

const out = [];
out.push(`; Блоки, из которых собираются этажи подземелья (как в Albion Online).
; Сгенерировано tools/gen_blocks.js по формам модульных наборов (референсы владельца) —
; правьте генератор, а не этот файл. Внутри комнат стен нет, только колонны.
;
; Каждый блок — квадрат 15x15 клеток. Заголовок: "= имя тег".
;   теги: start — стартовая комната, exit — комната с лестницей, forge — с наковальней,
;         room — обычная комната, corridor — коридор (в нём меньше монстров).
;
; Символы:
;   #  стена/колонна  .  пол
;   D  проход — только на краях, ровно в клетках 6–8 (середина стороны).
;      Если сосед с этой стороны не нужен, проход замуровывается.
;   M  место для монстра      P  старт героя      S  лестница вниз
;   A  наковальня (заточка снаряжения) — только в блоках с тегом forge
;
; Генератор этажа сам поворачивает и отражает блоки (до 8 вариантов из одного).
`);
seed = 3;
// --- особые ---
out.push(block("start_round", "start", round(5.6), "NSWE", { mark: "P" }));
out.push(block("start_octagon", "start", chamfer(5, 5, 3), "NSWE", { mark: "P" }));
out.push(block("exit_octagon", "exit", chamfer(6, 6, 4), "NSWE", { mark: "S", cols: sym([[3, 3]]) }));
out.push(block("exit_round", "exit", round(6.2), "NSWE", { mark: "S" }));
out.push(block("forge_hall", "forge", rrect(6, 5, 2), "NSWE", { mark: "A", cols: sym([[4, 3]]) }));
out.push(block("forge_round", "forge", round(6.0), "NSWE", { mark: "A" }));
// --- залы (все с четырьмя проходами — подходят куда угодно) ---
out.push(block("hall_chamfer", "room", chamfer(6, 6, 3), "NSWE"));
out.push(block("hall_pillars", "room", chamfer(6, 6, 3), "NSWE", { cols: sym([[3, 3]]) }));
out.push(block("hall_big_pillars", "room", rrect(6, 6, 2), "NSWE", { cols: [...col2(3, 3), ...col2(10, 3), ...col2(3, 10), ...col2(10, 10)] }));
out.push(block("hall_rounded", "room", rrect(6, 5, 3), "NSWE"));
out.push(block("hall_long", "room", rrect(6, 4, 2), "NSWE", { cols: [[3, 7], [7, 7], [11, 7]].map(([x, y]) => [x, y]) }));
out.push(block("round_room", "room", round(6.3), "NSWE"));
out.push(block("round_pillar", "room", round(6.3), "NSWE", { cols: [[[6, 6], [7, 6], [8, 6], [6, 7], [7, 7], [8, 7], [6, 8], [7, 8], [8, 8]]] }));
out.push(block("round_ring", "room", round(6.3), "NSWE", { cols: sym([[2, 4], [4, 2]]) }));
out.push(block("octagon", "room", chamfer(6, 6, 5), "NSWE"));
out.push(block("cross_room", "room", union(rect(6, 2), rect(2, 6), round(3.5)), "NSWE"));
out.push(block("cross_wide", "room", union(rect(6, 3), rect(3, 6)), "NSWE", { cols: sym([[2, 2]]) }));
out.push(block("clover", "room", union(shift(round(2.9), 4, 0), shift(round(2.9), -4, 0), shift(round(2.9), 0, 4), shift(round(2.9), 0, -4), round(2.2)), "NSWE"));
out.push(block("diamond", "room", (dx, dy) => Math.abs(dx) + Math.abs(dy) <= 7, "NSWE"));
out.push(block("capsule", "room", union(rect(3, 3.5), shift(round(3.6), 3, 0), shift(round(3.6), -3, 0)), "NSWE"));
out.push(block("twin_rounds", "room", union(shift(round(3.8), -3, -3), shift(round(3.8), 3, 3), rect(1, 6), rect(6, 1)), "NSWE"));
out.push(block("l_hall", "room", minus(rrect(6, 6, 2), (dx, dy) => dx >= 2 && dy <= -2), "NSWE"));
out.push(block("t_hall", "room", union(rrect(6, 3, 2), rect(3, 6)), "NSWE", { cols: [[4, 6], [10, 6]] }));
out.push(block("alcoves", "room", union(rect(4, 4), rect(6, 2), rect(2, 6), shift(rect(1, 1), 5, 4), shift(rect(1, 1), -5, 4), shift(rect(1, 1), 5, -4), shift(rect(1, 1), -5, -4)), "NSWE"));
// --- коридоры ---
out.push(block("corridor_straight", "corridor", rect(1, 7), "NS"));
out.push(block("corridor_bulge", "corridor", union(rect(1, 7), round(3.2)), "NS"));
out.push(block("corridor_pillars", "corridor", rect(2, 7), "NS", { cols: [[5, 4], [9, 4], [5, 10], [9, 10]] }));
out.push(block("corridor_arc", "corridor", (dx, dy) => { const d = Math.hypot(dx - 7.5, dy + 7.5); return d >= 5.2 && d <= 9.2; }, "NE"));
out.push(block("corridor_chamfer", "corridor", union((dx, dy) => dx >= -1 && dx <= 1 && dy <= 0, (dx, dy) => dy >= -1 && dy <= 1 && dx >= 0, (dx, dy) => dx >= -1 && dy <= 1 && dx - dy <= 3 && dy >= -3 && dx <= 3), "NE"));
out.push(block("corridor_t", "corridor", union(rect(7, 1), (dx, dy) => Math.abs(dx) <= 1 && dy >= 0, round(2.6)), "WES"));
out.push(block("corridor_cross", "corridor", union(rect(7, 1), rect(1, 7), chamfer(3, 3, 2)), "NSWE"));
fs.writeFileSync("data/blocks.txt", out.join("\n"));
console.log("blocks:", out.length - 1);

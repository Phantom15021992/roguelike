// Концепты векторной графики (по референсам владельца): кристальная пещера + рыцарь-чиби с 8 сторон.
//   node tools/vector_concepts.js   → concepts/hero_8dirs.svg, concepts/cave_scene.svg
// Это только картинки для обсуждения стиля, в игру не подключены.
const fs = require("fs");

// ---------------- общие кусочки ----------------
let seed = 7;
function rnd() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }
function r(a, b) { return a + (b - a) * rnd(); }
const OUT = "#1b1726";   // цвет обводки
const f = (n) => n.toFixed(1);

function defs() {
  return `<defs>
  <linearGradient id="steel" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#eef3fb"/><stop offset="0.5" stop-color="#b5c0d6"/><stop offset="1" stop-color="#6d7792"/></linearGradient>
  <linearGradient id="steelBack" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#c9d2e4"/><stop offset="1" stop-color="#5f6984"/></linearGradient>
  <linearGradient id="tabard" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4f79d6"/><stop offset="1" stop-color="#28407e"/></linearGradient>
  <linearGradient id="shield" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5d8ae8"/><stop offset="1" stop-color="#22356f"/></linearGradient>
  <linearGradient id="wood" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9a6a3e"/><stop offset="1" stop-color="#5a3a22"/></linearGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe7a0"/><stop offset="1" stop-color="#c58b2a"/></linearGradient>
  <linearGradient id="blade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffffff"/><stop offset="0.5" stop-color="#d7e1f0"/><stop offset="1" stop-color="#8b97b3"/></linearGradient>
  <linearGradient id="hair" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#b4703c"/><stop offset="1" stop-color="#6b3a1c"/></linearGradient>
  <radialGradient id="skin" cx="0.4" cy="0.35" r="0.8"><stop offset="0" stop-color="#ffe4cc"/><stop offset="1" stop-color="#e9b48e"/></radialGradient>
  <linearGradient id="boot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a4e2c"/><stop offset="1" stop-color="#3f2716"/></linearGradient>
  <radialGradient id="shadow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#000" stop-opacity="0.45"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  <!-- пещера -->
  <linearGradient id="slabA" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7d83b8"/><stop offset="1" stop-color="#4b4f7c"/></linearGradient>
  <linearGradient id="slabB" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8573b0"/><stop offset="1" stop-color="#4a3f72"/></linearGradient>
  <linearGradient id="slabC" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5f8fa6"/><stop offset="1" stop-color="#33506a"/></linearGradient>
  <linearGradient id="cliff" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7680b4"/><stop offset="0.12" stop-color="#4d5383"/><stop offset="1" stop-color="#151428"/></linearGradient>
  <linearGradient id="rockTop" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3a3d63"/><stop offset="1" stop-color="#161529"/></linearGradient>
  <linearGradient id="crystal" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#3fa9d8"/><stop offset="0.6" stop-color="#8fe9ff"/><stop offset="1" stop-color="#ffffff"/></linearGradient>
  <linearGradient id="crystalSide" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#1d6c9c"/><stop offset="1" stop-color="#6fd3f5"/></linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#8ff0ff" stop-opacity="0.75"/><stop offset="0.4" stop-color="#4cc4f0" stop-opacity="0.28"/><stop offset="1" stop-color="#2a80c0" stop-opacity="0"/></radialGradient>
  <radialGradient id="warm" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffe2b0" stop-opacity="0.5"/><stop offset="1" stop-color="#ffb070" stop-opacity="0"/></radialGradient>
  <linearGradient id="fungus" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffc06a"/><stop offset="0.5" stop-color="#e5762a"/><stop offset="1" stop-color="#8e3a12"/></linearGradient>
  <radialGradient id="vignette" cx="0.5" cy="0.47" r="0.72"><stop offset="0.45" stop-color="#05040c" stop-opacity="0"/><stop offset="1" stop-color="#05040c" stop-opacity="0.88"/></radialGradient>
  <filter id="blur6"><feGaussianBlur stdDeviation="6"/></filter>
</defs>`;
}

// ---------------- рыцарь-чиби ----------------
// dir: 0 вниз (лицом к нам), 1 вниз-вбок, 2 вбок, 3 вверх-вбок, 4 вверх (спиной). Смотрит вправо;
// влево — зеркально. Рост ~150 у.е., ступни в (0,0).
function knight(dir) {
  const front = dir <= 1, back = dir >= 3, side = dir === 2;
  const sh = [0, 7, 12, 7, 0][dir];               // смещение лица вправо
  const s = `stroke="${OUT}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"`;
  let g = "";
  g += `<ellipse cx="0" cy="-2" rx="34" ry="9" fill="url(#shadow)"/>`;
  // задний план: со спины щит на левой руке (слева на экране)
  if (back) {
    g += `<path d="M-46 -78 Q-46 -92 -30 -92 Q-14 -92 -14 -78 L-16 -50 Q-30 -36 -44 -50 Z" fill="url(#wood)" ${s}/>`;
    g += `<path d="M-30 -88 L-30 -44" stroke="#3b2414" stroke-width="2.5"/>`;
    g += `<path d="M30 -118 L36 -120 L38 -60 L32 -58 Z" fill="url(#blade)" ${s}/>`;
    g += `<rect x="24" y="-62" width="20" height="6" rx="3" fill="url(#gold)" ${s}/>`;
  }
  // ноги
  if (side) {
    g += `<path d="M-10 -38 L-10 -6 Q-10 0 0 0 L10 0 Q14 -6 6 -8 L6 -38 Z" fill="url(#boot)" ${s}/>`;
    g += `<path d="M4 -38 L4 -4 Q4 0 14 0 L22 0 Q26 -6 18 -8 L18 -38 Z" fill="url(#boot)" ${s}/>`;
  } else {
    g += `<path d="M-20 -38 L-20 -6 Q-20 0 -10 0 L-4 0 L-4 -38 Z" fill="url(#boot)" ${s}/>`;
    g += `<path d="M4 -38 L4 0 L12 0 Q20 0 20 -6 L20 -38 Z" fill="url(#boot)" ${s}/>`;
  }
  // корпус в латах
  const bw = side ? 26 : 34;
  g += `<path d="M${-bw} -88 Q${-bw - 2} -40 ${-bw + 4} -36 L${bw - 4} -36 Q${bw + 2} -40 ${bw} -88 Q0 -98 ${-bw} -88 Z" fill="url(#${back ? "steelBack" : "steel"})" ${s}/>`;
  if (front) g += `<path d="M${-10 + sh * 0.6} -86 L${10 + sh * 0.6} -86 L${12 + sh * 0.6} -40 L${-12 + sh * 0.6} -40 Z" fill="url(#tabard)" ${s}/>`;
  if (back) g += `<path d="M-22 -86 Q0 -80 22 -86 L26 -40 Q0 -34 -26 -40 Z" fill="#3b4f8f" opacity="0.85" ${s}/>`; // плащ
  g += `<rect x="${-bw + 1}" y="-50" width="${bw * 2 - 2}" height="8" rx="3" fill="#5b3a22" ${s}/>`;
  g += `<rect x="${-5 + sh * 0.5}" y="-51" width="10" height="10" rx="2" fill="url(#gold)" ${s}/>`;
  // наплечники
  if (side) g += `<ellipse cx="-2" cy="-86" rx="17" ry="12" fill="url(#steel)" ${s}/>`;
  else { g += `<ellipse cx="-32" cy="-86" rx="15" ry="11" fill="url(#steel)" ${s}/><ellipse cx="32" cy="-86" rx="15" ry="11" fill="url(#steel)" ${s}/>`; }
  // голова (чиби — крупная)
  const hx = sh * 0.5, hy = -128;
  g += `<ellipse cx="${hx}" cy="${hy}" rx="40" ry="37" fill="url(#hair)" ${s}/>`;
  if (!back || dir === 3) {
    if (dir !== 4) {
      const fx = hx + [0, 8, 16, 26, 0][dir];
      const fw = [29, 25, 19, 6, 0][dir];
      if (dir <= 2) {
        g += `<ellipse cx="${fx}" cy="${hy + 10}" rx="${fw}" ry="24" fill="url(#skin)" ${s}/>`;
        // чёлка
        g += `<path d="M${hx - 38} ${hy - 4} Q${hx - 30} ${hy - 30} ${hx} ${hy - 34} Q${hx + 32} ${hy - 32} ${hx + 38 + sh * 0.3} ${hy - 2} Q${hx + 22} ${hy - 14} ${hx + 12} ${hy - 6} Q${hx + 4} ${hy - 18} ${hx - 8} ${hy - 8} Q${hx - 20} ${hy - 18} ${hx - 38} ${hy - 4} Z" fill="url(#hair)" ${s}/>`;
        const eyes = dir === 0 ? [fx - 11, fx + 11] : dir === 1 ? [fx - 6, fx + 12] : [fx + 8];
        for (const ex of eyes) {
          g += `<ellipse cx="${ex}" cy="${hy + 8}" rx="4.2" ry="6" fill="#2a1f3a"/>`;
          g += `<circle cx="${ex + 1.3}" cy="${hy + 5.5}" r="1.8" fill="#fff"/>`;
        }
        g += `<path d="M${fx - 3 + (dir ? 4 : 0)} ${hy + 22} Q${fx + (dir ? 4 : 0)} ${hy + 25} ${fx + 3 + (dir ? 4 : 0)} ${hy + 22}" stroke="#a0604a" stroke-width="2" fill="none"/>`;
        g += `<ellipse cx="${fx - 16 + (dir ? 6 : 0)}" cy="${hy + 17}" rx="5" ry="3" fill="#ff9c8c" opacity="0.55"/>`;
        if (dir === 0) g += `<ellipse cx="${fx + 16}" cy="${hy + 17}" rx="5" ry="3" fill="#ff9c8c" opacity="0.55"/>`;
      } else {
        g += `<ellipse cx="${fx}" cy="${hy + 12}" rx="${fw}" ry="12" fill="url(#skin)" ${s}/>`; // краешек щеки
      }
    }
  }
  g += `<path d="M${hx - 22} ${hy - 26} Q${hx - 4} ${hy - 38} ${hx + 14} ${hy - 30}" stroke="#d9925a" stroke-width="5" fill="none" stroke-linecap="round"/>`; // блик на волосах
  // передний план: щит и меч
  if (dir === 0) {
    g += `<path d="M38 -96 Q60 -96 66 -88 L64 -58 Q58 -40 50 -34 Q42 -40 36 -58 L34 -88 Q36 -96 38 -96 Z" fill="url(#shield)" ${s}/>`;
    g += `<path d="M50 -92 L50 -40 M38 -72 L62 -72" stroke="url(#gold)" stroke-width="6"/>`;
    g += `<path d="M37 -94 Q50 -100 64 -92" stroke="url(#gold)" stroke-width="4" fill="none"/>`;
    g += `<path d="M-50 -132 L-44 -138 L-38 -132 L-38 -66 L-50 -66 Z" fill="url(#blade)" ${s}/>`;
    g += `<rect x="-58" y="-68" width="28" height="7" rx="3" fill="url(#gold)" ${s}/>`;
    g += `<rect x="-48" y="-61" width="8" height="16" rx="3" fill="#5b3a22" ${s}/>`;
  } else if (dir === 1) {
    g += `<path d="M-46 -94 Q-26 -98 -18 -90 L-20 -58 Q-28 -40 -36 -36 Q-46 -42 -50 -60 L-52 -88 Z" fill="url(#shield)" ${s}/>`;
    g += `<path d="M-34 -92 L-34 -40" stroke="url(#gold)" stroke-width="6"/>`;
    g += `<path d="M44 -130 L50 -136 L56 -130 L56 -64 L44 -64 Z" fill="url(#blade)" ${s}/>`;
    g += `<rect x="36" y="-66" width="28" height="7" rx="3" fill="url(#gold)" ${s}/>`;
  } else if (side) {
    g += `<path d="M-18 -96 Q4 -100 12 -92 L10 -60 Q2 -42 -6 -38 Q-16 -44 -20 -62 L-22 -88 Z" fill="url(#shield)" ${s}/>`;
    g += `<path d="M-6 -94 L-6 -42 M-20 -70 L10 -70" stroke="url(#gold)" stroke-width="5"/>`;
    g += `<path d="M22 -66 L84 -84 L88 -78 L26 -58 Z" fill="url(#blade)" ${s}/>`;
    g += `<rect x="12" y="-70" width="8" height="24" rx="3" fill="url(#gold)" ${s} transform="rotate(-16 16 -58)"/>`;
  } else if (dir === 3) {
    g += `<path d="M36 -118 L42 -120 L44 -62 L38 -60 Z" fill="url(#blade)" ${s}/>`;
  }
  return g;
}

function heroSheet() {
  const names = ["вниз", "вниз-вправо", "вправо", "вверх-вправо", "вверх", "вверх-влево", "влево", "вниз-влево"];
  const map = [[0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [3, -1], [2, -1], [1, -1]]; // [нарисованное направление, зеркало]
  let body = "";
  for (let i = 0; i < 8; i++) {
    const x = 110 + (i % 4) * 220, y = 250 + Math.floor(i / 4) * 290;
    body += `<g transform="translate(${x} ${y}) scale(${map[i][1]} 1)">${knight(map[i][0])}</g>`;
    body += `<text x="${x}" y="${y + 40}" text-anchor="middle" font-family="Arial" font-size="20" fill="#cfd6ee">${names[i]}</text>`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="900" height="620" viewBox="0 0 900 620">${defs()}
<rect width="900" height="620" fill="#232238"/>
<text x="450" y="34" text-anchor="middle" font-family="Arial" font-size="24" fill="#ffffff">Рыцарь (Мечник) — 8 сторон (5 нарисованы + 3 зеркально)</text>
${body}</svg>`;
}

// ---------------- сцена кристальной пещеры ----------------
// Пол из каменных плит: ячейки Вороного (обрезка полуплоскостями), чуть сжатые к центру.
function voronoiCells(pts, W, H) {
  const cells = [];
  for (let i = 0; i < pts.length; i++) {
    let poly = [[0, 0], [W, 0], [W, H], [0, H]];
    const p = pts[i];
    for (let j = 0; j < pts.length; j++) {
      if (i === j) continue;
      const q = pts[j];
      const mx = (p[0] + q[0]) / 2, my = (p[1] + q[1]) / 2, nx = q[0] - p[0], ny = q[1] - p[1];
      const inside = (v) => (v[0] - mx) * nx + (v[1] - my) * ny <= 0;
      const out = [];
      for (let k = 0; k < poly.length; k++) {
        const a = poly[k], b = poly[(k + 1) % poly.length];
        const ia = inside(a), ib = inside(b);
        if (ia) out.push(a);
        if (ia !== ib) {
          const da = (a[0] - mx) * nx + (a[1] - my) * ny, db = (b[0] - mx) * nx + (b[1] - my) * ny;
          const t = da / (da - db);
          out.push([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]);
        }
      }
      poly = out;
      if (!poly.length) break;
    }
    cells.push(poly);
  }
  return cells;
}
function roundedPath(poly, inset, cx, cy) {
  const pts = poly.map(([x, y]) => [cx + (x - cx) * inset, cy + (y - cy) * inset]);
  let d = "";
  for (let i = 0; i < pts.length; i++) {
    const a = pts[i], b = pts[(i + 1) % pts.length];
    const m = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
    d += i === 0 ? `M${f(m[0])} ${f(m[1])}` : "";
    const n = pts[(i + 1) % pts.length], nn = pts[(i + 2) % pts.length];
    const m2 = [(n[0] + nn[0]) / 2, (n[1] + nn[1]) / 2];
    d += ` Q${f(n[0])} ${f(n[1])} ${f(m2[0])} ${f(m2[1])}`;
  }
  return d + " Z";
}

function crystal(x, y, sc, n) {
  let g = `<ellipse cx="${x}" cy="${y - 30 * sc}" rx="${110 * sc}" ry="${80 * sc}" fill="url(#glow)"/>`;
  for (let i = 0; i < n; i++) {
    const a = (i - (n - 1) / 2) * 0.32 + r(-0.08, 0.08);
    const len = (r(60, 95) - Math.abs(i - (n - 1) / 2) * 16) * sc;
    const w = r(9, 14) * sc;
    const bx = x + (i - (n - 1) / 2) * 12 * sc;
    const tx = bx + Math.sin(a) * len, ty = y - Math.cos(a) * len;
    const px = Math.cos(a) * w, py = Math.sin(a) * w;
    g += `<path d="M${f(bx - px)} ${f(y - py)} L${f(tx - px * 0.8)} ${f(ty - py * 0.8)} L${f(tx + Math.sin(a) * w * 1.2)} ${f(ty - Math.cos(a) * w * 1.2)} L${f(tx + px * 0.8)} ${f(ty + py * 0.8)} L${f(bx + px)} ${f(y + py)} Z" fill="url(#crystal)" stroke="#0f3550" stroke-width="2.2" stroke-linejoin="round"/>`;
    g += `<path d="M${f(bx)} ${f(y)} L${f(tx)} ${f(ty)} L${f(tx + px * 0.8)} ${f(ty + py * 0.8)} L${f(bx + px)} ${f(y + py)} Z" fill="url(#crystalSide)" opacity="0.85"/>`;
  }
  return g;
}
function fungus(x, y, sc) {
  let g = "";
  for (const [dx, dy, w] of [[0, 0, 34], [16, 20, 26], [-10, 34, 20]]) {
    g += `<path d="M${x + dx * sc - w * sc} ${y + dy * sc} Q${x + dx * sc} ${y + dy * sc - 22 * sc} ${x + dx * sc + w * sc} ${y + dy * sc} Q${x + dx * sc} ${y + dy * sc + 8 * sc} ${x + dx * sc - w * sc} ${y + dy * sc} Z" fill="#e5762a" stroke="#3a1606" stroke-width="2"/>`;
    g += `<path d="M${x + dx * sc - w * sc * 0.6} ${y + dy * sc - 5 * sc} Q${x + dx * sc} ${y + dy * sc - 16 * sc} ${x + dx * sc + w * sc * 0.6} ${y + dy * sc - 5 * sc}" stroke="#ffd79a" stroke-width="1.5" fill="none" opacity="0.8"/>`;
  }
  return g;
}
function shroomsGlow(x, y) {
  let g = `<ellipse cx="${x}" cy="${y - 10}" rx="46" ry="30" fill="url(#glow)" opacity="0.7"/>`;
  for (const [dx, h, cw] of [[-14, 26, 9], [0, 34, 11], [14, 22, 8]]) {
    g += `<path d="M${x + dx} ${y} L${x + dx} ${y - h}" stroke="#a8c2d8" stroke-width="3"/>`;
    g += `<path d="M${x + dx - cw} ${y - h} Q${x + dx} ${y - h - cw * 1.2} ${x + dx + cw} ${y - h} Z" fill="#7fe6ff" stroke="#14516e" stroke-width="2"/>`;
  }
  return g;
}
function grass(x, y) {
  let g = "";
  for (let i = 0; i < 9; i++) {
    const bx = x + i * 5 - 20, h = r(20, 44), lean = r(-14, 14);
    const tip = i % 3 === 0 ? "#d04a5a" : "#2f6f78";
    g += `<path d="M${bx} ${y} Q${bx + lean * 0.3} ${y - h * 0.6} ${bx + lean} ${y - h}" stroke="${tip}" stroke-width="2.5" fill="none" stroke-linecap="round"/>`;
  }
  return g;
}
function root(x, y, len) {
  let d = `M${x} ${y}`, cx = x;
  for (let i = 1; i <= 6; i++) { cx += r(-10, 10); d += ` Q${f(cx + r(-8, 8))} ${f(y + len * (i - 0.5) / 6)} ${f(cx)} ${f(y + len * i / 6)}`; }
  return `<path d="${d}" stroke="#5c6386" stroke-width="3" fill="none" opacity="0.9"/>`;
}
// Скальный выступ: верх-масса + обрыв (видимая стенка) снизу.
function cliff(top, faceH) {
  // top — массив точек верхнего контура (по часовой), нижний край обрыва — смещение вниз на faceH
  const pts = top.map((p) => p.join(" ")).join(" L");
  const bottomEdge = top.filter((p) => p[2]); // точки, у которых виден обрыв
  let g = "";
  if (bottomEdge.length > 1) {
    let d = `M${bottomEdge[0][0]} ${bottomEdge[0][1]}`;
    for (const p of bottomEdge.slice(1)) d += ` L${p[0]} ${p[1]}`;
    for (const p of bottomEdge.slice().reverse()) d += ` L${p[0] + r(-4, 4)} ${p[1] + faceH + r(-6, 6)}`;
    g += `<path d="${d} Z" fill="url(#cliff)" stroke="${OUT}" stroke-width="3" stroke-linejoin="round"/>`;
    // слои породы
    for (let k = 1; k <= 3; k++) {
      let s = `M${bottomEdge[0][0]} ${bottomEdge[0][1] + faceH * k / 4}`;
      for (const p of bottomEdge.slice(1)) s += ` L${p[0]} ${p[1] + faceH * k / 4 + r(-3, 3)}`;
      g += `<path d="${s}" stroke="#10101f" stroke-width="2" fill="none" opacity="0.6"/>`;
    }
  }
  g += `<path d="M${top.map((p) => p[0] + " " + p[1]).join(" L")} Z" fill="url(#rockTop)" stroke="${OUT}" stroke-width="3" stroke-linejoin="round"/>`;
  // холодная кромка по видимому краю
  if (bottomEdge.length > 1) g += `<path d="M${bottomEdge.map((p) => p[0] + " " + p[1]).join(" L")}" stroke="#9aa8e0" stroke-width="2.5" fill="none" opacity="0.8"/>`;
  return g;
}

function caveScene() {
  const W = 1280, H = 720;
  seed = 11;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs()}`;
  s += `<rect width="${W}" height="${H}" fill="#0c0b18"/>`;
  // пол: плиты
  const pts = [];
  for (let i = 0; i < 70; i++) pts.push([r(0, W), r(0, H)]);
  const cells = voronoiCells(pts, W, H);
  s += `<g>`;
  for (let i = 0; i < cells.length; i++) {
    const c = cells[i]; if (c.length < 3) continue;
    const cx = c.reduce((a, p) => a + p[0], 0) / c.length, cy = c.reduce((a, p) => a + p[1], 0) / c.length;
    const fill = ["slabA", "slabA", "slabA", "slabB", "slabC"][Math.floor(rnd() * 5)];
    s += `<path d="${roundedPath(c, 0.9, cx, cy)}" fill="url(#${fill})" stroke="#191a33" stroke-width="2.5"/>`;
    // трещинка
    if (rnd() < 0.35) s += `<path d="M${f(cx - 14)} ${f(cy - 4)} L${f(cx)} ${f(cy + 3)} L${f(cx + 10)} ${f(cy - 2)}" stroke="#2a2b4c" stroke-width="1.5" fill="none"/>`;
  }
  s += `</g>`;
  // мелкая галька и мох
  for (let i = 0; i < 60; i++) s += `<circle cx="${f(r(0, W))}" cy="${f(r(0, H))}" r="${f(r(1.5, 3.5))}" fill="${rnd() < 0.5 ? "#6fc2d4" : "#8d93c4"}" opacity="0.6"/>`;
  // лестница вниз (справа)
  s += `<g transform="translate(1010 470)"><path d="M0 0 L120 0 L120 90 L0 90 Z" fill="#0b0a16" stroke="${OUT}" stroke-width="3"/>`;
  for (let i = 0; i < 4; i++) s += `<rect x="${10 + i * 6}" y="${8 + i * 20}" width="${100 - i * 12}" height="12" rx="2" fill="#6b72a6" opacity="${1 - i * 0.2}" stroke="${OUT}" stroke-width="2"/>`;
  s += `<ellipse cx="60" cy="70" rx="40" ry="16" fill="url(#glow)"/></g>`;
  // скалы: верхняя стена, левый выступ, правый выступ, передний план
  s += cliff([[0, 0, 0], [W, 0, 0], [W, 120, 1], [1100, 150, 1], [980, 130, 1], [860, 160, 1], [700, 140, 1], [560, 170, 1], [420, 150, 1], [300, 175, 1], [160, 150, 1], [0, 165, 1]], 70);
  s += cliff([[0, 250, 0], [120, 270, 0], [190, 330, 1], [170, 420, 1], [90, 470, 1], [0, 480, 1]], 50);
  s += cliff([[1180, 230, 0], [W, 220, 0], [W, 400, 1], [1220, 390, 1], [1170, 330, 1]], 46);
  s += cliff([[0, 640, 0], [260, 610, 0], [420, 650, 0], [560, 630, 0], [560, 720, 0], [0, 720, 0]], 0);
  s += cliff([[860, 660, 0], [1050, 630, 0], [W, 650, 0], [W, 720, 0], [820, 720, 0]], 0);
  // корни со стены, трутовики
  for (const x of [130, 380, 640, 920, 1160]) s += root(x, 160 + r(-10, 10), r(70, 120));
  s += fungus(250, 190, 1.0) + fungus(760, 205, 0.9) + fungus(1060, 185, 0.8) + fungus(150, 360, 0.8);
  // кристаллы со свечением
  s += crystal(480, 235, 1.1, 4) + crystal(900, 230, 0.9, 3) + crystal(205, 470, 0.8, 3) + crystal(1150, 650, 1.0, 4) + crystal(330, 650, 0.7, 2);
  s += shroomsGlow(620, 255) + shroomsGlow(1210, 420);
  s += grass(560, 260) + grass(820, 250) + grass(240, 520) + grass(980, 640) + grass(700, 600);
  // герой в центре (с тёплым светом вокруг)
  s += `<ellipse cx="640" cy="400" rx="220" ry="160" fill="url(#warm)"/>`;
  s += `<g transform="translate(640 440) scale(0.75)">${knight(1)}</g>`;
  // общий полумрак по краям
  s += `<rect width="${W}" height="${H}" fill="url(#vignette)"/>`;
  s += `<text x="20" y="${H - 16}" font-family="Arial" font-size="18" fill="#9aa3c8" opacity="0.8">Концепт: векторная графика — кристальная пещера, 1-й этаж</text>`;
  return s + `</svg>`;
}

fs.writeFileSync("concepts/hero_8dirs.svg", heroSheet());
fs.writeFileSync("concepts/cave_scene.svg", caveScene());
console.log("written concepts/hero_8dirs.svg, concepts/cave_scene.svg");

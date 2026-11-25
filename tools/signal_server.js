// Локальный сигнальный сервер для тестов кооператива (тот же протокол, что у PeerJS):
//   node tools/signal_server.js [порт]   → ws://127.0.0.1:<порт>/peerjs?id=...
// Игра: --signal=ws://127.0.0.1:9000/peerjs
// Клиент получает {"type":"OPEN"}; сообщения {"type","dst","payload"} пересылаются адресату
// с полем "src"; если адресата нет — отправителю приходит {"type":"EXPIRE"}.
const http = require("http");
const crypto = require("crypto");
const port = +(process.argv[2] || 9000);
const clients = new Map(); // id -> socket

function frame(text) {
  const data = Buffer.from(text);
  const len = data.length;
  let head;
  if (len < 126) head = Buffer.from([0x81, len]);
  else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x81; head[1] = 126; head.writeUInt16BE(len, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x81; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
  return Buffer.concat([head, data]);
}

function send(sock, obj) { try { sock.write(frame(JSON.stringify(obj))); } catch (e) {} }

const server = http.createServer((req, res) => { res.writeHead(200); res.end("signal ok"); });
server.on("upgrade", (req, sock) => {
  const url = new URL(req.url, "http://x");
  const id = url.searchParams.get("id");
  const accept = crypto.createHash("sha1").update(req.headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  sock.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n");
  if (!id || clients.has(id)) { send(sock, { type: "ID-TAKEN" }); sock.end(); return; }
  clients.set(id, sock);
  console.log("open", id);
  send(sock, { type: "OPEN" });
  let buf = Buffer.alloc(0);
  sock.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    while (buf.length >= 2) {
      const op = buf[0] & 0x0f;
      let len = buf[1] & 0x7f, off = 2;
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
      const masked = buf[1] & 0x80;
      const total = off + (masked ? 4 : 0) + len;
      if (buf.length < total) return;
      let data = buf.subarray(off + (masked ? 4 : 0), total);
      if (masked) { const m = buf.subarray(off, off + 4); data = Buffer.from(data.map((b, i) => b ^ m[i % 4])); }
      buf = buf.subarray(total);
      if (op === 8) { sock.end(); return; }
      if (op !== 1) continue;
      let msg; try { msg = JSON.parse(data.toString()); } catch (e) { continue; }
      if (msg.type === "HEARTBEAT") continue;
      const dst = clients.get(msg.dst);
      if (dst) send(dst, { type: msg.type, src: id, payload: msg.payload });
      else send(sock, { type: "EXPIRE", src: msg.dst });
    }
  });
  const bye = () => { if (clients.get(id) === sock) { clients.delete(id); console.log("close", id); } };
  sock.on("close", bye);
  sock.on("error", bye);
});
server.listen(port, "127.0.0.1", () => console.log("signal server on " + port));

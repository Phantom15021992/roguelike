// Локальный сервер связи для тестов кооператива — крошечный MQTT-брокер поверх WebSocket
// (тот же протокол, что у открытых серверов broker.emqx.io и др., см. scripts/mqtt_signal.gd):
//   node tools/signal_server.js [порт]   → ws://127.0.0.1:<порт>/mqtt
// Игра: --signal=ws://127.0.0.1:9000/mqtt   (в браузере: index.html?signal=ws://127.0.0.1:9000/mqtt)
// Умеет: CONNECT/CONNACK, SUBSCRIBE/SUBACK (точное имя ящика), PUBLISH (QoS 0), PINGREQ, DISCONNECT.
const http = require("http");
const crypto = require("crypto");
const port = +(process.argv[2] || 9000);
const subs = new Map(); // ящик -> Set(сокетов)

function wsFrame(data) {
  const len = data.length;
  let head;
  if (len < 126) head = Buffer.from([0x82, len]);
  else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x82; head[1] = 126; head.writeUInt16BE(len, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x82; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
  return Buffer.concat([head, data]);
}

function mqtt(type, body) {
  const out = [type];
  let n = body.length;
  do { let d = n % 128; n = Math.floor(n / 128); if (n > 0) d |= 128; out.push(d); } while (n > 0);
  return Buffer.concat([Buffer.from(out), body]);
}

function send(sock, pkt) { try { sock.write(wsFrame(pkt)); } catch (e) {} }

function onMqtt(sock, pkt) {
  const type = pkt[0] >> 4;
  let i = 1, n = 0, mul = 1;
  do { n += (pkt[i] & 127) * mul; mul *= 128; } while (pkt[i++] & 128);
  const body = pkt.subarray(i, i + n);
  if (type === 1) send(sock, Buffer.from([0x20, 2, 0, 0]));
  else if (type === 8) {
    const id = body.subarray(0, 2);
    const tl = body.readUInt16BE(2);
    const topic = body.subarray(4, 4 + tl).toString();
    if (!subs.has(topic)) subs.set(topic, new Set());
    subs.get(topic).add(sock);
    sock.topics.push(topic);
    console.log("sub", topic);
    send(sock, mqtt(0x90, Buffer.concat([id, Buffer.from([0])])));
  } else if (type === 3) {
    const tl = body.readUInt16BE(0);
    const topic = body.subarray(2, 2 + tl).toString();
    for (const s of subs.get(topic) || []) send(s, mqtt(0x30, body));
  } else if (type === 12) send(sock, Buffer.from([0xD0, 0]));
  else if (type === 14) sock.end();
}

const server = http.createServer((req, res) => { res.writeHead(200); res.end("mqtt ok"); });
server.on("upgrade", (req, sock) => {
  const accept = crypto.createHash("sha1").update(req.headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  sock.write("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\nSec-WebSocket-Protocol: mqtt\r\n\r\n");
  sock.topics = [];
  let buf = Buffer.alloc(0);
  let mq = Buffer.alloc(0);
  sock.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    while (buf.length >= 2) {
      const op = buf[0] & 0x0f;
      let len = buf[1] & 0x7f, off = 2;
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
      const masked = buf[1] & 0x80;
      if (buf.length < off + (masked ? 4 : 0) + len) return;
      let data = buf.subarray(off + (masked ? 4 : 0), off + (masked ? 4 : 0) + len);
      if (masked) { const m = buf.subarray(off, off + 4); data = Buffer.from(data.map((b, i) => b ^ m[i % 4])); }
      buf = buf.subarray(off + (masked ? 4 : 0) + len);
      if (op === 8) { sock.end(); return; }
      if (op !== 2 && op !== 0) continue;
      mq = Buffer.concat([mq, data]);
      // Разбор MQTT-пакетов (могут приходить склеенными).
      while (mq.length >= 2) {
        let i = 1, n = 0, mul = 1, ok = true;
        while (true) { if (i >= mq.length) { ok = false; break; } n += (mq[i] & 127) * mul; mul *= 128; if (!(mq[i++] & 128)) break; }
        if (!ok || mq.length < i + n) break;
        onMqtt(sock, mq.subarray(0, i + n));
        mq = mq.subarray(i + n);
      }
    }
  });
  const drop = () => { for (const t of sock.topics) subs.get(t)?.delete(sock); };
  sock.on("close", drop);
  sock.on("error", drop);
});
server.listen(port, "127.0.0.1", () => console.log("mqtt signal server on ws://127.0.0.1:" + port + "/mqtt"));

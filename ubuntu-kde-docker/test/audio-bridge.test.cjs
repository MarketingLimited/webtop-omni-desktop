const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('child_process');
const { WebSocket } = require('/opt/webrtc-bridge/node_modules/ws');

const wait = (ms) => new Promise((res) => setTimeout(res, ms));

test('webrtc audio bridge server', async (t) => {
  const server = spawn('node', ['/opt/webrtc-bridge/server.js']);
  t.after(() => server.kill());
  await wait(500);

  await t.test('GET /package.json', async () => {
    const res = await fetch('http://localhost:8080/package.json');
    assert.strictEqual(res.status, 200);
    const body = await res.text();
    assert.ok(body.includes('"name": "pipewire-webrtc-bridge"'));
  });

  await t.test('GET /webrtc-client.html', async () => {
    const res = await fetch('http://localhost:8080/webrtc-client.html');
    assert.strictEqual(res.status, 200);
    const body = await res.text();
    assert.ok(body.includes('<title>WebRTC Desktop Audio</title>'));
  });

  await t.test('WebSocket signaling connection', async () => {
    const ws = new WebSocket('ws://localhost:8081');
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('timeout')), 1000);
      ws.once('open', () => {
        clearTimeout(timer);
        resolve();
      });
      ws.once('error', (err) => {
        clearTimeout(timer);
        reject(err);
      });
    });
    ws.close();
  });
});

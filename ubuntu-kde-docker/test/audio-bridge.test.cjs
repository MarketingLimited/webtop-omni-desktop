const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { WebSocket, WebSocketServer } = require('/opt/audio-bridge/node_modules/ws');

const wait = (ms) => new Promise((res) => setTimeout(res, ms));

test('audio bridge server', async (t) => {
  // Create a parecord stub that emits dummy audio data
  const stubDir = fs.mkdtempSync(path.join(os.tmpdir(), 'parecord-'));
  const stubPath = path.join(stubDir, 'parecord');
  fs.writeFileSync(
    stubPath,
    `#!/usr/bin/env node\n` +
      `setInterval(() => process.stdout.write(Buffer.alloc(4)), 20);\n` +
      `process.stdin.resume();\n`
  );
  fs.chmodSync(stubPath, 0o755);

  const server = spawn('node', ['/opt/audio-bridge/server.js'], {
    env: { ...process.env, PATH: `${stubDir}:${process.env.PATH}` },
  });
  t.after(() => server.kill());

  // give the server a moment to start
  await wait(500);

  await t.test('GET /package.json', async () => {
    const res = await fetch('http://localhost:8080/package.json');
    assert.strictEqual(res.status, 200);
    const body = await res.text();
    assert.ok(body.includes('"name": "pulseaudio-web-bridge"'));
  });

  await t.test('GET /audio-player.html', async () => {
    const res = await fetch('http://localhost:8080/audio-player.html');
    assert.strictEqual(res.status, 200);
    const body = await res.text();
    assert.ok(body.includes('<title>Desktop Audio</title>'));
  });

  await t.test('WebSocket direct connection', async () => {
    const ws = new WebSocket('ws://localhost:8080/audio-bridge');
    const message = await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('timeout')), 2000);
      ws.once('message', (data) => {
        clearTimeout(timeout);
        resolve(data);
      });
      ws.once('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });
    assert.ok(message.length > 0);
    ws.close();
  });

  await t.test('WebSocket fails without /audio-bridge path', async () => {
    await assert.rejects(
      () =>
        new Promise((resolve, reject) => {
          const ws = new WebSocket('ws://localhost:8080');
          ws.on('open', resolve);
          ws.on('error', reject);
        }),
      /unexpected server response/i
    );
  });

  await t.test('WebSocket proxied connection', async () => {
    const proxy = new WebSocketServer({ port: 8099, path: '/audio-bridge' });
    proxy.on('connection', (client) => {
      const target = new WebSocket('ws://localhost:8080/audio-bridge');
      client.on('close', () => target.close());
      client.on('message', (msg) => target.send(msg));
      target.on('message', (msg) => client.send(msg));
      target.on('close', () => client.close());
    });
    t.after(() => proxy.close());

    const ws = new WebSocket('ws://localhost:8099/audio-bridge');
    const message = await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('timeout')), 2000);
      ws.once('message', (data) => {
        clearTimeout(timeout);
        resolve(data);
      });
      ws.once('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });
    assert.ok(message.length > 0);
    ws.close();
  });
});


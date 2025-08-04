const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('child_process');


const wait = (ms) => new Promise((res) => setTimeout(res, ms));

test('audio bridge serves static files', async (t) => {
  const server = spawn('node', ['/opt/audio-bridge/server.js']);
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
});

const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('child_process');
const path = require('path');

const wait = (ms) => new Promise((res) => setTimeout(res, ms));

test('WebRTC offer endpoint responds', async (t) => {
  const serverPath = path.resolve(__dirname, '../webrtc-audio-server.cjs');
  const server = spawn('node', [serverPath]);
  t.after(() => server.kill());

  await wait(500);

  const res = await fetch('http://localhost:8080/offer', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  });

  assert.ok(res.status >= 400);
});

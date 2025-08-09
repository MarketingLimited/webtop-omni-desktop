const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

function writeStub(dir, name, content) {
  const file = path.join(dir, name);
  fs.writeFileSync(file, content);
  fs.chmodSync(file, 0o755);
}

test('retries and calls start-pulseaudio with exponential backoff', { concurrency: false }, (t) => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sab-'));
  const log = path.join(tmp, 'stub.log');

  // Copy script under test and stub start-pulseaudio.sh in same dir.
  const scriptSrc = path.resolve(__dirname, '..', 'start-audio-bridge.sh');
  const script = path.join(tmp, 'start-audio-bridge.sh');
  fs.copyFileSync(scriptSrc, script);
  fs.chmodSync(script, 0o755);
  writeStub(tmp, 'start-pulseaudio.sh', '#!/bin/bash\necho "start-pulseaudio" >>"$STUB_OUT"');

  // Stub utilities used by the script.
  writeStub(tmp, 'su', '#!/bin/bash\ncmd="$4"\nbash -c "$cmd"');
  writeStub(tmp, 'pactl', '#!/bin/bash\nexit 1');
  writeStub(tmp, 'sleep', '#!/bin/bash\necho "sleep $1" >>"$STUB_OUT"');

  const result = spawnSync('/bin/bash', [script], {
    env: { PATH: `${tmp}:${process.env.PATH}`, STUB_OUT: log, PULSE_USER: 'stub', PULSE_UID: '1000' },
    encoding: 'utf8',
  });

  assert.notStrictEqual(result.status, 0);
  const stub = fs.readFileSync(log, 'utf8').trim().split('\n');
  const sleeps = stub.filter((l) => l.startsWith('sleep')).map((l) => l.split(' ')[1]);
  assert.deepStrictEqual(sleeps, ['1', '2', '4', '8', '16']);
  const starts = stub.filter((l) => l.startsWith('start-pulseaudio'));
  assert.strictEqual(starts.length, 5);
});

test('exits once PulseAudio is reachable over TCP', { concurrency: false }, (t) => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sab-'));
  const log = path.join(tmp, 'stub.log');

  const scriptSrc = path.resolve(__dirname, '..', 'start-audio-bridge.sh');
  const script = path.join(tmp, 'start-audio-bridge.sh');
  fs.copyFileSync(scriptSrc, script);
  fs.chmodSync(script, 0o755);
  writeStub(tmp, 'start-pulseaudio.sh', '#!/bin/bash\necho "start-pulseaudio" >>"$STUB_OUT"');

  writeStub(tmp, 'su', '#!/bin/bash\ncmd="$4"\nbash -c "$cmd"');
  writeStub(
    tmp,
    'pactl',
    '#!/bin/bash\nif [ "$1" = "info" ]; then exit 1; fi\nif [ "$1" = "-s" ] && [ "$2" = "tcp:localhost:4713" ] && [ "$3" = "info" ]; then exit 0; fi\nexit 1'
  );
  writeStub(tmp, 'sleep', '#!/bin/bash\necho "sleep $1" >>"$STUB_OUT"');

  writeStub(tmp, 'node', '#!/bin/bash\necho "node $@" >>"$STUB_OUT"');
  const nodePath = '/usr/bin/node';
  fs.copyFileSync(path.join(tmp, 'node'), nodePath);
  t.after(() => {
    try { fs.unlinkSync(nodePath); } catch {}
  });

  const result = spawnSync('/bin/bash', [script], {
    env: { PATH: `${tmp}:${process.env.PATH}`, STUB_OUT: log, PULSE_USER: 'stub', PULSE_UID: '1000' },
    encoding: 'utf8',
  });

  assert.strictEqual(result.status, 0);
  const stub = fs.readFileSync(log, 'utf8');
  assert.ok(!stub.includes('start-pulseaudio'));
  assert.ok(!stub.includes('sleep'));
  assert.match(stub, /node \/opt\/audio-bridge\/webrtc-audio-server.cjs/);
});

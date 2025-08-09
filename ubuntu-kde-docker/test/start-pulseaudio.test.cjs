const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const net = require('net');
const { spawnSync } = require('child_process');

function writeStub(dir, name, content) {
  const file = path.join(dir, name);
  fs.writeFileSync(file, content);
  fs.chmodSync(file, 0o755);
}

test('falls back to TCP when UNIX socket unavailable', async (t) => {
  const stubDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pa-stub-'));
  const stubLog = path.join(stubDir, 'stub.log');
  const logFile = path.join(stubDir, 'pa.log');

  // stub commands
  writeStub(stubDir, 'dpkg', '#!/bin/bash\nexit 0');
  writeStub(stubDir, 'id', '#!/bin/bash\nif [ "$1" = "-u" ]; then echo 1000; exit 0; fi\nif [ "$1" = "-nG" ]; then echo audio; exit 0; fi\nexit 0');
  writeStub(stubDir, 'chown', '#!/bin/bash\nexit 0');
  writeStub(stubDir, 'su', '#!/bin/bash\necho "su $@" >>"$STUB_OUT"\ncmd="$4"\nbash -c "$cmd"');
  writeStub(stubDir, 'pulseaudio', '#!/bin/bash\necho "pulseaudio $@" >>"$STUB_OUT"\necho "Daemon startup complete" >>"$LOGFILE"\nexit 0');
  writeStub(stubDir, 'pactl', '#!/bin/bash\necho "pactl $@" >>"$STUB_OUT"\nif [ "$1" = "list" ] && [ "$3" = "sinks" ]; then echo "1\tstub_sink"; exit 0; fi\nif [ -n "$PULSE_SERVER" ]; then exit 0; else exit 1; fi');
  writeStub(stubDir, 'pkill', '#!/bin/bash\necho "pkill $@" >>"$STUB_OUT"');
  writeStub(stubDir, 'sleep', '#!/bin/bash\n:');

  // dummy native socket
  const runtimeDir = path.join('/run/user', '1000', 'pulse');
  fs.mkdirSync(runtimeDir, { recursive: true });
  const sockPath = path.join(runtimeDir, 'native');
  try { fs.unlinkSync(sockPath); } catch {}
  const server = net.createServer().listen(sockPath);
  t.after(() => server.close());

  const script = path.resolve(__dirname, '..', 'start-pulseaudio.sh');
  const result = spawnSync('/bin/bash', [script], {
    env: {
      PATH: `${stubDir}:${process.env.PATH}`,
      PULSE_USER: 'stubuser',
      PULSE_UID: '1000',
      LOGFILE: logFile,
      PULSE_LOGFILE: logFile,
      STUB_OUT: stubLog,
    },
    encoding: 'utf8',
  });
  assert.strictEqual(result.status, 0);
  const log = fs.readFileSync(logFile, 'utf8');
  assert.match(log, /PulseAudio bound to tcp/);
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.match(stub, /pulseaudio -D --log-target=file:/);
  assert.match(stub, /pulseaudio -D --exit-idle-time=-1 --load=module-native-protocol-tcp --log-target=file:/);
  assert.ok(!fs.existsSync(sockPath));
});

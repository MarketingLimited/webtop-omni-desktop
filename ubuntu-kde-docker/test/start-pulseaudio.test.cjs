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

test('fails when system.pa is missing', { concurrency: false }, async (t) => {
  const systemPa = '/etc/pulse/system.pa';
  const backup = `${systemPa}.bak`;

  const hadSystemPa = fs.existsSync(systemPa);
  const hadBackup = fs.existsSync(backup);

  // Move any existing system.pa so the test can simulate a missing config.
  let tempBackup;
  if (hadSystemPa) {
    tempBackup = hadBackup ? `${backup}.${Date.now()}` : backup;
    fs.renameSync(systemPa, tempBackup);
  }

  // Cleanup: restore any moved config and remove files this test created.
  t.after(() => {
    try {
      if (tempBackup && fs.existsSync(tempBackup)) fs.renameSync(tempBackup, systemPa);
    } catch {}
    try {
      // Delete backup if it wasn't present before the test.
      if (!hadBackup && fs.existsSync(backup)) fs.unlinkSync(backup);
    } catch {}
    try {
      // Remove system.pa if the test or script created it.
      if (!hadSystemPa && fs.existsSync(systemPa)) fs.unlinkSync(systemPa);
    } catch {}
  });

  const stubDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pa-stub-'));
  const stubLog = path.join(stubDir, 'stub.log');
  const logFile = path.join(stubDir, 'pa.log');

  writeStub(stubDir, 'dpkg', '#!/bin/bash\nexit 0');
  writeStub(stubDir, 'id', '#!/bin/bash\nif [ "$1" = "-u" ]; then echo 1000; exit 0; fi\nif [ "$1" = "-nG" ]; then echo audio; exit 0; fi\nexit 0');
  writeStub(stubDir, 'chown', '#!/bin/bash\nexit 0');
  writeStub(stubDir, 'su', '#!/bin/bash\necho "su $@" >>"$STUB_OUT"\ncmd="$4"\nbash -c "$cmd"');
  writeStub(stubDir, 'pulseaudio', '#!/bin/bash\necho "pulseaudio $@" >>"$STUB_OUT"');
  writeStub(stubDir, 'pactl', '#!/bin/bash\necho "pactl $@" >>"$STUB_OUT"');
  writeStub(stubDir, 'pkill', '#!/bin/bash\necho "pkill $@" >>"$STUB_OUT"');
  writeStub(stubDir, 'sleep', '#!/bin/bash\n:');

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
  assert.notStrictEqual(result.status, 0);
  assert.match(result.stderr, /Missing or unreadable PulseAudio config/);
});

test('falls back to TCP when UNIX socket unavailable', { concurrency: false }, async (t) => {
  const systemPa = '/etc/pulse/system.pa';
  fs.mkdirSync(path.dirname(systemPa), { recursive: true });
  fs.writeFileSync(systemPa, '');
  t.after(() => {
    try { fs.unlinkSync(systemPa); } catch {}
  });
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
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    try {
      fs.unlinkSync(sockPath);
    } catch {}
  });

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
  assert.match(stub, /pulseaudio --system --daemonize --file=\/etc\/pulse\/system.pa --log-target=file:/);
  const pulseaudioLines = stub
    .split('\n')
    .filter((line) => line.startsWith('pulseaudio'));
  assert.strictEqual(pulseaudioLines.length, 1);
  assert.ok(!fs.existsSync(sockPath));
});

test('uses UNIX socket when available', { concurrency: false }, async (t) => {
  const systemPa = '/etc/pulse/system.pa';
  fs.mkdirSync(path.dirname(systemPa), { recursive: true });
  fs.writeFileSync(systemPa, '');
  t.after(() => {
    try { fs.unlinkSync(systemPa); } catch {}
  });
  const stubDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pa-stub-'));
  const stubLog = path.join(stubDir, 'stub.log');
  const logFile = path.join(stubDir, 'pa.log');

  // stub commands
  writeStub(stubDir, 'dpkg', '#!/bin/bash\nexit 0');
  writeStub(
    stubDir,
    'id',
    '#!/bin/bash\nif [ "$1" = "-u" ]; then echo 1000; exit 0; fi\nif [ "$1" = "-nG" ]; then echo audio; exit 0; fi\nexit 0'
  );
  writeStub(stubDir, 'chown', '#!/bin/bash\nexit 0');
  writeStub(
    stubDir,
    'su',
    '#!/bin/bash\necho "su $@" >>"$STUB_OUT"\ncmd="$4"\nbash -c "$cmd"'
  );
  writeStub(
    stubDir,
    'pulseaudio',
    '#!/bin/bash\necho "pulseaudio $@" >>"$STUB_OUT"\necho "Daemon startup complete" >>"$LOGFILE"\nexit 0'
  );
  writeStub(
    stubDir,
    'pactl',
    '#!/bin/bash\necho "pactl $@" >>"$STUB_OUT"\nif [ "$1" = "list" ] && [ "$3" = "sinks" ]; then echo "1\tstub_sink"; exit 0; fi\nexit 0'
  );
  writeStub(stubDir, 'pkill', '#!/bin/bash\necho "pkill $@" >>"$STUB_OUT"');
  writeStub(stubDir, 'sleep', '#!/bin/bash\n:');

  // ensure no native socket exists
  const runtimeDir = path.join('/run/user', '1000', 'pulse');
  fs.mkdirSync(runtimeDir, { recursive: true });
  const sockPath = path.join(runtimeDir, 'native');
  try { fs.unlinkSync(sockPath); } catch {}

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
  assert.match(log, /PulseAudio bound to unix/);
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.match(stub, /pulseaudio --system --daemonize --file=\/etc\/pulse\/system.pa --log-target=file:/);
  const pulseaudioLines = stub
    .split('\n')
    .filter((line) => line.startsWith('pulseaudio'));
  assert.strictEqual(pulseaudioLines.length, 1);
  assert.match(stub, /pactl list short sinks/);
});

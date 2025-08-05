const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

// helper to find real path of a command
function findCmd(cmd) {
  for (const dir of ['/usr/bin', '/bin']) {
    const full = path.join(dir, cmd);
    if (fs.existsSync(full)) return full;
  }
  throw new Error(`command not found: ${cmd}`);
}

function writeStub(dir, name, content) {
  const file = path.join(dir, name);
  fs.writeFileSync(file, content);
  fs.chmodSync(file, 0o755);
}

const script = path.join(__dirname, '..', 'diagnostic-and-fix.sh');

// Test: failure when a required command is missing
// -----------------------------------------------
test('fails if required command missing', () => {
  const stubDir = fs.mkdtempSync(path.join(os.tmpdir(), 'diagfix-missing-'));
  // provide minimal utilities for log function
  fs.symlinkSync(findCmd('date'), path.join(stubDir, 'date'));
  fs.symlinkSync(findCmd('tee'), path.join(stubDir, 'tee'));
  const logFile = path.join(stubDir, 'log');
  const result = spawnSync('/bin/bash', [script], {
    env: { LOG_FILE: logFile, PATH: stubDir },
    encoding: 'utf8',
  });
  assert.notStrictEqual(result.status, 0);
  const log = fs.readFileSync(logFile, 'utf8');
  assert.match(log, /Required command 'pulseaudio' not found/);
});

// Shared stubs for remaining tests
function setupBaseEnv(opts = {}) {
  const stubDir = fs.mkdtempSync(path.join(os.tmpdir(), 'diagfix-stub-'));
  const stubLog = path.join(stubDir, 'stub.log');

  // pulseaudio stub
  writeStub(stubDir, 'pulseaudio', `#!/bin/bash\n` +
    `echo "pulseaudio $@" >>"$STUB_OUT"\n` +
    `if [ "$1" = "--check" ]; then\n` +
    `  exit ${opts.paCheck ?? 0}\n` +
    `elif [ "$1" = "--start" ]; then\n` +
    `  echo "pulseaudio started" >>"$STUB_OUT"\n` +
    `  exit 0\n` +
    `fi`);

  // pactl stub
  writeStub(stubDir, 'pactl', `#!/bin/bash\n` +
    `echo "pactl $@" >>"$STUB_OUT"\n` +
    `if [ "$1" = "list" ] && [ "$2" = "short" ] && [ "$3" = "sinks" ]; then\n` +
    `  printf "%s" "${opts.sinks ?? ''}"\n` +
    `elif [ "$1" = "list" ] && [ "$2" = "short" ] && [ "$3" = "sources" ]; then\n` +
    `  printf "%s" "${opts.sources ?? ''}"\n` +
    `elif [ "$1" = "list" ] && [ "$2" = "short" ] && [ "$3" = "sink-inputs" ]; then\n` +
    `  printf "%s" "${opts.sinkInputs ?? ''}"\n` +
    `fi`);

  // pgrep stub
  writeStub(stubDir, 'pgrep', `#!/bin/bash\n` +
    `echo "pgrep $@" >>"$STUB_OUT"\n` +
    `if [ ${opts.audioBridgePresent ? 1 : 0} -eq 1 ]; then exit 0; else exit 1; fi`);

  // pkill stub
  writeStub(stubDir, 'pkill', `#!/bin/bash\n` +
    `echo "pkill $@" >>"$STUB_OUT"`);

  // audio-bridge stub
  writeStub(stubDir, 'audio-bridge', `#!/bin/bash\n` +
    `echo "audio-bridge invoked" >>"$STUB_OUT"`);

  // link other required utilities
  for (const cmd of ['date', 'tee', 'grep', 'awk', 'sleep', 'nohup']) {
    const real = findCmd(cmd);
    fs.symlinkSync(real, path.join(stubDir, cmd));
  }

  return { stubDir, stubLog };
}

// Test: starts pulseaudio when not running
// ----------------------------------------
test('starts pulseaudio when not running', () => {
  const { stubDir, stubLog } = setupBaseEnv({ paCheck: 1 });
  const logFile = path.join(stubDir, 'log');
  const result = spawnSync('/bin/bash', [script], {
    env: {
      LOG_FILE: logFile,
      PATH: `${stubDir}:/usr/bin:/bin`,
      STUB_OUT: stubLog,
    },
    encoding: 'utf8',
  });
  assert.strictEqual(result.status, 0);
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.match(stub, /pulseaudio --start/);
});

// Test: skips starting pulseaudio if already running
// --------------------------------------------------
test('does not start pulseaudio when already running', () => {
  const { stubDir, stubLog } = setupBaseEnv({ paCheck: 0 });
  const logFile = path.join(stubDir, 'log');
  const result = spawnSync('/bin/bash', [script], {
    env: {
      LOG_FILE: logFile,
      PATH: `${stubDir}:/usr/bin:/bin`,
      STUB_OUT: stubLog,
    },
    encoding: 'utf8',
  });
  assert.strictEqual(result.status, 0);
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.ok(!stub.includes('pulseaudio --start'));
});

// Test: create virtual_speaker only when absent
// ---------------------------------------------
test('creates virtual_speaker sink when missing', () => {
  const { stubDir, stubLog } = setupBaseEnv({ paCheck: 0, sinks: '1\tsome_sink\n' });
  const logFile = path.join(stubDir, 'log');
  spawnSync('/bin/bash', [script], {
    env: {
      LOG_FILE: logFile,
      PATH: `${stubDir}:/usr/bin:/bin`,
      STUB_OUT: stubLog,
    },
    encoding: 'utf8',
  });
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.match(stub, /pactl load-module/);
});

// ensure load-module not called when sink exists
test('does not create sink when already present', () => {
  const { stubDir, stubLog } = setupBaseEnv({ paCheck: 0, sinks: '1\tvirtual_speaker\n' });
  const logFile = path.join(stubDir, 'log');
  spawnSync('/bin/bash', [script], {
    env: {
      LOG_FILE: logFile,
      PATH: `${stubDir}:/usr/bin:/bin`,
      STUB_OUT: stubLog,
    },
    encoding: 'utf8',
  });
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.ok(!/pactl load-module/.test(stub));
});

// Test: restart audio-bridge when present
// ---------------------------------------
test('restarts audio-bridge when running', () => {
  const { stubDir, stubLog } = setupBaseEnv({ paCheck: 0, audioBridgePresent: true, sinks: '1\tvirtual_speaker\n' });
  const logFile = path.join(stubDir, 'log');
  const result = spawnSync('/bin/bash', [script], {
    env: {
      LOG_FILE: logFile,
      PATH: `${stubDir}:/usr/bin:/bin`,
      STUB_OUT: stubLog,
    },
    encoding: 'utf8',
  });
  assert.strictEqual(result.status, 0);
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.match(stub, /pgrep -f audio-bridge/);
  assert.match(stub, /pkill -f audio-bridge/);
  assert.match(stub, /audio-bridge invoked/);
  const log = fs.readFileSync(logFile, 'utf8');
  assert.match(log, /Restarting audio-bridge/);
});

// ensure audio-bridge not restarted when absent
test('does not restart audio-bridge when not running', () => {
  const { stubDir, stubLog } = setupBaseEnv({
    paCheck: 0,
    audioBridgePresent: false,
    sinks: '1\tvirtual_speaker\n',
  });
  const logFile = path.join(stubDir, 'log');
  const result = spawnSync('/bin/bash', [script], {
    env: {
      LOG_FILE: logFile,
      PATH: `${stubDir}:/usr/bin:/bin`,
      STUB_OUT: stubLog,
    },
    encoding: 'utf8',
  });
  assert.strictEqual(result.status, 0);
  const stub = fs.readFileSync(stubLog, 'utf8');
  assert.ok(!/pkill -f audio-bridge/.test(stub));
  assert.ok(!/audio-bridge invoked/.test(stub));
  const log = fs.readFileSync(logFile, 'utf8');
  assert.ok(!/Restarting audio-bridge/.test(log));
});

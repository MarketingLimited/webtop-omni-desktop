#!/usr/bin/env bash
set -euo pipefail

PULSE_USER="${PULSE_USER:-${DEV_USERNAME:-devuser}}"
PULSE_UID="${PULSE_UID:-$(id -u "$PULSE_USER" 2>/dev/null || echo 1000)}"
LOGFILE="${PULSE_LOGFILE:-/var/log/pulseaudio-startup.log}"

# 1. Confirm required packages are installed
REQUIRED_PKGS=(pulseaudio pulseaudio-utils alsa-utils)
echo "Checking required audio packages..."
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "Missing required package: $pkg" >&2
    exit 1
  fi
done
echo "All required packages are installed."

# 2. Ensure PulseAudio runs with a user who can manage audio devices
if ! id "$PULSE_USER" >/dev/null 2>&1; then
  echo "User $PULSE_USER does not exist" >&2
  exit 1
fi
if ! id -nG "$PULSE_USER" | grep -qw audio; then
  echo "User $PULSE_USER is not in audio group" >&2
  exit 1
fi

RUNTIME_DIR="/run/user/$PULSE_UID"
PULSE_DIR="$RUNTIME_DIR/pulse"
mkdir -p "$PULSE_DIR"
chown -R "$PULSE_USER:$PULSE_USER" "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

# 3. Remove stale PID files or instances
rm -f "$PULSE_DIR"/*.pid 2>/dev/null || true
pkill -u "$PULSE_UID" pulseaudio >/dev/null 2>&1 || true
# PulseAudio's native UNIX socket path.  If a previous run crashed or exited
# without cleaning up, the leftover file will block the daemon from binding to
# the same address again, so ensure it is removed before startup.
NATIVE_SOCKET="$PULSE_DIR/native"
if [ -e "$NATIVE_SOCKET" ]; then
  echo "Removing stale PulseAudio socket: $NATIVE_SOCKET"
  rm -f "$NATIVE_SOCKET"
fi

start_pulseaudio() {
  local mode="$1"
  local cmd="pulseaudio -D --log-target=file:$LOGFILE"
  if [ "$mode" = "tcp" ]; then
    cmd="pulseaudio -D --exit-idle-time=-1 --load=module-native-protocol-tcp --log-target=file:$LOGFILE"
  fi
  su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; $cmd"
}

# 4. Start PulseAudio in daemon mode and log output
# PA_MODE records how clients should connect: "unix" uses the native socket and
# "tcp" enables module-native-protocol-tcp for network access.
PA_MODE="unix"
start_pulseaudio "$PA_MODE"

for i in {1..10}; do
  if grep -q 'Daemon startup complete' "$LOGFILE" || grep -q 'READY=1' "$LOGFILE"; then
    echo "PulseAudio reported successful startup."
    break
  fi
  sleep 1
done

if ! grep -q 'Daemon startup complete' "$LOGFILE" && ! grep -q 'READY=1' "$LOGFILE"; then
  echo "PulseAudio log does not show successful startup" >&2
  exit 1
fi

wait_for_pactl() {
  local server_flag="$1"
  local label="$2"
  echo "Waiting for PulseAudio availability$label..."
  for i in {1..20}; do
    if su - "$PULSE_USER" -c "$server_flag pactl info" >/dev/null 2>&1; then
      echo "pactl info succeeded$label."
      return 0
    fi
    echo "PulseAudio not ready$label (attempt $i/20)" >&2
    sleep 1
  done
  return 1
}

# Try connecting over the expected UNIX socket.  If pactl cannot reach the
# daemon, assume the bind failed (e.g. another socket is already in use) and
# restart in TCP mode.
if ! wait_for_pactl "export XDG_RUNTIME_DIR=$RUNTIME_DIR;" ""; then
  echo "Initial PulseAudio startup failed, retrying with TCP..." >&2
  pkill -u "$PULSE_UID" pulseaudio >/dev/null 2>&1 || true
  rm -f "$NATIVE_SOCKET" 2>/dev/null || true
  PA_MODE="tcp"  # remember active protocol for later checks and logging
  start_pulseaudio "$PA_MODE"
  for i in {1..10}; do
    if grep -q 'Daemon startup complete' "$LOGFILE" || grep -q 'READY=1' "$LOGFILE"; then
      echo "PulseAudio reported successful startup."
      break
    fi
    sleep 1
  done
  wait_for_pactl "PULSE_SERVER=tcp:127.0.0.1:4713" " over TCP" || {
    echo "Failed to connect to PulseAudio with pactl info" >&2
    echo "Check $LOGFILE for details" >&2
    exit 1
  }
fi

# 6. Health check for sinks/sources
echo "Performing PulseAudio health check..."
if [ "$PA_MODE" = "tcp" ]; then
  PACTL_PREFIX="PULSE_SERVER=tcp:127.0.0.1:4713"
else
  PACTL_PREFIX="export XDG_RUNTIME_DIR=$RUNTIME_DIR;"
fi
SINKS=$(su - "$PULSE_USER" -c "$PACTL_PREFIX pactl list short sinks" 2>/dev/null)
if [ -z "$SINKS" ]; then
  echo "Health check failed: no PulseAudio sinks found" >&2
  exit 1
fi
echo "$SINKS"

echo "PulseAudio is ready using $PA_MODE."
echo "PulseAudio bound to $PA_MODE" >> "$LOGFILE"

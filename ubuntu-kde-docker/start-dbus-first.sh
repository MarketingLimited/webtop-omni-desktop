#!/bin/bash
set -euo pipefail

echo "INFO: Robust D-Bus starter script initiated."

# Ensure basic runtime environment variables are set to avoid mysterious
# dbus-daemon exits when $HOME or $XDG_RUNTIME_DIR are missing.
export HOME="${HOME:-/root}"

# Prefer an XDG runtime directory for the non-root dev user when available.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${DEV_UID:-1000}}"
if [ ! -d "$RUNTIME_DIR" ]; then
  mkdir -p "$RUNTIME_DIR"
  chown "${DEV_UID:-1000}:${DEV_GID:-1000}" "$RUNTIME_DIR" 2>/dev/null || true
  chmod 700 "$RUNTIME_DIR" 2>/dev/null || true
fi
export XDG_RUNTIME_DIR="$RUNTIME_DIR"

# 1. Ensure directory exists with correct permissions
# The messagebus user may not exist yet in some minimal images. Create the
# directory as root first, then adjust ownership if possible to avoid crashes.
if ! install -o messagebus -g messagebus -m 755 -d /run/dbus 2>/dev/null; then
  mkdir -p /run/dbus
  chown messagebus:messagebus /run/dbus 2>/dev/null || true
  chmod 755 /run/dbus
fi

# Some base images ship without a machine-id which causes
# dbus-daemon to exit immediately.  Ensure one exists before
# attempting to start the service.
if [ ! -s /etc/machine-id ]; then
  dbus-uuidgen --ensure=/etc/machine-id >/dev/null 2>&1 || true
fi

if pgrep -x dbus-daemon >/dev/null; then
  echo "INFO: D-Bus daemon already running."
  if [ -f /run/dbus/pid ]; then
    DBUS_PID=$(cat /run/dbus/pid)
  else
    DBUS_PID=$(pgrep -x dbus-daemon | head -n 1)
    echo "$DBUS_PID" > /run/dbus/pid
  fi
else
  # 2. Clean up stale files from a previous run
  rm -f /run/dbus/system_bus_socket /run/dbus/pid

  echo "INFO: Starting system D-Bus daemon."
  # 3. Start the system D-Bus daemon. Keep it in the foreground for supervisor.
  # Also write its PID so subsequent scripts know it's running.
  /usr/bin/dbus-daemon --system --nofork --nosyslog --print-pid=/run/dbus/pid &
  DBUS_PID=$!

  # 4. Wait for the D-Bus socket to be created
  echo "INFO: Waiting for D-Bus socket to be created..."
  counter=0
  while [ ! -S /run/dbus/system_bus_socket ] && [ $counter -lt 20 ]; do
    sleep 0.5
    counter=$((counter+1))
  done

  if [ ! -S /run/dbus/system_bus_socket ]; then
    echo "ERROR: D-Bus socket was not created in time. Exiting."
    kill "$DBUS_PID"
    exit 1
  fi
  echo "INFO: D-Bus socket is up."
fi

trap 'kill "$DBUS_PID" 2>/dev/null' EXIT

# 5. Start accounts-daemon if available and not running
echo "INFO: Starting accounts-daemon."
if ! pgrep -x accounts-daemon >/dev/null; then
  if [ -x /usr/libexec/accounts-daemon ]; then
      /usr/libexec/accounts-daemon &
  elif [ -x /usr/lib/accountsservice/accounts-daemon ]; then
      /usr/lib/accountsservice/accounts-daemon &
  else
      echo "WARNING: accounts-daemon not found."
  fi
else
  echo "INFO: accounts-daemon already running."
fi

# 6. Start polkitd if available and not running
echo "INFO: Starting polkitd."
if ! pgrep -x polkitd >/dev/null; then
  if [ -x /usr/lib/polkit-1/polkitd ]; then
      /usr/lib/polkit-1/polkitd --no-debug &
  else
      echo "WARNING: polkitd not found."
  fi
else
  echo "INFO: polkitd already running."
fi

echo "INFO: D-Bus and related services startup sequence complete."

# Wait for the main dbus-daemon process. If it dies, this script will exit and supervisor will restart it.
wait "$DBUS_PID"

#!/usr/bin/env bash
set -euo pipefail

# Purpose: Validate that D-Bus and polkitd are functional
# This script starts temporary instances if necessary and uses pkcheck
# to verify that polkitd responds to authorization queries.

if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root." >&2
  exit 1
fi

command -v dbus-daemon >/dev/null || { echo "❌ dbus-daemon not found" >&2; exit 1; }
command -v /usr/lib/polkit-1/polkitd >/dev/null || { echo "❌ polkitd binary not found" >&2; exit 1; }
command -v pkcheck >/dev/null || { echo "❌ pkcheck not found" >&2; exit 1; }

mkdir -p /run/dbus

echo "🔍 Testing PolicyKit configuration..."

DBUS_TEMP=0
POLKIT_TEMP=0
DBUS_PID=""
POLKIT_PID=""

cleanup() {
  if [[ $POLKIT_TEMP -eq 1 && -n ${POLKIT_PID} ]]; then
    kill "$POLKIT_PID" 2>/dev/null || true
    wait "$POLKIT_PID" 2>/dev/null || true
  fi
  if [[ $DBUS_TEMP -eq 1 && -n ${DBUS_PID} ]]; then
    kill "$DBUS_PID" 2>/dev/null || true
    wait "$DBUS_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Ensure D-Bus is running
if ! pgrep -x dbus-daemon >/dev/null; then
  echo "⚠️  D-Bus is not running, starting temporary instance..."
  dbus-daemon --system --fork --nopidfile
  DBUS_PID=$(pgrep -n dbus-daemon)
  DBUS_TEMP=1
else
  echo "✅ D-Bus is running"
fi

# Ensure polkitd is running
if pgrep -x polkitd >/dev/null; then
  echo "ℹ️  polkitd already running"
else
  echo "🧪 Testing polkitd startup..."
  /usr/lib/polkit-1/polkitd --no-debug --replace &
  POLKIT_PID=$!
  POLKIT_TEMP=1
  sleep 3
  if ! kill -0 "$POLKIT_PID" 2>/dev/null; then
    echo "❌ polkitd failed to start"
    exit 1
  fi
  echo "✅ polkitd started successfully"
fi

# Verify polkit responsiveness
if pkcheck --action-id org.freedesktop.policykit.exec --process $$ >/dev/null 2>&1; then
  echo "✅ polkitd responded to pkcheck"
else
  echo "❌ pkcheck failed to communicate with polkitd"
  exit 1
fi

echo "🎉 PolicyKit test completed successfully"

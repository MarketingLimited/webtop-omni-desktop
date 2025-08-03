#!/bin/bash
set -e

echo "🔍 Testing PolicyKit configuration..."

# Test if D-Bus is running; start temporary instance if needed
DBUS_TEMP=0
DBUS_PID=$(pgrep -x dbus-daemon | head -n1 || true)
if [ -z "$DBUS_PID" ] || [ "$(ps -o state= -p "$DBUS_PID" | tr -d ' ')" = "Z" ]; then
    echo "⚠️  D-Bus is not running, starting temporary instance..."
    dbus-daemon --system --fork --nopidfile
    DBUS_PID=$(pgrep -n dbus-daemon)
    DBUS_TEMP=1
fi
echo "✅ D-Bus is running"

# Test if polkitd can start manually
echo "🧪 Testing polkitd startup..."
/usr/lib/polkit-1/polkitd --no-debug --replace &
POLKIT_PID=$!
sleep 3

if kill -0 $POLKIT_PID 2>/dev/null; then
    echo "✅ polkitd started successfully"
    kill $POLKIT_PID
else
    echo "❌ polkitd failed to start"
    [ "$DBUS_TEMP" -eq 1 ] && kill "$DBUS_PID"
    exit 1
fi

[ "$DBUS_TEMP" -eq 1 ] && kill "$DBUS_PID"

echo "🎉 PolicyKit test completed successfully"

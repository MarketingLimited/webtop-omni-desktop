#!/bin/bash
set -e

echo "🔍 Testing PolicyKit configuration..."

# Test if D-Bus is running
if ! pgrep -x dbus-daemon >/dev/null; then
    echo "❌ D-Bus is not running"
    exit 1
fi
echo "✅ D-Bus is running"

# Test if polkitd can start manually
echo "🧪 Testing polkitd startup..."
if /usr/lib/polkit-1/polkitd --no-debug --replace &
POLKIT_PID=$!
sleep 3

if kill -0 $POLKIT_PID 2>/dev/null; then
    echo "✅ polkitd started successfully"
    kill $POLKIT_PID
else
    echo "❌ polkitd failed to start"
    exit 1
fi

echo "🎉 PolicyKit test completed successfully"
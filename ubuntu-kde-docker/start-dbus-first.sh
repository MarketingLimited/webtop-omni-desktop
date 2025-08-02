#!/bin/bash
set -e

echo "INFO: Robust D-Bus starter script initiated."

# 1. Ensure directories exist and have correct permissions
mkdir -p /run/dbus
chown messagebus:messagebus /run/dbus
chmod 755 /run/dbus

# 2. Clean up stale files from a previous run
rm -f /run/dbus/system_bus_socket
rm -f /run/dbus/pid

echo "INFO: Starting system D-Bus daemon."
# 3. Start the system D-Bus daemon. We will keep it in the foreground for supervisor.
# The script will wait for it at the end.
/usr/bin/dbus-daemon --system --nofork --nosyslog &
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
  kill $DBUS_PID
  exit 1
fi
echo "INFO: D-Bus socket is up."

# 5. Start accounts-daemon
echo "INFO: Starting accounts-daemon."
# Path from startup log
if [ -x /usr/libexec/accounts-daemon ]; then
    /usr/libexec/accounts-daemon &
# Other common path
elif [ -x /usr/lib/accountsservice/accounts-daemon ]; then
    /usr/lib/accountsservice/accounts-daemon &
else
    echo "WARNING: accounts-daemon not found."
fi

# 6. Start polkitd
echo "INFO: Starting polkitd."
# Common path for polkitd
if [ -x /usr/lib/polkit-1/polkitd ]; then
    /usr/lib/polkit-1/polkitd --no-debug &
else
    echo "WARNING: polkitd not found."
fi

echo "INFO: D-Bus and related services startup sequence complete."

# Wait for the main dbus-daemon process. If it dies, this script will exit and supervisor will restart it.
wait $DBUS_PID

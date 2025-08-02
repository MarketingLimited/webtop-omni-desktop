#!/bin/bash
set -e

echo "INFO: Robust VNC starter script initiated."

# 1. Wait for the D-Bus socket to be created
echo "INFO: Waiting for D-Bus socket before starting VNC..."
counter=0
while [ ! -S /run/dbus/system_bus_socket ] && [ $counter -lt 30 ]; do
  sleep 1
  counter=$((counter+1))
done

if [ ! -S /run/dbus/system_bus_socket ]; then
  echo "ERROR: D-Bus socket not available. VNC will not start."
  exit 1
fi
echo "INFO: D-Bus is ready."

# 2. Ensure .Xauthority file exists
# The vncserver script should handle this, but as a fallback, we can touch it.
# The log showed "xauth: file /root/.Xauthority does not exist"
# The VNC server is run as root according to supervisord.conf
if [ ! -f /root/.Xauthority ]; then
    echo "INFO: .Xauthority file not found. Creating it."
    touch /root/.Xauthority
fi

echo "INFO: Starting KasmVNC server."
# 3. Start the VNC server using the KasmVNC binary.
# We use exec to replace the shell process with the kasmvncserver process.
exec /usr/bin/kasmvncserver :1

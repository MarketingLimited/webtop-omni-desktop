#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"

echo "🚌 Setting up container-optimized D-Bus configuration..."

# Create D-Bus directories
mkdir -p /run/dbus
mkdir -p /var/lib/dbus
mkdir -p /etc/dbus-1/system.d
mkdir -p /etc/dbus-1/session.d
mkdir -p /run/user/${DEV_UID}

# Create container-specific D-Bus system configuration
cat > /etc/dbus-1/system.conf << 'EOF'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>system</type>
  <listen>unix:path=/run/dbus/system_bus_socket</listen>
  
  <policy context="default">
    <allow user="*"/>
    <allow own="*"/>
    <allow send_destination="*" send_interface="*"/>
    <allow receive_destination="*" receive_interface="*"/>
  </policy>
  
  <!-- Container-optimized policies -->
  <policy user="root">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_destination="*"/>
  </policy>
  
  <policy user="devuser">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_destination="*"/>
  </policy>
  
  <limit name="max_incoming_bytes">1000000000</limit>
  <limit name="max_outgoing_bytes">1000000000</limit>
  <limit name="max_message_size">1000000000</limit>
  <limit name="service_start_timeout">120000</limit>
  <limit name="auth_timeout">240000</limit>
  <limit name="pending_fd_timeout">150000</limit>
  <limit name="max_completed_connections">100000</limit>
  <limit name="max_incomplete_connections">10000</limit>
  <limit name="max_connections_per_user">100000</limit>
  <limit name="max_pending_service_starts">10000</limit>
  <limit name="max_names_per_connection">50000</limit>
  <limit name="max_match_rules_per_connection">50000</limit>
</busconfig>
EOF

# Create session D-Bus configuration
cat > /etc/dbus-1/session.conf << 'EOF'
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path=/run/user/1000/bus</listen>
  
  <standard_session_servicedirs />
  
  <policy context="default">
    <allow send_destination="*" send_interface="*"/>
    <allow receive_destination="*" receive_interface="*"/>
    <allow own="*"/>
  </policy>
  
  <limit name="max_incoming_bytes">1000000000</limit>
  <limit name="max_outgoing_bytes">1000000000</limit>
  <limit name="max_message_size">1000000000</limit>
</busconfig>
EOF

# Create D-Bus startup script
cat > /usr/local/bin/start-dbus << 'EOF'
#!/bin/bash

# Start system D-Bus
mkdir -p /run/dbus
if [ ! -f /run/dbus/pid ]; then
    dbus-daemon --system --fork --print-pid > /run/dbus/pid 2>/dev/null || true
fi

# Start session D-Bus for devuser
mkdir -p /run/user/1000
chown devuser:devuser /run/user/1000
chmod 700 /run/user/1000

sudo -u devuser bash -c '
export XDG_RUNTIME_DIR=/run/user/1000
if [ ! -f /run/user/1000/dbus.pid ]; then
    dbus-daemon --session --fork --print-pid > /run/user/1000/dbus.pid 2>/dev/null || true
fi
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
'

echo "D-Bus services started"
EOF

chmod +x /usr/local/bin/start-dbus

# Create D-Bus health check
cat > /usr/local/bin/check-dbus << 'EOF'
#!/bin/bash

# Check system D-Bus
if ! dbus-send --system --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
    echo "System D-Bus not accessible"
    exit 1
fi

# Check session D-Bus
if ! sudo -u devuser bash -c 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus; dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames' >/dev/null 2>&1; then
    echo "Session D-Bus not accessible"
    exit 1
fi

echo "D-Bus services healthy"
EOF

chmod +x /usr/local/bin/check-dbus

# Set proper permissions
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" /run/user/${DEV_UID}
chmod 700 /run/user/${DEV_UID}

echo "✅ Container D-Bus configuration complete"
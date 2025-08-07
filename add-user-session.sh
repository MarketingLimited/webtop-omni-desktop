#!/bin/bash
set -euo pipefail

# add-user-session.sh USERNAME
#
# Allocates a free Xvfb display and matching VNC/websocket ports for USERNAME.
# A supervisor configuration snippet is written to /etc/supervisor/conf.d
# and the mapping is recorded in /var/log/webtop/user_ports.csv.

USERNAME=${1:-}
if [[ -z "$USERNAME" ]]; then
    echo "Usage: $0 USERNAME" >&2
    exit 1
fi

CONF_DIR="/etc/supervisor/conf.d"
MAP_FILE="/var/log/webtop/user_ports.csv"

# Ensure mapping file exists with header
mkdir -p "$(dirname "$MAP_FILE")"
if [[ ! -f "$MAP_FILE" ]]; then
    echo "user,display,vnc_port,websocket_port" > "$MAP_FILE"
fi

# Do nothing if user already configured
if grep -q "^$USERNAME," "$MAP_FILE" 2>/dev/null; then
    echo "User $USERNAME already configured" >&2
    exit 0
fi

is_port_free() {
    local port=$1
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port$" && return 1 || return 0
}

display=2
while true; do
    vnc_port=$((5900 + display))
    ws_port=$((6080 + display))
    if grep -q "^.*,:$display," "$MAP_FILE" 2>/dev/null; then
        display=$((display + 1))
        continue
    fi
    if ! is_port_free "$vnc_port" || ! is_port_free "$ws_port"; then
        display=$((display + 1))
        continue
    fi
    break
done

cat >"$CONF_DIR/user-$USERNAME.conf" <<EOF
[program:Xvfb_$USERNAME]
command=/usr/bin/Xvfb :$display -screen 0 1920x1080x24 -dpi 96 +extension GLX +render -noreset -ac
priority=10
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/xvfb_$USERNAME.log
stderr_logfile=/var/log/supervisor/xvfb_$USERNAME.log

[program:X11VNC_$USERNAME]
command=/bin/sh -c "sleep 5; exec /usr/bin/x11vnc -display :$display -rfbport $vnc_port -forever -shared -nopw -xkb -noxrecord -noxfixes -noxdamage -wait 5"
priority=35
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/x11vnc_$USERNAME.log
stderr_logfile=/var/log/supervisor/x11vnc_$USERNAME.log

[program:noVNC_$USERNAME]
command=/usr/bin/websockify --web=/usr/share/novnc/ $ws_port localhost:$vnc_port
priority=37
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/supervisor/novnc_$USERNAME.log
stderr_logfile=/var/log/supervisor/novnc_$USERNAME.log
EOF

echo "$USERNAME,:$display,$vnc_port,$ws_port" >> "$MAP_FILE"

if command -v supervisorctl >/dev/null 2>&1; then
    supervisorctl reread >/dev/null 2>&1 || true
    supervisorctl update >/dev/null 2>&1 || true
fi

echo "Configured $USERNAME on display :$display (VNC $vnc_port, web $ws_port)"


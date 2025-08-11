#!/usr/bin/env bash
set -euo pipefail

DESK_USER="${DEV_USERNAME:-devuser}"
PULSE_TCP='tcp:127.0.0.1:4713'

echo "🔊 Setting up PulseAudio TCP configuration..."

# System-wide Pulse client defaults
mkdir -p /etc/pulse
cat >/etc/pulse/client.conf <<EOF
autospawn = no
default-server = ${PULSE_TCP}
EOF

# Unified daemon configuration for stable 48 kHz pipeline
cat >/etc/pulse/daemon.conf <<'EOF'
default-sample-format = s16le
default-sample-rate = 48000
alternate-sample-rate = 48000
avoid-resampling = yes
resample-method = soxr-vhq
flat-volumes = no
default-fragments = 8
default-fragment-size-msec = 40
exit-idle-time = -1
EOF

# User Pulse client defaults and mirrored daemon.conf
mkdir -p "/home/${DESK_USER}/.config/pulse"
cat >"/home/${DESK_USER}/.config/pulse/client.conf" <<EOF
autospawn = no
default-server = ${PULSE_TCP}
EOF
cp /etc/pulse/daemon.conf "/home/${DESK_USER}/.config/pulse/daemon.conf"
chown -R "${DESK_USER}:${DESK_USER}" "/home/${DESK_USER}/.config/pulse"

# Login env for new sessions
grep -q PULSE_SERVER= /etc/environment || echo "PULSE_SERVER=${PULSE_TCP}" >> /etc/environment
cat >/etc/profile.d/99-pulse.sh <<EOF
export PULSE_SERVER=${PULSE_TCP}
export PULSE_LATENCY_MSEC=180
EOF
chmod +x /etc/profile.d/99-pulse.sh

# Ensure PipeWire is not taking over
pkill -u "${DESK_USER}" -f "pipewire|pipewire-pulse" 2>/dev/null || true

echo "✅ PulseAudio TCP configuration complete"
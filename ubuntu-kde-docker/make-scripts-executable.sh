#!/bin/bash
# Make all container scripts executable
set -euo pipefail

echo "Making container scripts executable..."

# Core scripts
chmod +x /usr/local/bin/start-dbus-first.sh
chmod +x /usr/local/bin/wait-for-dbus.sh
chmod +x /usr/local/bin/setup-desktop.sh
chmod +x /usr/local/bin/system-validation.sh
chmod +x /usr/local/bin/enhanced-service-monitor.sh

# Audio related scripts
chmod +x /usr/local/bin/audio-monitor.sh
chmod +x /usr/local/bin/create-virtual-audio-devices.sh

# VNC and other service scripts
chmod +x /usr/local/bin/start-vnc-robust.sh

echo "✅ All scripts are now executable"
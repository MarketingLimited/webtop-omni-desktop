#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🤖 Setting up Waydroid for Android apps..."

# Initialize Waydroid (this may fail in some environments)
echo "🔧 Initializing Waydroid..."
waydroid init || echo "⚠️  Waydroid initialization failed - this is expected in some container environments"

# Create desktop shortcuts
mkdir -p "${DEV_HOME}/.local/share/applications"

cat > "${DEV_HOME}/.local/share/applications/waydroid.desktop" << 'EOF'
[Desktop Entry]
Name=Waydroid
Comment=Android container for marketing apps
Exec=waydroid show-full-ui
Icon=android
Terminal=false
Type=Application
Categories=System;Emulator;
EOF

# Create Android Apps folder on desktop
mkdir -p "${DEV_HOME}/Desktop/Android Apps"
cp "${DEV_HOME}/.local/share/applications/waydroid"*.desktop "${DEV_HOME}/Desktop/Android Apps/"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Waydroid setup complete (may require kernel modules for full functionality)"
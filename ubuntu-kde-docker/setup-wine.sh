#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🍷 Setting up Wine for Windows applications..."

# Clean up any existing Wine state
rm -rf "${DEV_HOME}/.wine"
rm -f /tmp/.X*-lock
killall -q Xvfb wineserver wine 2>/dev/null || true

# Initialize Wine prefix with 32-bit architecture
export WINEPREFIX="${DEV_HOME}/.wine"
export WINEARCH="win32"
export WINEDLLOVERRIDES="mscoree,mshtml="
mkdir -p "$WINEPREFIX"

# Start a virtual display if needed
if ! pgrep Xvfb >/dev/null; then
    Xvfb :99 -screen 0 1024x768x16 &
    sleep 2
fi
export DISPLAY=:99

# Ensure Wine prefix is properly owned
mkdir -p "$WINEPREFIX"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "$WINEPREFIX"

# Set up Wine as the dev user
sudo -u "$DEV_USERNAME" bash << 'WINE_SETUP'
export WINEPREFIX="/home/devuser/.wine"
export WINEARCH="win32"
export WINEDLLOVERRIDES="mscoree,mshtml="
export DISPLAY=:99

# Initialize Wine with no GUI prompts
echo "🔧 Initializing Wine prefix..."
WINEDEBUG=-all wine wineboot --init 2>/dev/null || true

# Install essential Windows components (container-optimized)
echo "📦 Installing Wine components..."
# Only install essential components that work in containers
WINEDEBUG=-all winetricks -q --unattended corefonts 2>/dev/null || true
WINEDEBUG=-all winetricks -q --unattended vcrun2019 2>/dev/null || true

# Skip problematic components that cause DLL errors in containers
echo "⚠️  Skipping container-incompatible Wine components"

echo "✅ Wine setup completed"
WINE_SETUP

# Final ownership fix
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "$WINEPREFIX"

# Create desktop shortcuts
mkdir -p "${DEV_HOME}/.local/share/applications"

cat > "${DEV_HOME}/.local/share/applications/wine-notepad.desktop" << 'EOF'
[Desktop Entry]
Name=Wine Notepad
Comment=Windows Notepad via Wine
Exec=wine notepad
Icon=text-editor
Terminal=false
Type=Application
Categories=Utility;TextEditor;
EOF

cat > "${DEV_HOME}/.local/share/applications/wine-config.desktop" << 'EOF'
[Desktop Entry]
Name=Wine Configuration
Comment=Configure Wine settings
Exec=winecfg
Icon=preferences-system
Terminal=false
Type=Application
Categories=Settings;System;
EOF

# Create Windows Programs folder on desktop
mkdir -p "${DEV_HOME}/Desktop/Windows Programs"
cp "${DEV_HOME}/.local/share/applications/wine-"*.desktop "${DEV_HOME}/Desktop/Windows Programs/"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Wine setup complete"


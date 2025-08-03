#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🍷 Setting up Wine for Windows applications..."

# Initialize Wine prefix with proper architecture
export WINEPREFIX="${DEV_HOME}/.wine"
export WINEARCH="win64"
export WINEDLLOVERRIDES="mscoree,mshtml="
mkdir -p "$WINEPREFIX"

# Ensure Wine prefix is properly owned
mkdir -p "$WINEPREFIX"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "$WINEPREFIX"

# Set up Wine as the dev user
sudo -u "$DEV_USERNAME" bash << 'WINE_SETUP'
export WINEPREFIX="/home/devuser/.wine"
export WINEARCH="win64"
export WINEDLLOVERRIDES="mscoree,mshtml="
export DISPLAY=:1

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
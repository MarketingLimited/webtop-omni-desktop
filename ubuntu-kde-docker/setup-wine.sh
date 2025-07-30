#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🍷 Setting up Wine for Windows applications..."

# Initialize Wine prefix
export WINEPREFIX="${DEV_HOME}/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="
mkdir -p "$WINEPREFIX"

# Set up Wine as the dev user
sudo -u "$DEV_USERNAME" bash << 'WINE_SETUP'
export WINEPREFIX="/home/devuser/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="
export DISPLAY=:1

# Initialize Wine
echo "🔧 Initializing Wine prefix..."
winecfg /v win10 || true

# Install essential Windows components
echo "📦 Installing Wine components..."
winetricks -q corefonts vcrun2019 dotnet48 gdiplus msxml6 d3dx9 || true

# Install additional libraries for marketing applications
winetricks -q win10 || true
winetricks -q ie8 || true
winetricks -q flash || true

echo "✅ Wine applications installed"
WINE_SETUP

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
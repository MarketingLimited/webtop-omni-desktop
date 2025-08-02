#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
WINEPREFIX="${DEV_HOME}/.wine"
WINEARCH="win64"
WINEDLLOVERRIDES="mscoree,mshtml="

echo "🍷 Setting up Wine for Windows applications..."

# Initialize Wine prefix directory and ensure ownership
mkdir -p "$WINEPREFIX"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "$WINEPREFIX"

# Set up Wine as the dev user
sudo -u "$DEV_USERNAME" \
  WINEPREFIX="$WINEPREFIX" \
  WINEARCH="$WINEARCH" \
  WINEDLLOVERRIDES="$WINEDLLOVERRIDES" \
  DISPLAY=:1 bash <<'WINE_SETUP'
set -euo pipefail

echo "🔧 Initializing Wine prefix..."
WINEDEBUG=-all wine wineboot --init 2>/dev/null || true

echo "📦 Installing Wine components..."
# Only install essential components that work in containers
WINEDEBUG=-all winetricks -q --unattended corefonts 2>/dev/null || true
WINEDEBUG=-all winetricks -q --unattended vcrun2019 2>/dev/null || true

echo "⚠️  Skipping container-incompatible Wine components"

echo "✅ Wine setup completed"
WINE_SETUP

# Create desktop shortcuts
mkdir -p "${DEV_HOME}/.local/share/applications"

cat > "${DEV_HOME}/.local/share/applications/wine-notepad.desktop" <<'EOF2'
[Desktop Entry]
Name=Wine Notepad
Comment=Windows Notepad via Wine
Exec=wine notepad
Icon=text-editor
Terminal=false
Type=Application
Categories=Utility;TextEditor;
EOF2

cat > "${DEV_HOME}/.local/share/applications/wine-config.desktop" <<'EOF3'
[Desktop Entry]
Name=Wine Configuration
Comment=Configure Wine settings
Exec=winecfg
Icon=preferences-system
Terminal=false
Type=Application
Categories=Settings;System;
EOF3

# Ensure desktop entries are executable
chmod +x "${DEV_HOME}/.local/share/applications/"wine-{notepad,config}.desktop

# Create Windows Programs folder on desktop
mkdir -p "${DEV_HOME}/Desktop/Windows Programs"
cp "${DEV_HOME}/.local/share/applications"/wine-*.desktop "${DEV_HOME}/Desktop/Windows Programs/"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Wine setup complete"


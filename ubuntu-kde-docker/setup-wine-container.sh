#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🍷 Setting up container-optimized Wine..."

# Create Wine directory structure
mkdir -p "${DEV_HOME}/.wine"
mkdir -p "${DEV_HOME}/.wine/drive_c/windows/system32"
mkdir -p "${DEV_HOME}/.wine/drive_c/Program Files"

# Set ownership first
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.wine" 2>/dev/null || true

# Configure Wine for container environment
sudo -u "$DEV_USERNAME" bash << 'WINE_CONTAINER_SETUP'
export WINEPREFIX="/home/devuser/.wine"
export WINEARCH="win64"
export WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d"
export DISPLAY=:1
export WINE_NO_SANDBOX=1

# Initialize Wine prefix with minimal setup
echo "🔧 Initializing container-optimized Wine..."
WINEDEBUG=-all wineboot --init 2>/dev/null || true

# Create minimal registry for container compatibility
cat > /tmp/wine-container.reg << 'WINE_REG'
REGEDIT4

[HKEY_CURRENT_USER\Software\Wine]
"Version"="wine-8.0"

[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"winemenubuilder.exe"="d"
"mscoree"=""
"mshtml"=""

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"Managed"="Y"
"Decorated"="Y"
"ClientSideGraphics"="Y"

[HKEY_CURRENT_USER\Software\Wine\DirectSound]
"DefaultPlayback"="pulse:default"
"DefaultCapture"="pulse:default"
WINE_REG

# Apply registry settings
WINEDEBUG=-all wine regedit /tmp/wine-container.reg 2>/dev/null || true
rm -f /tmp/wine-container.reg

# Install essential fonts only
echo "📦 Installing essential Wine components..."
WINEDEBUG=-all winetricks -q --unattended corefonts 2>/dev/null || true

echo "✅ Container Wine setup completed"
WINE_CONTAINER_SETUP

# Create Wine application launcher
cat > "${DEV_HOME}/.local/bin/wine-app-launcher" << 'EOF'
#!/bin/bash
export WINEPREFIX="/home/devuser/.wine"
export WINEARCH="win64"
export WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d"
export DISPLAY=:1
export WINE_NO_SANDBOX=1

# Launch Wine application
WINEDEBUG=-all wine "$@"
EOF

chmod +x "${DEV_HOME}/.local/bin/wine-app-launcher"

# Create Google Ads Editor web alternative
cat > "${DEV_HOME}/Desktop/Google Ads Editor (Web).desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Ads Editor (Web)
Comment=Google Ads management via web interface
Exec=firefox https://ads.google.com/
Icon=web-browser
Categories=Office;
Terminal=false
EOF

chmod +x "${DEV_HOME}/Desktop/Google Ads Editor (Web).desktop"

# Create Wine diagnostics tool
cat > "${DEV_HOME}/.local/bin/wine-diagnostics" << 'EOF'
#!/bin/bash
echo "=== Wine Container Diagnostics ==="
echo "Wine Version: $(wine --version 2>/dev/null || echo 'Not available')"
echo "Wine Prefix: $WINEPREFIX"
echo "Display: $DISPLAY"
echo ""
echo "=== Wine Registry Status ==="
if [ -f "$WINEPREFIX/system.reg" ]; then
    echo "✅ Wine registry exists"
else
    echo "❌ Wine registry missing"
fi
echo ""
echo "=== Available Windows Programs ==="
find "$WINEPREFIX/drive_c/Program Files" -name "*.exe" 2>/dev/null | head -10 || echo "No programs found"
EOF

chmod +x "${DEV_HOME}/.local/bin/wine-diagnostics"

# Set final ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}" 2>/dev/null || true

echo "✅ Container-optimized Wine setup complete"

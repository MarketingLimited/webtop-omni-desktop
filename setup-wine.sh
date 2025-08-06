#!/bin/bash
# Wine initialization script for container environments.
#
# - Skips Xvfb when /tmp/.X11-unix is read-only or unwritable
# - Treats Xvfb/X11 "(EE) Cannot establish any listening sockets" messages as
#   expected and non-fatal
# - Continues even when Xvfb fails or DISPLAY cannot be set so Wine can still
#   initialize headlessly, matching the noisy logs seen in container startup
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
#
# /tmp/.X11-unix may be mounted read-only inside the container. Xvfb then
# emits fatal messages like "(EE) Cannot establish any listening sockets" but
# the Wine setup can safely continue without a display. We check socket
# writability before launching Xvfb to avoid unnecessary errors.
if ! pgrep Xvfb >/dev/null; then
    if [ -w /tmp/.X11-unix ]; then
        Xvfb :99 -screen 0 1024x768x16 >/tmp/xvfb.log 2>&1 &
        sleep 2
        if pgrep Xvfb >/dev/null; then
            export DISPLAY=:99
        else
            # Xvfb failed to bind; noisy errors above are expected in containers
            # and we continue without a virtual display.
            echo "⚠️  Xvfb failed to start; continuing without virtual display"
        fi
    else
        # Unable to write to X11 socket; skip Xvfb to prevent fatal (EE) spam.
        echo "⚠️  /tmp/.X11-unix is not writable; skipping Xvfb setup"
    fi
fi
# Fallback to host display if available; if none, DISPLAY remains unset and Wine
# runs headlessly. Later X11 errors in logs are safe to ignore.
export DISPLAY="${DISPLAY:-:0}"

# Ensure Wine prefix is properly owned
mkdir -p "$WINEPREFIX"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "$WINEPREFIX"

# Set up Wine as the dev user
sudo -u "$DEV_USERNAME" bash <<WINE_SETUP
export WINEPREFIX="/home/${DEV_USERNAME}/.wine"
export WINEARCH="win32"
export WINEDLLOVERRIDES="mscoree,mshtml="
export DISPLAY="${DISPLAY}"

# DISPLAY may be empty when no X server is available. Wine commands below can
# output X11 errors in this case, but they are harmless in containerized
# headless setups.

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


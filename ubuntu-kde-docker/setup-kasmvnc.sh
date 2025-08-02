#!/bin/bash
set -euo pipefail

echo "🔧 Installing KasmVNC server..."

# Install required dependencies first
apt-get update
apt-get install -y \
    xvfb \
    xauth \
    x11-xserver-utils \
    x11-utils \
    x11-xkb-utils \
    xkb-data \
    fonts-liberation \
    dbus-x11 \
    libjpeg-turbo8 \
    libwebp7 \
    libssl3 \
    libpng16-16 \
    zlib1g \
    libxrandr2 \
    libxtst6 \
    libxfixes3 \
    libxdamage1 \
    libfontconfig1 \
    wget

# Install KasmVNC version 1.3.4 for the current architecture
ARCH="$(dpkg --print-architecture)"
RELEASE="noble"
VERSION="1.3.4"
DEB_URL="https://github.com/kasmtech/KasmVNC/releases/download/v${VERSION}/kasmvncserver_${RELEASE}_${VERSION}_${ARCH}.deb"

echo "🔧 Downloading KasmVNC for architecture: $ARCH"
if ! wget -q -O /tmp/kasmvncserver.deb "$DEB_URL"; then
    echo "❌ Failed to download KasmVNC package"
    # Try alternative architecture mappings
    case "$ARCH" in
        amd64) ALT_ARCH="x86_64" ;;
        arm64) ALT_ARCH="aarch64" ;;
        *) ALT_ARCH="$ARCH" ;;
    esac
    
    ALT_URL="https://github.com/kasmtech/KasmVNC/releases/download/v${VERSION}/kasmvncserver_${RELEASE}_${VERSION}_${ALT_ARCH}.deb"
    echo "🔧 Trying alternative URL with architecture: $ALT_ARCH"
    if ! wget -q -O /tmp/kasmvncserver.deb "$ALT_URL"; then
        echo "❌ Failed to download KasmVNC package with alternative architecture"
        exit 1
    fi
fi

echo "🔧 Installing KasmVNC package..."
if ! apt-get install -y /tmp/kasmvncserver.deb; then
    echo "❌ Failed to install KasmVNC package"
    exit 1
fi

rm -f /tmp/kasmvncserver.deb
apt-get clean

# Verify installation
if command -v kasmvncserver >/dev/null 2>&1; then
    echo "✅ KasmVNC server installed successfully"
    kasmvncserver -version || echo "✅ KasmVNC binary found at: $(which kasmvncserver)"
else
    echo "❌ KasmVNC installation verification failed"
    exit 1
fi

# Create VNC configuration directories
mkdir -p /etc/kasmvnc /root/.vnc /home/devuser/.vnc
chown -R devuser:devuser /home/devuser/.vnc 2>/dev/null || true

echo "✅ KasmVNC installation completed successfully"

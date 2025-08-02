#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🔧 Installing KasmVNC server..."

# Install required dependencies first
apt-get update
apt-get install -y --no-install-recommends \
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
BASE_URL="https://github.com/kasmtech/KasmVNC/releases/download/v${VERSION}"
DEB_URL="${BASE_URL}/kasmvncserver_${RELEASE}_${VERSION}_${ARCH}.deb"

echo "🔧 Downloading KasmVNC for architecture: $ARCH"
if ! wget -q -O /tmp/kasmvncserver.deb "$DEB_URL"; then
    echo "❌ Failed to download KasmVNC package"
    # Try alternative architecture mappings
    case "$ARCH" in
        amd64) ALT_ARCH="x86_64" ;;
        arm64) ALT_ARCH="aarch64" ;;
        *) ALT_ARCH="$ARCH" ;;
    esac
    
    ALT_URL="${BASE_URL}/kasmvncserver_${RELEASE}_${VERSION}_${ALT_ARCH}.deb"
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
rm -rf /var/lib/apt/lists/*

# Verify installation
if command -v kasmvncserver >/dev/null 2>&1; then
    echo "✅ KasmVNC server installed successfully"
    echo "✅ KasmVNC binary found at: $(which kasmvncserver)"
else
    echo "❌ KasmVNC installation verification failed"
    exit 1
fi

# Pre-configure KasmVNC to avoid interactive prompts
echo "🔧 Pre-configuring KasmVNC settings..."

# Create VNC password file for root user
mkdir -p /root/.kasmvnc
echo 'kasmvnc' | /usr/bin/kasmvncpasswd -f > /root/.kasmvnc/passwd 2>/dev/null || true

# Create default KasmVNC configuration
cat > /root/.kasmvnc/kasmvnc.yaml << 'EOF'
desktop:
  resolution:
    width: 1920
    height: 1080
  allow_resize: true
security:
  authentication:
    require_ssl: false
    username: "user"
    password: "password"
network:
  interface: "0.0.0.0"
  websocket_port: 80
  vnc_port: 5901
logging:
  level: "INFO"
  log_writer_file: "/var/log/kasmvnc.log"
EOF

# Create VNC configuration directories
mkdir -p /etc/kasmvnc /root/.vnc "${DEV_HOME}/.vnc"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.vnc" 2>/dev/null || true

echo "✅ KasmVNC installation completed successfully"

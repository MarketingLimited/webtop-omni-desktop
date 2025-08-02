#!/bin/bash
set -euo pipefail

echo "🔧 Installing KasmVNC server..."

# The KasmVNC .deb package will install its own dependencies.
# Pre-installing them manually can cause conflicts.
# wget is already installed in the base image.
apt-get update

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
    echo "✅ KasmVNC binary found at: $(which kasmvncserver)"
else
    echo "❌ KasmVNC installation verification failed"
    exit 1
fi

# Pre-configure KasmVNC to avoid interactive prompts
echo "🔧 Pre-configuring KasmVNC settings..."

# Create VNC password file for root user
mkdir -p /root/.kasmvnc
echo "#!/bin/bash" > /root/.kasmvnc/kasmvncpasswd
echo "echo 'kasmvnc' | /usr/bin/kasmvncpasswd -f > /root/.kasmvnc/passwd 2>/dev/null || true" >> /root/.kasmvnc/kasmvncpasswd
chmod +x /root/.kasmvnc/kasmvncpasswd
/root/.kasmvnc/kasmvncpasswd

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
mkdir -p /etc/kasmvnc /root/.vnc /home/devuser/.vnc
chown -R devuser:devuser /home/devuser/.vnc 2>/dev/null || true

echo "✅ KasmVNC installation completed successfully"

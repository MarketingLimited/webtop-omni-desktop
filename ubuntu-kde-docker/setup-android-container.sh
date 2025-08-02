#!/bin/bash
set -euo pipefail

readonly DEV_USERNAME="${DEV_USERNAME:-devuser}"
readonly DEV_HOME="/home/${DEV_USERNAME}"

echo "🤖 Setting up container-compatible Android solutions..."

# Prepare required directories with proper ownership
install -d -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" \
    /data/android \
    "$DEV_HOME/.android" \
    "$DEV_HOME/.local/bin" \
    "$DEV_HOME/Desktop/Android Tools"

# Install Android x86 emulator (QEMU-based)
echo "📦 Installing Android x86 emulator..."

# Download Android x86 ISO (lightweight version)
readonly ANDROID_ISO_URL="https://osdn.net/projects/android-x86/downloads/71931/android-x86_64-9.0-r2.iso"
readonly ANDROID_ISO="/data/android/android-x86.iso"

if [ ! -f "$ANDROID_ISO" ]; then
    echo "⬇️ Downloading Android x86 ISO..."
    wget -qO "$ANDROID_ISO" "$ANDROID_ISO_URL" || {
        echo "⚠️ Download failed, creating placeholder"
        touch "$ANDROID_ISO"
    }
fi

EMULATOR_SCRIPT="${DEV_HOME}/.local/bin/android-emulator"
install -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" /dev/null "$EMULATOR_SCRIPT"
cat <<'EOF' > "$EMULATOR_SCRIPT"
#!/bin/bash
set -e

ANDROID_DATA="/data/android"
ANDROID_DISK="$ANDROID_DATA/android-data.qcow2"
ANDROID_ISO="/data/android/android-x86.iso"

# Create Android data disk if it doesn't exist
if [ ! -f "$ANDROID_DISK" ]; then
    echo "🔧 Creating Android data disk..."
    qemu-img create -f qcow2 "$ANDROID_DISK" 8G
fi

# Check if KVM is available
KVM_OPTS=""
if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_OPTS="-enable-kvm -cpu host"
    echo "✅ KVM acceleration enabled"
else
    echo "⚠️ KVM not available, using software emulation"
fi

echo "🚀 Starting Android x86 emulator..."
qemu-system-x86_64 \
    $KVM_OPTS \
    -m 2048 \
    -smp 2 \
    -hda "$ANDROID_DISK" \
    -cdrom "$ANDROID_ISO" \
    -boot d \
    -netdev user,id=net0,hostfwd=tcp::5555-:5555 \
    -device e1000,netdev=net0 \
    -vga virtio \
    -display gtk \
    -audio-drv pulse \
    &

QEMU_PID=$!
echo "Android emulator started with PID: $QEMU_PID"
echo "ADB connection: adb connect localhost:5555"
EOF

# Create web-based Android alternative
WEB_SCRIPT="${DEV_HOME}/.local/bin/android-web"
install -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" /dev/null "$WEB_SCRIPT"
cat <<'EOF' > "$WEB_SCRIPT"
#!/bin/bash
echo "🌐 Opening web-based Android emulator..."
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "https://appetize.io/demo" >/dev/null 2>&1 &
else
    firefox "https://appetize.io/demo" &
fi
echo "Alternative: https://www.genymotion.com/device-online/"
EOF

# Create ADB setup script
ADB_SCRIPT="${DEV_HOME}/.local/bin/setup-adb"
install -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" /dev/null "$ADB_SCRIPT"
cat <<'EOF' > "$ADB_SCRIPT"
#!/bin/bash
set -e
echo "🔧 Setting up ADB..."

if ! command -v adb >/dev/null 2>&1; then
    echo "❌ ADB is not installed"
    exit 1
fi

# Start ADB server
adb start-server

# Check for connected devices
echo "📱 Checking for Android devices..."
adb devices

# Connect to local emulator if running
if command -v ss >/dev/null 2>&1; then
    LISTEN_CMD="ss -tuln"
else
    LISTEN_CMD="netstat -tuln"
fi
if $LISTEN_CMD | grep -q :5555; then
    echo "🔌 Connecting to local Android emulator..."
    adb connect localhost:5555
fi

echo "✅ ADB setup complete"
EOF

# Create Android desktop shortcuts
ANDROID_TOOLS_DIR="${DEV_HOME}/Desktop/Android Tools"

install -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" /dev/null "$ANDROID_TOOLS_DIR/Android Emulator.desktop"
cat <<EOF > "$ANDROID_TOOLS_DIR/Android Emulator.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Emulator
Comment=Android x86 QEMU emulator
Exec=${DEV_HOME}/.local/bin/android-emulator
Icon=phone
Categories=Development;
Terminal=true
EOF

install -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" /dev/null "$ANDROID_TOOLS_DIR/Web Android.desktop"
cat <<EOF > "$ANDROID_TOOLS_DIR/Web Android.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Web Android
Comment=Web-based Android emulator
Exec=${DEV_HOME}/.local/bin/android-web
Icon=web-browser
Categories=Development;
Terminal=false
EOF

install -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" /dev/null "$ANDROID_TOOLS_DIR/ADB Setup.desktop"
cat <<EOF > "$ANDROID_TOOLS_DIR/ADB Setup.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=ADB Setup
Comment=Android Debug Bridge setup
Exec=${DEV_HOME}/.local/bin/setup-adb
Icon=utilities-terminal
Categories=Development;
Terminal=true
EOF

# Create Android diagnostics
DIAG_SCRIPT="${DEV_HOME}/.local/bin/android-diagnostics"
install -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" /dev/null "$DIAG_SCRIPT"
cat <<'EOF' > "$DIAG_SCRIPT"
#!/bin/bash
echo "=== Android Container Diagnostics ==="
echo ""
echo "=== QEMU Availability ==="
command -v qemu-system-x86_64 >/dev/null && echo "✅ QEMU installed" || echo "❌ QEMU not found"
echo ""
echo "=== KVM Support ==="
if [ -c /dev/kvm ]; then
    echo "✅ KVM device available"
    ls -la /dev/kvm
else
    echo "❌ KVM device not available"
fi
echo ""
echo "=== ADB Status ==="
adb version 2>/dev/null || echo "❌ ADB not available"
echo ""
echo "=== Android Emulator Processes ==="
pgrep -f qemu-system || echo "No Android emulator running"
echo ""
echo "=== Network Ports ==="
if command -v ss >/dev/null 2>&1; then
    ss -tuln | grep -E ":(5555|5037)" || echo "No Android ports listening"
else
    netstat -tuln | grep -E ":(5555|5037)" || echo "No Android ports listening"
fi
EOF

echo "✅ Container Android setup complete"
echo "📱 Available Android solutions:"
echo "   1. Android x86 emulator: android-emulator"
echo "   2. Web-based Android: android-web"
echo "   3. ADB tools: setup-adb"

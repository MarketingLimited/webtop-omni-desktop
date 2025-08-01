#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🤖 Setting up container-compatible Android solutions..."

# Create Android data directory
mkdir -p /data/android
mkdir -p "${DEV_HOME}/.android"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.android"

# Install Android x86 emulator (QEMU-based)
echo "📦 Installing Android x86 emulator..."

# Download Android x86 ISO (lightweight version)
ANDROID_ISO_URL="https://osdn.net/projects/android-x86/downloads/71931/android-x86_64-9.0-r2.iso"
ANDROID_ISO="/data/android/android-x86.iso"

if [ ! -f "$ANDROID_ISO" ]; then
    echo "⬇️ Downloading Android x86 ISO..."
    wget -qO "$ANDROID_ISO" "$ANDROID_ISO_URL" || {
        echo "⚠️ Download failed, creating placeholder"
        touch "$ANDROID_ISO"
    }
fi

# Create Android emulator script
cat > "${DEV_HOME}/.local/bin/android-emulator" << 'EOF'
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

chmod +x "${DEV_HOME}/.local/bin/android-emulator"

# Create web-based Android alternative
cat > "${DEV_HOME}/.local/bin/android-web" << 'EOF'
#!/bin/bash
echo "🌐 Opening web-based Android emulator..."
firefox "https://appetize.io/demo" &
echo "Alternative: https://www.genymotion.com/device-online/"
EOF

chmod +x "${DEV_HOME}/.local/bin/android-web"

# Create ADB setup script
cat > "${DEV_HOME}/.local/bin/setup-adb" << 'EOF'
#!/bin/bash
echo "🔧 Setting up ADB..."

# Start ADB server
adb start-server

# Check for connected devices
echo "📱 Checking for Android devices..."
adb devices

# Connect to local emulator if running
if netstat -tuln | grep -q :5555; then
    echo "🔌 Connecting to local Android emulator..."
    adb connect localhost:5555
fi

echo "✅ ADB setup complete"
EOF

chmod +x "${DEV_HOME}/.local/bin/setup-adb"

# Create Android desktop shortcuts
mkdir -p "${DEV_HOME}/Desktop/Android Tools"

cat > "${DEV_HOME}/Desktop/Android Tools/Android Emulator.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Emulator
Comment=Android x86 QEMU emulator
Exec=/home/devuser/.local/bin/android-emulator
Icon=phone
Categories=Development;
Terminal=true
EOF

cat > "${DEV_HOME}/Desktop/Android Tools/Web Android.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Web Android
Comment=Web-based Android emulator
Exec=/home/devuser/.local/bin/android-web
Icon=web-browser
Categories=Development;
Terminal=false
EOF

cat > "${DEV_HOME}/Desktop/Android Tools/ADB Setup.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=ADB Setup
Comment=Android Debug Bridge setup
Exec=/home/devuser/.local/bin/setup-adb
Icon=utilities-terminal
Categories=Development;
Terminal=true
EOF

chmod +x "${DEV_HOME}/Desktop/Android Tools/"*.desktop

# Create Android diagnostics
cat > "${DEV_HOME}/.local/bin/android-diagnostics" << 'EOF'
#!/bin/bash
echo "=== Android Container Diagnostics ==="
echo ""
echo "=== QEMU Availability ==="
which qemu-system-x86_64 >/dev/null && echo "✅ QEMU installed" || echo "❌ QEMU not found"
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
netstat -tuln | grep -E ":(5555|5037)" || echo "No Android ports listening"
EOF

chmod +x "${DEV_HOME}/.local/bin/android-diagnostics"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" /data/android

echo "✅ Container Android setup complete"
echo "📱 Available Android solutions:"
echo "   1. Android x86 emulator: android-emulator"
echo "   2. Web-based Android: android-web"
echo "   3. ADB tools: setup-adb"
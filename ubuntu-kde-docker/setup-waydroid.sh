#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

# Logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WAYDROID] $*"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WAYDROID WARN] $*" >&2
}

log_info "Setting up Waydroid for Android apps..."

# Check if Waydroid is available
if ! command -v waydroid >/dev/null 2>&1; then
    log_warn "Waydroid not installed - skipping Android support setup"
    exit 0
fi

# Check for required kernel modules (optional in containers)
missing_modules=0
for module in binder_linux ashmem_linux; do
    if ! lsmod | grep -q "^$module"; then
        log_warn "Kernel module $module not loaded (expected in containers)"
        missing_modules=$((missing_modules + 1))
    fi
done

if [ $missing_modules -eq 2 ]; then
    log_warn "Required kernel modules not available - Waydroid may not function properly"
    log_info "Creating placeholder shortcuts for Android support"
else
    log_info "Initializing Waydroid..."
    waydroid init 2>/dev/null || log_warn "Waydroid initialization failed (container limitation)"
fi

# Create desktop shortcuts
mkdir -p "${DEV_HOME}/.local/share/applications"

cat > "${DEV_HOME}/.local/share/applications/waydroid.desktop" << 'EOF'
[Desktop Entry]
Name=Waydroid
Comment=Android container for marketing apps
Exec=waydroid show-full-ui
Icon=android
Terminal=false
Type=Application
Categories=System;Emulator;
EOF

# Create Android Apps folder on desktop
mkdir -p "${DEV_HOME}/Desktop/Android Apps"
cp "${DEV_HOME}/.local/share/applications/waydroid"*.desktop "${DEV_HOME}/Desktop/Android Apps/"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Waydroid setup complete (may require kernel modules for full functionality)"
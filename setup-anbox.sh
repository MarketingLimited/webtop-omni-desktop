#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
# Resolve the UID for the runtime directory
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANBOX] $*"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANBOX WARN] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANBOX ERROR] $*" >&2
}

log_info "Installing Anbox as Android fallback solution..."

# Install Anbox dependencies
apt-get update
apt-get install -y \
    snapd \
    squashfuse \
    fuse \
    android-tools-adb \
    android-tools-fastboot


# Install Anbox via snap (if snap is available)
if command -v snap >/dev/null 2>&1; then
    log_info "Installing Anbox via snap..."
    if ! snap install --devmode anbox 2>/dev/null; then
        log_warn "Snap installation failed, trying alternative..."
    fi
else
    log_warn "snapd not available, skipping snap install."
fi

# Alternative: Install Anbox from PPA
if ! command -v anbox >/dev/null 2>&1; then
    log_info "Installing Anbox from PPA..."
    # Add Anbox PPA
    if ! add-apt-repository -y ppa:morphis/anbox-support 2>/dev/null; then
        log_warn "Failed to add Anbox PPA."
    fi
    apt-get update
    # Install Anbox
    if ! apt-get install -y anbox-modules-dkms anbox; then
        log_warn "PPA installation failed. Anbox may not be available."
    fi
fi

# Create Anbox configuration directory
mkdir -p "${DEV_HOME}/.config/anbox"

# Configure Anbox for container environment
cat > "${DEV_HOME}/.config/anbox/config" <<EOF
[core]
use_system_dbus=false
data_path=${DEV_HOME}/.local/share/anbox
socket_path=/run/user/${DEV_UID}/anbox_bridge

[graphics]
egl_driver=swiftshader
enable_hardware_acceleration=false

[network]
use_host_networking=true
EOF

# Create Anbox startup script
mkdir -p "${DEV_HOME}/.local/bin"
cat > "${DEV_HOME}/.local/bin/anbox-start" <<EOF
#!/bin/bash
export ANBOX_LOG_LEVEL=info
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

# Start Anbox session manager
anbox session-manager &
sleep 2

# Launch Anbox UI
anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity
EOF
chmod +x "${DEV_HOME}/.local/bin/anbox-start"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"


if command -v anbox >/dev/null 2>&1; then
    log_info "✅ Anbox installation complete. You can launch Anbox from the Applications menu or with anbox-start."
else
    log_warn "⚠️  Anbox installation may have failed. Please check logs and ensure your system supports Anbox."
    log_warn "See https://anbox.io/ for troubleshooting."
fi

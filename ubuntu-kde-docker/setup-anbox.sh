#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
DEV_UID="$(id -u "${DEV_USERNAME}")"

# Logging functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANBOX] $*"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANBOX WARN] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANBOX ERROR] $*" >&2
}

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

log_info "Installing Anbox as Android fallback solution..."

# Install Anbox dependencies
apt-get update
apt-get install -y --no-install-recommends \
    snapd \
    squashfuse \
    fuse \
    software-properties-common \
    android-tools-adb \
    android-tools-fastboot

# Install Anbox via snap (if snap is available)
if command -v snap >/dev/null 2>&1; then
    log_info "Installing Anbox via snap..."
    if ! snap install --devmode anbox; then
        log_warn "Snap installation failed, trying PPA..."
    fi
fi

# Alternative: Install Anbox from PPA
if ! command -v anbox >/dev/null 2>&1; then
    log_info "Installing Anbox from PPA..."

    if add-apt-repository -y ppa:morphis/anbox-support; then
        apt-get update
        apt-get install -y --no-install-recommends anbox-modules-dkms anbox || \
            log_warn "PPA installation failed"
    else
        log_warn "Failed to add Anbox PPA"
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
    log_info "Anbox installation complete"
    exit 0
else
    log_error "Anbox installation failed"
    exit 1
fi
#!/bin/bash
set -e

# Enhanced logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1"
}

echo "🚀 Starting Ubuntu KDE Marketing Agency WebTop (Emergency Fix)..."

# Use defaults for environment variables
DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_PASSWORD="${DEV_PASSWORD:-devuser123}"
DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"
ADMIN_USERNAME="${ADMIN_USERNAME:-adminuser}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
ADMIN_UID="${ADMIN_UID:-1001}"
ADMIN_GID="${ADMIN_GID:-1001}"

log_info "Creating missing system users..."

# Create groups if they don't exist
groupadd -g $DEV_GID $DEV_USERNAME 2>/dev/null || true
groupadd -g $ADMIN_GID $ADMIN_USERNAME 2>/dev/null || true

# Create development user
if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -u $DEV_UID -g $DEV_GID $DEV_USERNAME
    echo "$DEV_USERNAME:$DEV_PASSWORD" | chpasswd
    usermod -aG sudo,audio,video,pulse-access $DEV_USERNAME
    log_info "Created development user: $DEV_USERNAME"
fi

# Create admin user
if ! id "$ADMIN_USERNAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -u $ADMIN_UID -g $ADMIN_GID $ADMIN_USERNAME
    echo "$ADMIN_USERNAME:$ADMIN_PASSWORD" | chpasswd
    usermod -aG sudo,audio,video,pulse-access $ADMIN_USERNAME
    log_info "Created admin user: $ADMIN_USERNAME"
fi

# Create XDG runtime directory
mkdir -p /run/user/$DEV_UID
chown $DEV_UID:$DEV_GID /run/user/$DEV_UID
chmod 700 /run/user/$DEV_UID

# Create VNC directory for devuser
mkdir -p /home/$DEV_USERNAME/.vnc
chown $DEV_UID:$DEV_GID /home/$DEV_USERNAME/.vnc

# Fix /tmp/.X11-unix permissions
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
chown root:root /tmp/.X11-unix

# Initialize D-Bus system bus
log_info "🔧 Initializing D-Bus system bus..."
if [ ! -d /run/dbus ]; then
    mkdir -p /run/dbus
fi

if [ ! -f /run/dbus/system_bus_socket ]; then
    dbus-daemon --system --fork || {
        log_error "Failed to start D-Bus system daemon"
        exit 1
    }
    log_info "✅ D-Bus system bus started successfully"
else
    log_info "✅ D-Bus system bus already running"
fi

# Setup SSH host keys
log_info "Setting up SSH host keys..."
mkdir -p /var/run/sshd
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
fi
if [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''
fi
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
fi

# Configure sshd
cat > /etc/ssh/sshd_config.d/container.conf << EOF
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes
X11Forwarding yes
X11UseLocalhost no
EOF

# Skip PolicyKit setup (container limitation)
log_warn "Skipping PolicyKit setup (container environment)"

# Skip Android subsystem setup (container limitation)
log_info "Setting up Android subsystem support (optional)..."
log_warn "Could not load binder_linux module (container limitation)"
log_warn "Could not load ashmem_linux module (container limitation)"
log_warn "Could not mount binderfs (container limitation)"

# Create log directory for supervisor
mkdir -p /var/log/supervisor
chmod 755 /var/log/supervisor

# Fix home directory permissions
chown -R $DEV_UID:$DEV_GID /home/$DEV_USERNAME 2>/dev/null || true
chown -R $ADMIN_UID:$ADMIN_GID /home/$ADMIN_USERNAME 2>/dev/null || true

log_info "Starting supervisor daemon..."

# Export environment variables for supervisor
export DEV_USERNAME DEV_UID DEV_GID ADMIN_USERNAME ADMIN_UID ADMIN_GID
export TTYD_USER="${TTYD_USER:-terminal}"
export TTYD_PASSWORD="${TTYD_PASSWORD:-terminal}"

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n
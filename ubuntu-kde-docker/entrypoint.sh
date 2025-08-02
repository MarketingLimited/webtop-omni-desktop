#!/bin/bash
set -euo pipefail

echo "🚀 Starting Ubuntu KDE Marketing Agency WebTop..."

# Default credentials and IDs can be overridden via environment variables
: "${DEV_USERNAME:=devuser}"
: "${DEV_PASSWORD:=DevPassw0rd!}"
: "${DEV_UID:=1000}"
: "${DEV_GID:=1000}"
: "${ADMIN_USERNAME:=adminuser}"
: "${ADMIN_PASSWORD:=AdminPassw0rd!}"
: "${ROOT_PASSWORD:=ComplexP@ssw0rd!}"
: "${TTYD_USER:=terminal}"
: "${TTYD_PASSWORD:=TerminalPassw0rd!}"
: "${ENABLE_GOOGLE_ADS_EDITOR:=false}"

# Export variables so they are available to child processes like supervisord
export DEV_USERNAME DEV_PASSWORD DEV_UID DEV_GID \
       ADMIN_USERNAME ADMIN_PASSWORD ROOT_PASSWORD \
       TTYD_USER TTYD_PASSWORD ENABLE_GOOGLE_ADS_EDITOR

# Logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >&2
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" >&2
}

# Initialize system directories
mkdir -p /var/run/dbus "/run/user/${DEV_UID}" /tmp/.ICE-unix /tmp/.X11-unix
# /tmp/.X11-unix may be mounted read-only by the host. Avoid failing if chmod
# cannot modify permissions.
chmod 1777 /tmp/.ICE-unix /tmp/.X11-unix 2>/dev/null || \
  echo "⚠️  Warning: unable to set permissions on /tmp/.X11-unix"

# Replace default username in polkit rule if different
if [ -f /etc/polkit-1/rules.d/99-devuser-all.rules ]; then
    sed -i "s/\"devuser\"/\"${DEV_USERNAME}\"/" /etc/polkit-1/rules.d/99-devuser-all.rules
fi

# Update root password if provided
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
else
    # Generate a random password for root if not provided
    RANDOM_PASSWORD=$(openssl rand -base64 12)
    echo "root:${RANDOM_PASSWORD}" | chpasswd
    echo "Root password set to: ${RANDOM_PASSWORD}"
fi

# Create missing system users that D-Bus might reference
log_info "Creating missing system users..."
getent group whoopsie >/dev/null || groupadd -r whoopsie
getent passwd whoopsie >/dev/null || useradd -r -g whoopsie -s /sbin/nologin -d /nonexistent whoopsie

# Ensure polkitd system user and group exist
getent group polkitd >/dev/null || groupadd -r polkitd
getent passwd polkitd >/dev/null || useradd -r -g polkitd -s /sbin/nologin polkitd

# Create basic polkit directories and configuration
mkdir -p /var/lib/polkit-1/localauthority /etc/polkit-1/localauthority.conf.d /etc/dbus-1/system.d

# Create messagebus user for D-Bus if it doesn't exist
getent group messagebus >/dev/null || groupadd -r messagebus
getent passwd messagebus >/dev/null || useradd -r -g messagebus -s /sbin/nologin messagebus

# Apply required capabilities and permissions for PolicyKit
if command -v setcap >/dev/null 2>&1; then
    setcap cap_setgid=pe /usr/lib/polkit-1/polkitd || true
fi
chmod 4755 /usr/lib/policykit-1/polkit-agent-helper-1 2>/dev/null || true

# Create missing PolicyKit config files for Ubuntu 24.04 bug fix
mkdir -p /etc/polkit-1/localauthority.conf.d /etc/polkit-1/rules.d /var/lib/polkit-1/localauthority
cp -f /tmp/polkit-localauthority.conf /etc/polkit-1/localauthority.conf.d/51-ubuntu-admin.conf 2>/dev/null || true
cp -f /tmp/polkit-dbus.conf /etc/dbus-1/system.d/org.freedesktop.PolicyKit1.conf 2>/dev/null || true

# Fix PolicyKit permissions
chown polkitd:polkitd /var/lib/polkit-1/localauthority 2>/dev/null || true
chmod 755 /var/lib/polkit-1/localauthority 2>/dev/null || true

# Ensure group and user exist
if ! getent group "$DEV_USERNAME" > /dev/null; then
    if getent group "$DEV_GID" > /dev/null; then
        # Fallback to auto-assigned GID when the desired one already exists
        groupadd "$DEV_USERNAME"
    else
        groupadd -g "$DEV_GID" "$DEV_USERNAME"
    fi
fi

# Ensure the ssl-cert group exists for adding the dev user
if ! getent group ssl-cert > /dev/null; then
    groupadd ssl-cert
fi

if ! id -u "$DEV_USERNAME" > /dev/null 2>&1; then
    if getent passwd "$DEV_UID" > /dev/null; then
        # Fallback to auto-assigned UID when the desired one already exists
        useradd -m -s /bin/bash -g "$DEV_GID" "$DEV_USERNAME"
    else
        useradd -m -s /bin/bash -u "$DEV_UID" -g "$DEV_GID" "$DEV_USERNAME"
    fi
fi

echo "${DEV_USERNAME}:${DEV_PASSWORD}" | chpasswd
if ! getent group pulse-access >/dev/null; then
    groupadd -r pulse-access
fi
usermod -aG sudo,ssl-cert,pulse-access,video "$DEV_USERNAME"

# Admin user
if ! id -u "$ADMIN_USERNAME" > /dev/null 2>&1; then
    useradd -m -s /bin/bash "$ADMIN_USERNAME"
fi

echo "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" | chpasswd
usermod -aG sudo "$ADMIN_USERNAME"

sed -i 's/^%sudo.*/%sudo ALL=(ALL) NOPASSWD:ALL/' /etc/sudoers

# Prepare VNC startup script for dev user
mkdir -p "/home/${DEV_USERNAME}/.vnc"
install -m 755 /tmp/xstartup "/home/${DEV_USERNAME}/.vnc/xstartup"
chown -R "${DEV_USERNAME}":"${DEV_USERNAME}" "/home/${DEV_USERNAME}/.vnc"

# XDG runtime directory
mkdir -p "/run/user/${DEV_UID}"
chown "${DEV_USERNAME}":"${DEV_USERNAME}" "/run/user/${DEV_UID}"
chmod 700 "/run/user/${DEV_UID}"
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

# Register user with AccountsService

# D-Bus will be managed by supervisor, just ensure directory exists
echo "🔧 Preparing D-Bus directories..."
mkdir -p /run/dbus
echo "✅ D-Bus directories prepared"

# Set up audio system before other services
log_info "Setting up audio system..."
if [ -f "/usr/local/bin/setup-audio.sh" ]; then
    /usr/local/bin/setup-audio.sh
    echo "✅ Audio system setup completed"
    
    # Apply runtime audio fixes after user creation
    if [ -f "/usr/local/bin/fix-audio-startup.sh" ]; then
        /usr/local/bin/fix-audio-startup.sh
        echo "✅ Audio startup configuration completed"
    fi
    
    # Schedule audio validation after services start
    if [ -f "/usr/local/bin/audio-validation.sh" ]; then
        chmod +x /usr/local/bin/audio-validation.sh
        echo "✅ Audio validation scheduled"
    fi
else
    echo "⚠️  Audio setup script not found"
fi

# Set up TTYD terminal service
log_info "Setting up TTYD terminal service..."
if [ -f "/usr/local/bin/setup-ttyd.sh" ]; then
    /usr/local/bin/setup-ttyd.sh
    echo "✅ TTYD setup completed"
else
    echo "⚠️  TTYD setup script not found"
fi

# Set up desktop audio integration testing
log_info "Setting up desktop audio integration..."
if [ -f "/usr/local/bin/test-desktop-audio.sh" ]; then
    chmod +x /usr/local/bin/test-desktop-audio.sh
    echo "✅ Desktop audio integration testing setup completed"
else
    echo "⚠️  Desktop audio integration script not found"
fi

# Generate SSH host keys if they don't exist
log_info "Setting up SSH host keys..."
mkdir -p /etc/ssh /run/sshd
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -t rsa -b 3072 -f /etc/ssh/ssh_host_rsa_key -N '' -q
fi
if [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N '' -q
fi
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q
fi

# Set proper permissions for SSH host keys
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
chown root:root /etc/ssh/ssh_host_*

# Configure SSH
cat > /etc/ssh/sshd_config << 'EOF'
Port 22
Protocol 2
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
Subsystem sftp /usr/lib/openssh/sftp-server
AcceptEnv LANG LC_*
UsePAM yes
X11Forwarding yes
PrintMotd no
TCPKeepAlive yes
UsePrivilegeSeparation sandbox
PidFile /run/sshd.pid
EOF

# Launch the main process (e.g., supervisord) passed as arguments
exec "$@"

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

# Configure audio service defaults. Leave AUDIO_HOST unset so browsers
# fall back to the current window hostname, ensuring remote clients can
# connect even when the container runs behind NAT or port forwarding.
: "${AUDIO_PORT:=8080}"
: "${AUDIO_HOST:=}"
: "${AUDIO_WS_SCHEME:=}"
export AUDIO_HOST AUDIO_PORT AUDIO_WS_SCHEME

# Update runtime .env if present
ENV_FILE="/config/.env"
if [ -f "$ENV_FILE" ]; then
    sed -i "s/^AUDIO_HOST=.*/AUDIO_HOST=${AUDIO_HOST}/" "$ENV_FILE"
    sed -i "s/^AUDIO_PORT=.*/AUDIO_PORT=${AUDIO_PORT}/" "$ENV_FILE"
    sed -i "s/^AUDIO_WS_SCHEME=.*/AUDIO_WS_SCHEME=${AUDIO_WS_SCHEME}/" "$ENV_FILE"
elif [ -f "/.env" ]; then
    ENV_FILE="/.env"
    sed -i "s/^AUDIO_HOST=.*/AUDIO_HOST=${AUDIO_HOST}/" "$ENV_FILE"
    sed -i "s/^AUDIO_PORT=.*/AUDIO_PORT=${AUDIO_PORT}/" "$ENV_FILE"
    sed -i "s/^AUDIO_WS_SCHEME=.*/AUDIO_WS_SCHEME=${AUDIO_WS_SCHEME}/" "$ENV_FILE"
fi

# Write audio configuration for browser clients with validation
echo "🔧 Configuring audio environment for browsers..."

# Ensure directory exists
mkdir -p /usr/share/novnc

# Write audio configuration with proper escaping and validation
cat > /usr/share/novnc/audio-env.js <<EOF
// Audio environment configuration
// Generated at $(date)
console.log('Loading audio environment configuration...');

window.AUDIO_HOST = '${AUDIO_HOST}';
window.AUDIO_PORT = ${AUDIO_PORT};
window.AUDIO_WS_SCHEME = '${AUDIO_WS_SCHEME}';

// Debug information
console.log('Audio configuration:', {
    host: window.AUDIO_HOST,
    port: window.AUDIO_PORT,
    scheme: window.AUDIO_WS_SCHEME
});

// Validate configuration
if (!window.AUDIO_PORT || window.AUDIO_PORT < 1 || window.AUDIO_PORT > 65535) {
    console.warn('Invalid audio port configuration:', window.AUDIO_PORT);
}
EOF

# Verify the file was created correctly
if [ -f /usr/share/novnc/audio-env.js ]; then
    echo "✅ Audio environment configuration created successfully"
    echo "Configuration preview:"
    head -5 /usr/share/novnc/audio-env.js
else
    echo "❌ Failed to create audio environment configuration"
fi

# Provide package metadata expected by noVNC's UI
if [ ! -f /usr/share/novnc/package.json ]; then
    cat > /usr/share/novnc/package.json <<'EOF'
{
  "name": "novnc",
  "version": "1.0.0"
}
EOF
fi

# Initialize system directories
mkdir -p /var/run/dbus /tmp/.ICE-unix /tmp/.X11-unix
# Ensure world-writable permissions for X11 and ICE sockets
# /tmp/.X11-unix may be mounted read-only by the host
chmod 1777 /tmp/.ICE-unix 2>/dev/null || log_warn "/tmp/.ICE-unix permissions could not be set"
chmod 1777 /tmp/.X11-unix 2>/dev/null || log_warn "/tmp/.X11-unix is not writable; skipping chmod"

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

# Ensure runtime variables match the actual user IDs
DEV_UID="$(id -u "$DEV_USERNAME")"
DEV_GID="$(id -g "$DEV_USERNAME")"

# Admin user
if ! id -u "$ADMIN_USERNAME" > /dev/null 2>&1; then
    useradd -m -s /bin/bash "$ADMIN_USERNAME"
fi

echo "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" | chpasswd
usermod -aG sudo "$ADMIN_USERNAME"

sed -i 's/^%sudo.*/%sudo ALL=(ALL) NOPASSWD:ALL/' /etc/sudoers

# Prepare VNC startup script for dev user
mkdir -p "/home/${DEV_USERNAME}/.vnc"
cat <<'XEOF' > "/home/${DEV_USERNAME}/.vnc/xstartup"
#!/bin/sh
export XKL_XMODMAP_DISABLE=1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec dbus-launch --exit-with-session /usr/bin/startplasma-x11
XEOF
chown -R "${DEV_USERNAME}":"${DEV_USERNAME}" "/home/${DEV_USERNAME}/.vnc"
chmod +x "/home/${DEV_USERNAME}/.vnc/xstartup"

# XDG runtime directory
mkdir -p "/run/user/${DEV_UID}"
chown "${DEV_USERNAME}":"${DEV_USERNAME}" "/run/user/${DEV_UID}"
chmod 700 "/run/user/${DEV_UID}"
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

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
    
    # Schedule audio validation and routing fix after services start
    if [ -f "/usr/local/bin/audio-validation.sh" ]; then
        chmod +x /usr/local/bin/audio-validation.sh
        echo "✅ Audio validation scheduled"
    fi
    
    # Make audio debug and routing scripts executable
    chmod +x /usr/local/bin/debug-audio-pipeline.sh 2>/dev/null || true
    chmod +x /usr/local/bin/fix-audio-routing.sh 2>/dev/null || true
    
    # Schedule audio routing fix after a brief delay to allow services to start
    echo "🎯 Scheduling audio routing fix..."
    (sleep 10 && /usr/local/bin/fix-audio-routing.sh >/dev/null 2>&1) &
else
    echo "⚠️  Audio setup script not found"
fi

# Run post-setup diagnostics as the development user
if [ -x /usr/local/bin/diagnostic-and-fix.sh ]; then
    echo "🩺 Running audio diagnostic and fix as ${DEV_USERNAME}..."
    su - "${DEV_USERNAME}" -c "/usr/local/bin/diagnostic-and-fix.sh" || log_warn "diagnostic-and-fix.sh failed"
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

# Wine setup is handled later in the script.

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




# Fix permissions so KDE apps can write files
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}"
chown -R "${ADMIN_USERNAME}:${ADMIN_USERNAME}" "/home/${ADMIN_USERNAME}"

# Setup Wine (runtime only)
log_info "Setting up Wine..."
if [ -f "/usr/local/bin/setup-wine.sh" ]; then
    if /usr/local/bin/setup-wine.sh; then
        log_info "Wine setup completed successfully"
    else
        log_warn "Wine setup failed"
    fi
else
    log_warn "Wine setup script not found"
fi

# Setup Android subsystem (Waydroid/Anbox)
log_info "Setting up Android subsystem..."
if [ -f "/usr/local/bin/setup-waydroid.sh" ]; then
    if /usr/local/bin/setup-waydroid.sh; then
        log_info "Android subsystem setup completed"
    else
        log_warn "Android subsystem setup failed"
    fi
else
    log_warn "Android subsystem setup script not found"
fi

# Ensure binder/ashmem are available for Waydroid (optional, may fail in containers)
log_info "Setting up Android kernel support (optional)..."
if command -v modprobe >/dev/null 2>&1; then
    modprobe binder_linux 2>/dev/null || log_warn "Could not load binder_linux module (container limitation)"
    modprobe ashmem_linux 2>/dev/null || log_warn "Could not load ashmem_linux module (container limitation)"
fi
mkdir -p /dev/binderfs
if ! mountpoint -q /dev/binderfs; then
    mount -t binder binder /dev/binderfs 2>/dev/null || log_warn "Could not mount binderfs (container limitation)"
fi
if ! lsmod | grep -q binder_linux || ! lsmod | grep -q ashmem_linux; then
    log_warn "Android kernel modules missing; load binder_linux and ashmem_linux on the host for Waydroid support"
fi

# Setup service monitoring and recovery
log_info "Setting up service monitoring..."
mkdir -p /var/log/supervisor /var/run/supervisor

# The monitor-services.sh is copied via the Dockerfile and is managed by supervisord.
# The custom script generation below is removed, and the separate monitor is disabled.
chmod +x /usr/local/bin/monitor-services.sh
# /usr/local/bin/monitor-services.sh &

# Set up service health monitoring
log_info "Setting up service health monitoring..."
if [ -f "/usr/local/bin/service-health.sh" ]; then
    chmod +x /usr/local/bin/service-health.sh
    echo "✅ Service health monitoring setup completed"
else
    echo "⚠️  Service health monitoring script not found"
fi

log_info "Starting supervisor daemon..."

exec env \
    ENV_DEV_USERNAME="${DEV_USERNAME}" \
    ENV_DEV_UID="${DEV_UID}" \
    ENV_DEV_GID="${DEV_GID}" \
    ENV_TTYD_USER="${TTYD_USER}" \
    ENV_TTYD_PASSWORD="${TTYD_PASSWORD}" \
    DEV_USERNAME="${DEV_USERNAME}" DEV_UID="${DEV_UID}" DEV_GID="${DEV_GID}" \
    TTYD_USER="${TTYD_USER}" TTYD_PASSWORD="${TTYD_PASSWORD}" \
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n

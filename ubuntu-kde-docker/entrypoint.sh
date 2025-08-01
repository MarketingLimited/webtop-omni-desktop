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

# Set up Wine for Windows applications
log_info "Setting up Wine for Windows applications..."
if [ -f "/usr/local/bin/setup-wine.sh" ]; then
    if /usr/local/bin/setup-wine.sh; then
        log_info "Wine setup completed"

        # Set up Google Ads Editor after Wine is ready with error handling
        if [ -f "/usr/local/bin/setup-google-ads-editor.sh" ]; then
            if /usr/local/bin/setup-google-ads-editor.sh; then
                log_info "Google Ads Editor setup completed"
            else
                log_warn "Google Ads Editor setup failed (continuing)"
            fi
        else
            log_warn "Google Ads Editor setup script not found"
        fi
    else
        log_warn "Wine setup failed (continuing)"
    fi
else
    log_warn "Wine setup script not found"
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

if command -v dbus-send >/dev/null 2>&1; then
    dbus-send --system --dest=org.freedesktop.Accounts --type=method_call \
      /org/freedesktop/Accounts org.freedesktop.Accounts.CacheUser string:"${DEV_USERNAME}" || true
else
    echo "dbus-send not found; skipping AccountsService registration"
fi
if [ -f "/var/lib/AccountsService/users/${DEV_USERNAME}" ]; then
    if ! grep -q '^SystemAccount=false' "/var/lib/AccountsService/users/${DEV_USERNAME}"; then
        echo 'SystemAccount=false' >> "/var/lib/AccountsService/users/${DEV_USERNAME}"
    fi
fi

# Launch accounts-daemon manually when systemd services are unavailable
if command -v systemctl >/dev/null 2>&1 && [ "$(ps -p 1 -o comm=)" = systemd ]; then
    systemctl restart accounts-daemon || true
else
    if pgrep -x accounts-daemon >/dev/null 2>&1; then
        killall accounts-daemon || true
    fi
    started=false
    for path in \
        /usr/lib/accountsservice/accounts-daemon \
        /usr/sbin/accounts-daemon \
        /usr/libexec/accounts-daemon \
        $(command -v accounts-daemon 2>/dev/null); do
        if [ -x "$path" ]; then
            echo "Starting accounts-daemon at $path"
            "$path" &
            started=true
            break
        fi
    done
    if [ "$started" = false ]; then
        echo "accounts-daemon not available; skipping"
    fi
fi


# Fix permissions so KDE apps can write files
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}"
chown -R "${ADMIN_USERNAME}:${ADMIN_USERNAME}" "/home/${ADMIN_USERNAME}"

# Setup container-optimized D-Bus first
log_info "Setting up container D-Bus..."
if [ -f "/usr/local/bin/setup-container-dbus.sh" ]; then
    /usr/local/bin/setup-container-dbus.sh || log_warn "D-Bus setup failed"
fi

# Ensure D-Bus services are running so applications can connect
if [ -f "/usr/local/bin/start-dbus" ]; then
    /usr/local/bin/start-dbus || log_warn "Failed to start D-Bus services"
fi

# Setup font configuration early
log_info "Setting up font configuration..."
if [ -f "/usr/local/bin/setup-font-config.sh" ]; then
    /usr/local/bin/setup-font-config.sh || log_warn "Font config setup failed"
fi

# Guarantee fontconfig exists to avoid KDE errors
if [ ! -f "/home/${DEV_USERNAME}/.config/fontconfig/fonts.conf" ]; then
    mkdir -p "/home/${DEV_USERNAME}/.config/fontconfig"
    cat > "/home/${DEV_USERNAME}/.config/fontconfig/fonts.conf" <<'EOF'
<?xml version="1.0"?>
<fontconfig></fontconfig>
EOF
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config/fontconfig/fonts.conf"
fi

# Setup container-optimized Wine
log_info "Setting up container Wine..."
if [ -f "/usr/local/bin/setup-wine-container.sh" ]; then
    /usr/local/bin/setup-wine-container.sh || log_warn "Wine container setup failed"
else
    # Fallback to original Wine setup
    log_info "Setting up Wine and Google Ads Editor..."
    if [ -f "/usr/local/bin/setup-wine.sh" ]; then
        if /usr/local/bin/setup-wine.sh; then
            log_info "Wine setup completed successfully"

            # Setup Google Ads Editor
            if [ -f "/usr/local/bin/setup-google-ads-editor.sh" ]; then
                if /usr/local/bin/setup-google-ads-editor.sh; then
                    log_info "Google Ads Editor setup completed successfully"
                else
                    log_warn "Google Ads Editor setup failed"
                fi
            else
                log_warn "Google Ads Editor setup script not found"
            fi
        else
            log_warn "Wine setup failed"
        fi
    else
        log_warn "Wine setup script not found"
    fi
fi
# Setup container Android solutions
log_info "Setting up container Android..."
if [ -f "/usr/local/bin/setup-android-container.sh" ]; then
    /usr/local/bin/setup-android-container.sh || log_warn "Android container setup failed"
else
    # Fallback to original Android setup
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

# Setup service monitoring and recovery
log_info "Setting up service monitoring..."
mkdir -p /var/log/supervisor /var/run/supervisor

# Create a simple service monitor script
cat > /usr/local/bin/monitor-services.sh << 'EOF'
#!/bin/bash
while true; do
    # Check critical services every 30 seconds
    sleep 30
    
    # Check if D-Bus is running
    if ! pgrep -x dbus-daemon >/dev/null; then
        echo "$(date) [MONITOR] D-Bus not running, attempting restart" >> /var/log/supervisor/monitor.log
        dbus-daemon --system --fork 2>/dev/null || true
    fi
    
    # Log service status
    echo "$(date) [MONITOR] Services check completed" >> /var/log/supervisor/monitor.log
done &
EOF

# The monitor-services.sh is now copied from external file, just make it executable
chmod +x /usr/local/bin/monitor-services.sh

# Start the enhanced monitor
/usr/local/bin/monitor-services.sh &

# Setup enhanced monitoring
log_info "Setting up enhanced monitoring..."
if [ -f "/usr/local/bin/setup-enhanced-monitoring.sh" ]; then
    /usr/local/bin/setup-enhanced-monitoring.sh || log_warn "Enhanced monitoring setup failed"
fi

# Set up service health monitoring
log_info "Setting up service health monitoring..."
if [ -f "/usr/local/bin/service-health.sh" ]; then
    chmod +x /usr/local/bin/service-health.sh
    /usr/local/bin/service-health.sh wait &
    log_info "✅ Service health monitoring setup completed"
else
    log_warn "⚠️  Service health monitoring script not found"
fi

# Setup Xvfb optimization
log_info "Setting up Xvfb display server optimization..."
if [ -f "/usr/local/bin/setup-xvfb-optimization.sh" ]; then
    chmod +x /usr/local/bin/setup-xvfb-optimization.sh
    /usr/local/bin/setup-xvfb-optimization.sh
    log_info "✅ Xvfb optimization setup completed"
else
    log_warn "⚠️  Xvfb optimization script not found"
fi

# Setup KasmVNC
log_info "Setting up KasmVNC..."
if [ -f "/usr/local/bin/setup-kasmvnc.sh" ]; then
    chmod +x /usr/local/bin/setup-kasmvnc.sh
    /usr/local/bin/setup-kasmvnc.sh
    log_info "✅ KasmVNC setup completed"
else
    log_warn "⚠️  KasmVNC setup script not found"
fi

# Setup KDE optimization
log_info "Setting up KDE Plasma desktop optimization..."
if [ -f "/usr/local/bin/setup-kde-optimization.sh" ]; then
    chmod +x /usr/local/bin/setup-kde-optimization.sh
    /usr/local/bin/setup-kde-optimization.sh
    log_info "✅ KDE optimization setup completed"
else
    log_warn "⚠️  KDE optimization script not found"
fi

# Setup system-level optimization
log_info "Setting up system-level performance optimization..."
if [ -f "/usr/local/bin/setup-system-optimization.sh" ]; then
    chmod +x /usr/local/bin/setup-system-optimization.sh
    /usr/local/bin/setup-system-optimization.sh
    log_info "✅ System optimization setup completed"
else
    log_warn "⚠️  System optimization script not found"
fi

# Setup network and streaming optimization
log_info "Setting up network and streaming optimization..."
if [ -f "/usr/local/bin/setup-network-optimization.sh" ]; then
    chmod +x /usr/local/bin/setup-network-optimization.sh
    /usr/local/bin/setup-network-optimization.sh
    log_info "✅ Network optimization setup completed"
else
    log_warn "⚠️  Network optimization script not found"
fi

# Setup advanced features (Phase 7)
log_info "Setting up advanced desktop features..."
if [ -f "/usr/local/bin/setup-advanced-features.sh" ]; then
    chmod +x /usr/local/bin/setup-advanced-features.sh
    /usr/local/bin/setup-advanced-features.sh 2>&1 | tee -a "/var/log/setup-advanced-features.log"
    log_info "✅ Advanced features setup completed"
else
    log_warn "⚠️  Advanced features script not found"
fi

# Setup marketing optimization (Phase 8)
log_info "Setting up marketing agency optimizations..."
if [ -f "/usr/local/bin/setup-marketing-optimization.sh" ]; then
    chmod +x /usr/local/bin/setup-marketing-optimization.sh
    /usr/local/bin/setup-marketing-optimization.sh 2>&1 | tee -a "/var/log/setup-marketing-optimization.log"
    log_info "✅ Marketing optimization setup completed"
else
    log_warn "⚠️  Marketing optimization script not found"
fi

# Setup modern features
log_info "Setting up modern desktop features..."
if [ -f "/usr/local/bin/setup-modern-features.sh" ]; then
    chmod +x /usr/local/bin/setup-modern-features.sh
    /usr/local/bin/setup-modern-features.sh 2>&1 | tee -a "/var/log/setup-modern-features.log"
    log_info "✅ Modern features setup completed"
else
    log_warn "⚠️  Modern features script not found"
fi


log_info "Starting supervisor daemon..."

# Default performance and service configuration
: "${XVFB_PERFORMANCE_PROFILE:=balanced}"
: "${XVFB_RESOLUTION:=1920x1080x24}"
: "${XVFB_DPI:=96}"
: "${KDE_PERFORMANCE_PROFILE:=performance}"
: "${KDE_EFFECTS_DISABLED:=true}"
: "${KASMVNC_PORT:=80}"
: "${KASMVNC_VNC_PORT:=5901}"
: "${WEBRTC_PORT:=8443}"

# Log selected profiles for troubleshooting
log_info "Xvfb profile: ${XVFB_PERFORMANCE_PROFILE}, resolution: ${XVFB_RESOLUTION}, dpi: ${XVFB_DPI}"
log_info "KDE profile: ${KDE_PERFORMANCE_PROFILE}, effects disabled: ${KDE_EFFECTS_DISABLED}"
log_info "KasmVNC port: ${KASMVNC_PORT}, VNC port: ${KASMVNC_VNC_PORT}"
log_info "WebRTC signaling port: ${WEBRTC_PORT}"

exec env \
    ENV_DEV_USERNAME="${DEV_USERNAME}" \
    ENV_DEV_UID="${DEV_UID}" \
    ENV_DEV_GID="${DEV_GID}" \
    ENV_TTYD_USER="${TTYD_USER}" \
    ENV_TTYD_PASSWORD="${TTYD_PASSWORD}" \
    XVFB_PERFORMANCE_PROFILE="${XVFB_PERFORMANCE_PROFILE}" \
    XVFB_RESOLUTION="${XVFB_RESOLUTION}" \
    XVFB_DPI="${XVFB_DPI}" \
    KDE_PERFORMANCE_PROFILE="${KDE_PERFORMANCE_PROFILE}" \
    KDE_EFFECTS_DISABLED="${KDE_EFFECTS_DISABLED}" \
    KASMVNC_PORT="${KASMVNC_PORT}" \
    KASMVNC_VNC_PORT="${KASMVNC_VNC_PORT}" \
    WEBRTC_PORT="${WEBRTC_PORT}" \
    ENV_XVFB_PERFORMANCE_PROFILE="${XVFB_PERFORMANCE_PROFILE}" \
    ENV_XVFB_RESOLUTION="${XVFB_RESOLUTION}" \
    ENV_XVFB_DPI="${XVFB_DPI}" \
    ENV_KDE_PERFORMANCE_PROFILE="${KDE_PERFORMANCE_PROFILE}" \
    ENV_KDE_EFFECTS_DISABLED="${KDE_EFFECTS_DISABLED}" \
    ENV_KASMVNC_PORT="${KASMVNC_PORT}" \
    ENV_KASMVNC_VNC_PORT="${KASMVNC_VNC_PORT}" \
    ENV_WEBRTC_PORT="${WEBRTC_PORT}" \
    DEV_USERNAME="${DEV_USERNAME}" DEV_UID="${DEV_UID}" DEV_GID="${DEV_GID}" \
    TTYD_USER="${TTYD_USER}" TTYD_PASSWORD="${TTYD_PASSWORD}" \
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n

#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
DEV_UID="$(id -u "${DEV_USERNAME}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure required directories
mkdir -p "${DEV_HOME}/.local/bin" \
         "${DEV_HOME}/.local/share/applications" \
         "${DEV_HOME}/Desktop/Android Apps"

# Logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANDROID] $*"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANDROID WARN] $*" >&2
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ANDROID ERROR] $*" >&2
}

log_info "Setting up Android subsystem (Waydroid/Anbox)..."

# Function to setup Anbox using existing script
setup_anbox() {
    log_info "Setting up Anbox as Android fallback..."
    if bash "${SCRIPT_DIR}/setup-anbox.sh" >/dev/null 2>&1; then
        cat > "${DEV_HOME}/.local/share/applications/anbox.desktop" <<'EOT'
[Desktop Entry]
Name=Anbox (Android Apps)
Comment=Android container for running Android apps
Exec=anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity
Icon=android
Terminal=false
Type=Application
Categories=System;Emulator;
EOT
        log_info "Anbox setup completed"
        return 0
    else
        log_warn "Anbox not available"
        return 1
    fi
}

# Function to setup container-compatible Waydroid
setup_waydroid_container() {
    log_info "Setting up container-compatible Waydroid..."

    mkdir -p "${DEV_HOME}/.local/share/waydroid"

    cat > "${DEV_HOME}/.local/share/waydroid/waydroid.cfg" <<EOT
[properties]
waydroid.host_data_path=${DEV_HOME}/.local/share/waydroid/data
waydroid.rootfs_path=${DEV_HOME}/.local/share/waydroid/rootfs
waydroid.overlay_rw=true
waydroid.mount_overlays=true

[waydroid]
arch=x86_64
images_path=${DEV_HOME}/.local/share/waydroid/images
vendor_type=MAINLINE
system_type=VANILLA
xdg_runtime_dir=/run/user/${DEV_UID}
wayland_display=wayland-0
pulse_server=unix:/run/user/${DEV_UID}/pulse/native

[session]
user_manager=true
multi_windows=true
emu_gl=false
emu_virgl=false
EOT

    export WAYDROID_LOG=true
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    export WAYLAND_DISPLAY="wayland-0"

    if su - "${DEV_USERNAME}" -c "waydroid init -s GAPPS -f" 2>/dev/null; then
        log_info "Waydroid initialized successfully"
        return 0
    elif su - "${DEV_USERNAME}" -c "waydroid init" 2>/dev/null; then
        log_info "Waydroid basic initialization completed"
        return 0
    else
        log_warn "Waydroid initialization failed"
        return 1
    fi
}

ANDROID_SOLUTION="none"

# Check kernel modules (informational)
for mod in binder_linux ashmem_linux; do
    if ! lsmod | grep -q "^$mod" 2>/dev/null; then
        log_warn "Kernel module $mod not loaded"
    fi
done

# Determine available Android solution
if command -v waydroid >/dev/null 2>&1; then
    log_info "Waydroid found, attempting container setup..."
    if setup_waydroid_container; then
        ANDROID_SOLUTION="waydroid"
        log_info "Waydroid setup successful"
    else
        log_warn "Waydroid setup failed, trying Anbox fallback..."
        if setup_anbox; then
            ANDROID_SOLUTION="anbox"
            log_info "Anbox fallback setup successful"
        else
            log_error "Both Waydroid and Anbox setup failed"
        fi
    fi
else
    log_info "Waydroid not available, trying Anbox..."
    if setup_anbox; then
        ANDROID_SOLUTION="anbox"
        log_info "Anbox setup successful"
    else
        log_warn "No Android solution available"
    fi
fi

# Create desktop shortcuts based on available solution
if [ "$ANDROID_SOLUTION" = "waydroid" ]; then
    cat > "${DEV_HOME}/.local/share/applications/waydroid.desktop" <<'EOT'
[Desktop Entry]
Name=Waydroid (Android Apps)
Comment=Android container for running Android apps
Exec=waydroid show-full-ui
Icon=android
Terminal=false
Type=Application
Categories=System;Emulator;
EOT

    cat > "${DEV_HOME}/.local/bin/android-launcher" <<EOT
#!/bin/bash
# Android App Launcher for Waydroid
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
export WAYLAND_DISPLAY="wayland-0"

if pgrep -f "waydroid" > /dev/null; then
    waydroid show-full-ui
else
    waydroid session start &
    sleep 3
    waydroid show-full-ui
fi
EOT
    chmod +x "${DEV_HOME}/.local/bin/android-launcher"

    cp "${DEV_HOME}/.local/share/applications/waydroid.desktop" "${DEV_HOME}/Desktop/Android Apps/"
elif [ "$ANDROID_SOLUTION" = "anbox" ]; then
    cp "${DEV_HOME}/.local/share/applications/anbox.desktop" "${DEV_HOME}/Desktop/Android Apps/"
else
    cat > "${DEV_HOME}/Desktop/Android Apps/android-unavailable.txt" <<'EOT'
Android Support Unavailable

Neither Waydroid nor Anbox could be configured properly.
This may be due to container limitations or missing system components.

To enable Android support:
1. Ensure kernel modules binder_linux and ashmem_linux are available
2. Install Waydroid or Anbox packages
3. Run the setup script again
EOT
fi

cat > "${DEV_HOME}/.local/bin/android-debug" <<EOT
#!/bin/bash
echo "=== Android Debug Information ==="
echo "Solution: ${ANDROID_SOLUTION}"
echo "Waydroid Status:"
waydroid status 2>/dev/null || echo "Waydroid not running"
echo ""
echo "Kernel Modules:"
lsmod | grep -E "(binder|ashmem)" || echo "No Android kernel modules loaded"
echo ""
echo "Processes:"
pgrep -f "waydroid\|anbox" || echo "No Android processes running"
EOT
chmod +x "${DEV_HOME}/.local/bin/android-debug"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

# Final status
case "$ANDROID_SOLUTION" in
    "waydroid")
        echo "✅ Waydroid setup complete (container-optimized)"
        ;;
    "anbox")
        echo "✅ Anbox setup complete (fallback solution)"
        ;;
    "none")
        echo "⚠️  No Android solution available"
        ;;
esac

#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
# Determine the UID of the development user for runtime directory paths
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

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

# Anbox fallback has been removed to simplify the setup process
# and because it is unlikely to work in this containerized environment.

# Function to setup container-compatible Waydroid
setup_waydroid_container() {
    log_info "Setting up container-compatible Waydroid..."
    
    # Create Waydroid data directory
    mkdir -p "${DEV_HOME}/.local/share/waydroid"
    
    # Configure Waydroid for container environment
    cat > "${DEV_HOME}/.local/share/waydroid/waydroid.cfg" << 'EOF'
[properties]
waydroid.host_data_path=/home/devuser/.local/share/waydroid/data
waydroid.rootfs_path=/home/devuser/.local/share/waydroid/rootfs
waydroid.overlay_rw=true
waydroid.mount_overlays=true

[waydroid]
arch=x86_64
images_path=/home/devuser/.local/share/waydroid/images
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
EOF

    # Try to initialize Waydroid with container-specific settings
    export WAYDROID_LOG=true
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    export WAYLAND_DISPLAY="wayland-0"
    
    # Initialize without hardware requirements
    if su - "${DEV_USERNAME}" -c "waydroid init -s GAPPS -f" 2>/dev/null; then
        log_info "Waydroid initialized successfully"
        return 0
    else
        log_warn "Waydroid initialization failed, trying basic init..."
        if su - "${DEV_USERNAME}" -c "waydroid init" 2>/dev/null; then
            log_info "Waydroid basic initialization completed"
            return 0
        else
            log_warn "Waydroid initialization failed completely"
            return 1
        fi
    fi
}

# Main Android setup logic
log_info "Checking for Android subsystem requirements..."

# Waydroid requires binder_linux and ashmem_linux kernel modules on the host.
if ! lsmod | grep -q "binder_linux" || ! lsmod | grep -q "ashmem_linux"; then
    log_error "Android subsystem setup failed: Missing required kernel modules."
    log_warn "The host system is missing 'binder_linux' and/or 'ashmem_linux' kernel modules."
    log_warn "These modules must be loaded on the Docker host to enable Android support."
    log_warn "Waydroid installation will be skipped."

    # Create a placeholder explaining the issue
    mkdir -p "${DEV_HOME}/Desktop/Android Apps"
    cat > "${DEV_HOME}/Desktop/Android Apps/android-unavailable.txt" << 'EOF'
Android Support Unavailable

The host system does not have the required kernel modules ('binder_linux', 'ashmem_linux') loaded.
These are necessary for Waydroid to function.

To enable Android support, please ensure these modules are loaded on your Docker host system.
EOF
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/Desktop"

    # Exit cleanly as this is a configuration issue, not a script error.
    exit 0
fi

log_info "All Android requirements met. Proceeding with Waydroid setup..."

# Check if Waydroid is available
if command -v waydroid >/dev/null 2>&1; then
    log_info "Waydroid found, attempting container setup..."
    
    if setup_waydroid_container; then
        log_info "Waydroid setup successful"
        # Create desktop shortcuts
        mkdir -p "${DEV_HOME}/.local/share/applications"
        mkdir -p "${DEV_HOME}/Desktop/Android Apps"
        cat > "${DEV_HOME}/.local/share/applications/waydroid.desktop" << 'EOF'
[Desktop Entry]
Name=Waydroid (Android Apps)
Comment=Android container for running Android apps
Exec=waydroid show-full-ui
Icon=android
Terminal=false
Type=Application
Categories=System;Emulator;
EOF
        cp "${DEV_HOME}/.local/share/applications/waydroid.desktop" "${DEV_HOME}/Desktop/Android Apps/"
        chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"
        echo "✅ Waydroid setup complete (container-optimized)"
    else
        log_error "Waydroid setup failed even with kernel modules present."
        log_warn "There might be an issue with the Waydroid installation or configuration."
    fi
else
    log_warn "Waydroid command not found, skipping Android setup."
fi

# Create Android debugging tools
mkdir -p "${DEV_HOME}/.local/bin"
cat > "${DEV_HOME}/.local/bin/android-debug" << 'EOF'
#!/bin/bash
echo "=== Android Debug Information ==="
echo "Solution: waydroid"
echo "Waydroid Status:"
waydroid status 2>/dev/null || echo "Waydroid not running"
echo ""
echo "Kernel Modules:"
lsmod | grep -E "(binder|ashmem)" || echo "No Android kernel modules loaded"
echo ""
echo "Processes:"
pgrep -f "waydroid\|anbox" || echo "No Android processes running"
EOF
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
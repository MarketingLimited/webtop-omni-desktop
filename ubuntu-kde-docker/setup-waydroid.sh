#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

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

# Function to setup Anbox as fallback
setup_anbox() {
    log_info "Setting up Anbox as Android fallback..."
    
    # Install Anbox if available
    if command -v anbox >/dev/null 2>&1; then
        log_info "Anbox found, configuring..."
        
        # Create Anbox data directory
        mkdir -p "${DEV_HOME}/.local/share/anbox"
        
        # Create Anbox desktop shortcut
        cat > "${DEV_HOME}/.local/share/applications/anbox.desktop" << 'EOF'
[Desktop Entry]
Name=Anbox (Android Apps)
Comment=Android container for running Android apps
Exec=anbox launch --package=org.anbox.appmgr --component=org.anbox.appmgr.AppViewActivity
Icon=android
Terminal=false
Type=Application
Categories=System;Emulator;
EOF
        
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
xdg_runtime_dir=/run/user/1000
wayland_display=wayland-0
pulse_server=unix:/run/user/1000/pulse/native

[session]
user_manager=true
multi_windows=true
emu_gl=false
emu_virgl=false
EOF

    # Try to initialize Waydroid with container-specific settings
    export WAYDROID_LOG=true
    export XDG_RUNTIME_DIR="/run/user/1000"
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
ANDROID_SOLUTION=""

# Verify required kernel modules are available
missing_mods=0
for mod in binder_linux ashmem_linux; do
    if ! lsmod | grep -q "^$mod" 2>/dev/null; then
        log_warn "Kernel module $mod not loaded"
        missing_mods=1
    fi
done

if [ "$missing_mods" -eq 1 ]; then
    log_warn "Android kernel support unavailable; skipping Android setup"
    ANDROID_SOLUTION="none"
else

# Check if Waydroid is available
if command -v waydroid >/dev/null 2>&1; then
    log_info "Waydroid found, attempting container setup..."
    
    # Check for kernel modules (informational only)
    missing_modules=0
    for module in binder_linux ashmem_linux; do
        if ! lsmod | grep -q "^$module" 2>/dev/null; then
            log_info "Kernel module $module not loaded (using software fallback)"
            missing_modules=$((missing_modules + 1))
        fi
    done
    
    # Try Waydroid setup regardless of kernel modules
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
            ANDROID_SOLUTION="none"
        fi
    fi
else
    log_info "Waydroid not available, trying Anbox..."
    if setup_anbox; then
        ANDROID_SOLUTION="anbox"
        log_info "Anbox setup successful"
    else
        log_warn "No Android solution available"
        ANDROID_SOLUTION="none"
    fi
fi
fi

# Create desktop shortcuts based on available solution
mkdir -p "${DEV_HOME}/.local/share/applications"
mkdir -p "${DEV_HOME}/Desktop/Android Apps"

if [ "$ANDROID_SOLUTION" = "waydroid" ]; then
    # Create Waydroid desktop shortcut
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
    
    # Create Android launcher script
    cat > "${DEV_HOME}/.local/bin/android-launcher" << 'EOF'
#!/bin/bash
# Android App Launcher for Waydroid
export XDG_RUNTIME_DIR="/run/user/1000"
export WAYLAND_DISPLAY="wayland-0"

if pgrep -f "waydroid" > /dev/null; then
    waydroid show-full-ui
else
    waydroid session start &
    sleep 3
    waydroid show-full-ui
fi
EOF
    chmod +x "${DEV_HOME}/.local/bin/android-launcher"
    
    cp "${DEV_HOME}/.local/share/applications/waydroid.desktop" "${DEV_HOME}/Desktop/Android Apps/"
    
elif [ "$ANDROID_SOLUTION" = "anbox" ]; then
    cp "${DEV_HOME}/.local/share/applications/anbox.desktop" "${DEV_HOME}/Desktop/Android Apps/"
    
else
    # Create placeholder for no Android solution
    cat > "${DEV_HOME}/Desktop/Android Apps/android-unavailable.txt" << 'EOF'
Android Support Unavailable

Neither Waydroid nor Anbox could be configured properly.
This may be due to container limitations or missing system components.

To enable Android support:
1. Ensure kernel modules binder_linux and ashmem_linux are available
2. Install Waydroid or Anbox packages
3. Run the setup script again
EOF
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
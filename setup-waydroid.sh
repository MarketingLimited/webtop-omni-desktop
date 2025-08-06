#!/bin/bash
set -euo pipefail

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1"
}

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
# Determine the UID of the development user for runtime directory paths
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# --- Phase 3: Improved Android subsystem detection and fallback ---
log_info "Checking for Android subsystem requirements..."

missing_modules=()
for mod in binder_linux ashmem_linux; do
    if ! lsmod | grep -q "$mod"; then
        missing_modules+=("$mod")
    fi
done

if [ ${#missing_modules[@]} -gt 0 ]; then
    log_warn "================================================================================"
    log_warn "ANDROID SUPPORT DISABLED: Host kernel modules missing: ${missing_modules[*]}"
    log_warn "================================================================================"
    log_warn "The container host is missing the following required modules: ${missing_modules[*]}"
    log_warn "These are required by Waydroid to provide Android app support."
    log_warn ""
    log_warn "HOW-TO FIX:"
    log_warn "1. On your DOCKER HOST machine (not inside the container), run:"
    for mod in "${missing_modules[@]}"; do
        log_warn "   sudo modprobe $mod"
    done
    log_warn "2. To make this permanent, add the modules to /etc/modules."
    log_warn "3. Restart the Docker container."
    log_warn "================================================================================"
    log_warn "Waydroid installation will be skipped."

    # Create a placeholder explaining the issue
    mkdir -p "${DEV_HOME}/Desktop/Android Apps"
    cat > "${DEV_HOME}/Desktop/Android Apps/android-unavailable.txt" << EOF
Android Support Unavailable

The host system does not have the required kernel modules (${missing_modules[*]}) loaded.
These are necessary for Waydroid to function.

To enable Android support, please ensure these modules are loaded on your Docker host system.
EOF
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/Desktop"

    # Attempt Anbox fallback if available
    if [ -x "$(dirname "$0")/setup-anbox.sh" ]; then
        log_info "Attempting Anbox fallback..."
        if "$(dirname "$0")/setup-anbox.sh"; then
            ANDROID_SOLUTION="anbox"
        else
            log_warn "Anbox fallback failed"
        fi
    else
        log_warn "No Anbox fallback script found."
    fi

else
    log_info "All Android requirements met. Proceeding with Waydroid setup..."
    ANDROID_SOLUTION="waydroid"
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
        ANDROID_SOLUTION="none"
    fi
fi

# Print summary for user clarity
log_info "Android subsystem setup summary:"
case "${ANDROID_SOLUTION:-none}" in
    "waydroid")
        log_info "Waydroid is set up and ready."
        ;;
    "anbox")
        log_info "Anbox fallback is active. Some features may be limited."
        ;;
    "none")
        log_warn "No Android solution available. See instructions above."
        ;;
esac

# Create Android debugging tools
mkdir -p "${DEV_HOME}/.local/bin"
cat > "${DEV_HOME}/.local/bin/android-debug" <<EOF
#!/bin/bash
echo "=== Android Debug Information ==="
echo "Solution: ${ANDROID_SOLUTION:-none}"
if command -v waydroid >/dev/null 2>&1; then
    echo "Waydroid Status:"
    waydroid status 2>/dev/null || echo "Waydroid not running"
else
    echo "Waydroid not installed"
fi
echo ""
echo "Kernel Modules:"
lsmod | grep -E "(binder|ashmem)" || echo "No Android kernel modules loaded"
echo ""
echo "Processes:"
pgrep -f "waydroid|anbox" || echo "No Android processes running"
EOF
chmod +x "${DEV_HOME}/.local/bin/android-debug"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

# Final status
case "${ANDROID_SOLUTION:-none}" in
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
if [ "${ANDROID_SOLUTION:-none}" = "none" ]; then
    exit 1
else
    exit 0
fi
#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
APPLICATIONS_DIR="${DEV_HOME}/.local/share/applications"
DESKTOP_DIR="${DEV_HOME}/Desktop"
VIDEO_DIR="${DEV_HOME}/Videos"

# Logging functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [VIDEO] $*"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [VIDEO ERROR] $*" >&2
}

log_info "Setting up professional video editing environment..."

# Check if video editing tools are available
missing_tools=()
for tool in kdenlive obs; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -ne 0 ]; then
    log_error "Missing video editing tools: ${missing_tools[*]}"
    log_info "Creating placeholder shortcuts anyway"
fi

# Create directories
mkdir -p "$APPLICATIONS_DIR" "$DESKTOP_DIR"
project_dirs=(
    "$VIDEO_DIR/Projects"
    "$VIDEO_DIR/Assets"
    "$VIDEO_DIR/Templates"
    "$VIDEO_DIR/Exports"
    "$VIDEO_DIR/Projects/Marketing-Videos"
    "$VIDEO_DIR/Projects/Social-Media"
    "$VIDEO_DIR/Projects/Product-Demos"
    "$VIDEO_DIR/Projects/Tutorials"
)
for dir in "${project_dirs[@]}"; do
    mkdir -p "$dir"
done

# Kdenlive configuration
log_info "Configuring Kdenlive..."
mkdir -p "${DEV_HOME}/.config"
cat > "${DEV_HOME}/.config/kdenliverc" << EOF
[unmanaged]
defaultprojectfolder=${VIDEO_DIR}/Projects

[timeline]
trackheight=50

[env]
defaultprojectformat=atsc_1080p_30

[misc]
profile_fps_filter=30
EOF

# Create desktop shortcuts
cat > "$APPLICATIONS_DIR/kdenlive.desktop" << 'EOF'
[Desktop Entry]
Name=Kdenlive
Comment=Professional video editor
Exec=kdenlive
Icon=kdenlive
Terminal=false
Type=Application
Categories=AudioVideo;AudioVideoEditing;
EOF

cat > "$APPLICATIONS_DIR/obs-studio.desktop" << 'EOF'
[Desktop Entry]
Name=OBS Studio
Comment=Video recording and streaming
Exec=obs
Icon=com.obsproject.Studio
Terminal=false
Type=Application
Categories=AudioVideo;Recorder;
EOF

# Copy shortcuts to desktop
cp "$APPLICATIONS_DIR/kdenlive.desktop" "$DESKTOP_DIR/"
cp "$APPLICATIONS_DIR/obs-studio.desktop" "$DESKTOP_DIR/"
chmod +x "$DESKTOP_DIR/"*.desktop

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" \
    "$VIDEO_DIR" "$DESKTOP_DIR" "$APPLICATIONS_DIR" "${DEV_HOME}/.config/kdenliverc"

log_info "Video editing environment setup complete"

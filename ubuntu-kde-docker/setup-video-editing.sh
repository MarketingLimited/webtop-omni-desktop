#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🎬 Setting up professional video editing environment..."

# Create video project directories
mkdir -p \
    "${DEV_HOME}/Videos/Projects" \
    "${DEV_HOME}/Videos/Assets" \
    "${DEV_HOME}/Videos/Templates" \
    "${DEV_HOME}/Videos/Exports" \
    "${DEV_HOME}/Videos/Projects/Marketing-Videos" \
    "${DEV_HOME}/Videos/Projects/Social-Media" \
    "${DEV_HOME}/Videos/Projects/Product-Demos" \
    "${DEV_HOME}/Videos/Projects/Tutorials"

# Kdenlive configuration
echo "⚙️ Configuring Kdenlive..."
mkdir -p "${DEV_HOME}/.config"
cat > "${DEV_HOME}/.config/kdenliverc" << 'EOF'
[unmanaged]
defaultprojectfolder=/home/devuser/Videos/Projects

[timeline]
trackheight=50

[env]
defaultprojectformat=atsc_1080p_30

[misc]
profile_fps_filter=30
EOF

# Create desktop shortcuts
mkdir -p "${DEV_HOME}/.local/share/applications"

cat > "${DEV_HOME}/.local/share/applications/kdenlive.desktop" << 'EOF'
[Desktop Entry]
Name=Kdenlive
Comment=Professional video editor
Exec=kdenlive
Icon=kdenlive
Terminal=false
Type=Application
Categories=AudioVideo;AudioVideoEditing;
EOF

cat > "${DEV_HOME}/.local/share/applications/obs-studio.desktop" << 'EOF'
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
cp "${DEV_HOME}/.local/share/applications/kdenlive.desktop" "${DEV_HOME}/Desktop/"
cp "${DEV_HOME}/.local/share/applications/obs-studio.desktop" "${DEV_HOME}/Desktop/"
chmod +x "${DEV_HOME}/Desktop/"*.desktop

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Video editing environment setup complete"
#!/bin/bash
set -euxo pipefail

# Setup Professional Video Editing Environment
echo "Setting up professional video editing environment..."

DEV_USERNAME=${DEV_USERNAME:-devuser}
HOME_DIR="/home/${DEV_USERNAME}"

# Create directories for video editing
mkdir -p "${HOME_DIR}/Videos/Projects"
mkdir -p "${HOME_DIR}/Videos/Templates"
mkdir -p "${HOME_DIR}/Videos/Assets"
mkdir -p "${HOME_DIR}/Videos/Exports"
mkdir -p "${HOME_DIR}/.local/share/applications"
mkdir -p "${HOME_DIR}/Desktop"

# Install additional video editing codecs and tools
apt-get update && apt-get install -y \
    # Video codecs and libraries
    libavcodec-extra \
    ubuntu-restricted-extras \
    x264 x265 \
    libx264-dev libx265-dev \
    # Professional audio tools
    jackd2 qjackctl \
    ardour reaper \
    # Advanced video tools
    melt \
    frei0r-plugins \
    # Screen recording tools
    kazam gtk-recordmydesktop \
    # Video conversion tools
    handbrake-cli handbrake-gtk \
    # Streaming tools
    v4l2loopback-dkms \
    || true

# Install DaVinci Resolve dependencies
apt-get install -y \
    libnss3 \
    libxss1 \
    libgconf-2-4 \
    libxtst6 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    || true

# Create video editing project templates
mkdir -p "${HOME_DIR}/Videos/Templates/Social-Media-Templates"
mkdir -p "${HOME_DIR}/Videos/Templates/Marketing-Videos"
mkdir -p "${HOME_DIR}/Videos/Templates/Presentation-Templates"

# Create enhanced Kdenlive configuration
mkdir -p "${HOME_DIR}/.config/kdenliverc"
cat > "${HOME_DIR}/.config/kdenliverc" << 'EOF'
[Media Browser]
defaultfolder=/home/devuser/Videos/Projects

[Project Defaults]
videotracks=3
audiotracks=4
videocodec=libx264
audiocodec=aac

[Render]
defaultprofile=MP4-H264/AAC
renderquality=23

[Timeline]
trackheight=50
autoscroll=true
EOF

# Create OBS Studio profile for marketing
mkdir -p "${HOME_DIR}/.config/obs-studio/basic/profiles/Marketing"
cat > "${HOME_DIR}/.config/obs-studio/basic/profiles/Marketing/basic.ini" << 'EOF'
[Video]
BaseCX=1920
BaseCY=1080
OutputCX=1920
OutputCY=1080
FPSType=0
FPSCommon=30

[Audio]
SampleRate=44100
ChannelSetup=Stereo

[AdvOut]
RecEncoder=obs_x264
RecFilePath=/home/devuser/Videos/Exports
RecFormat=mp4
RecQuality=0
RecRB=false
EOF

# Create video editing shortcuts
cat > "${HOME_DIR}/.local/share/applications/kdenlive-pro.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Kdenlive Pro
Comment=Professional Video Editor
Exec=kdenlive --config ${HOME_DIR}/.config/kdenliverc
Icon=kdenlive
StartupNotify=true
Categories=AudioVideo;AudioVideoEditing;
MimeType=application/x-kdenlive;
EOF

cat > "${HOME_DIR}/.local/share/applications/obs-marketing.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=OBS Studio (Marketing)
Comment=Screen Recording & Streaming for Marketing
Exec=obs --profile Marketing
Icon=obs
StartupNotify=true
Categories=AudioVideo;Recorder;
EOF

cat > "${HOME_DIR}/.local/share/applications/video-projects.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Video Projects
Comment=Open video projects folder
Exec=dolphin ${HOME_DIR}/Videos/Projects
Icon=folder-videos
StartupNotify=true
Categories=System;FileManager;
EOF

# Create video editing tools launcher
cat > "${HOME_DIR}/video-tools.sh" << 'EOF'
#!/bin/bash
# Video Editing Tools Launcher

case "$1" in
    kdenlive)
        kdenlive --config ~/.config/kdenliverc &
        ;;
    obs)
        obs --profile Marketing &
        ;;
    audacity)
        audacity &
        ;;
    blender)
        blender &
        ;;
    gimp)
        gimp &
        ;;
    all)
        echo "Launching all video editing tools..."
        kdenlive --config ~/.config/kdenliverc &
        sleep 2
        obs --profile Marketing &
        sleep 2
        audacity &
        ;;
    templates)
        dolphin ~/Videos/Templates &
        ;;
    projects)
        dolphin ~/Videos/Projects &
        ;;
    *)
        echo "Video Editing Tools Launcher"
        echo "Usage: $0 {kdenlive|obs|audacity|blender|gimp|all|templates|projects}"
        echo ""
        echo "Tools:"
        echo "  kdenlive   - Launch Kdenlive video editor"
        echo "  obs        - Launch OBS Studio for recording"
        echo "  audacity   - Launch Audacity audio editor"
        echo "  blender    - Launch Blender for 3D/animation"
        echo "  gimp       - Launch GIMP for image editing"
        echo "  all        - Launch all main video editing tools"
        echo "  templates  - Open video templates folder"
        echo "  projects   - Open video projects folder"
        ;;
esac
EOF

chmod +x "${HOME_DIR}/video-tools.sh"

# Create video editing desktop shortcuts
mkdir -p "${HOME_DIR}/Desktop/Video Editing"
cp "${HOME_DIR}/.local/share/applications/kdenlive-pro.desktop" "${HOME_DIR}/Desktop/Video Editing/"
cp "${HOME_DIR}/.local/share/applications/obs-marketing.desktop" "${HOME_DIR}/Desktop/Video Editing/"
cp "${HOME_DIR}/.local/share/applications/video-projects.desktop" "${HOME_DIR}/Desktop/Video Editing/"

# Create quick access to video tools
cat > "${HOME_DIR}/Desktop/Video Editing/Video-Tools-Launcher.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Video Tools Launcher
Comment=Quick access to all video editing tools
Exec=konsole -e ${HOME_DIR}/video-tools.sh
Icon=applications-multimedia
StartupNotify=true
Categories=AudioVideo;
EOF

chmod +x "${HOME_DIR}/Desktop/Video Editing"/*.desktop

# Create marketing video templates info
cat > "${HOME_DIR}/Videos/Templates/MARKETING_VIDEO_TEMPLATES.txt" << 'EOF'
MARKETING VIDEO TEMPLATES

This folder contains templates for common marketing video formats:

SOCIAL MEDIA FORMATS:
- Instagram Story (1080x1920)
- Instagram Post (1080x1080)
- Instagram Reel (1080x1920)
- TikTok (1080x1920)
- YouTube Thumbnail (1280x720)
- Facebook Post (1200x630)
- Twitter Video (1200x675)

MARKETING FORMATS:
- Product Demo (1920x1080)
- Explainer Video (1920x1080)
- Testimonial Video (1920x1080)
- Brand Story (1920x1080)
- Tutorial Video (1920x1080)

TO USE TEMPLATES:
1. Copy template to Projects folder
2. Open in Kdenlive
3. Replace placeholder content
4. Export using appropriate social media preset

RECOMMENDED EXPORT SETTINGS:
- Instagram/TikTok: MP4, H.264, 30fps
- YouTube: MP4, H.264, 1080p, 30fps
- Facebook: MP4, H.264, 720p-1080p
- Twitter: MP4, H.264, max 512MB
EOF

# Setup GPU acceleration for video editing (if available)
if lspci | grep -i nvidia > /dev/null; then
    echo "NVIDIA GPU detected - installing NVENC support"
    apt-get install -y nvidia-cuda-toolkit || true
fi

# Set ownership
chown -R ${DEV_USERNAME}:${DEV_USERNAME} "${HOME_DIR}/Videos" "${HOME_DIR}/.config" "${HOME_DIR}/.local" "${HOME_DIR}/Desktop" "${HOME_DIR}/video-tools.sh" 2>/dev/null || true

echo "Professional video editing environment setup completed!"
echo "Access tools via Desktop/Video Editing folder or run video-tools.sh"
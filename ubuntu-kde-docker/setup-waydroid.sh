#!/bin/bash
set -euxo pipefail

# Setup Waydroid for Android Applications
echo "Setting up Waydroid for Android applications..."

DEV_USERNAME=${DEV_USERNAME:-devuser}
HOME_DIR="/home/${DEV_USERNAME}"

# Install Waydroid if not already installed
if ! command -v waydroid >/dev/null 2>&1; then
    # Add Waydroid repository
    curl https://repo.waydro.id | bash
    apt-get update
    apt-get install -y waydroid || true
fi

# Initialize Waydroid system
waydroid init || true

# Create Waydroid management scripts
mkdir -p "${HOME_DIR}/.local/share/applications"
mkdir -p "${HOME_DIR}/Desktop"

# Waydroid manager script
cat > "${HOME_DIR}/waydroid-manager.sh" << 'EOF'
#!/bin/bash
# Waydroid Management Script for Marketing Agency

case "$1" in
    start)
        echo "Starting Waydroid session..."
        waydroid session start &
        sleep 5
        waydroid show-full-ui &
        ;;
    stop)
        echo "Stopping Waydroid session..."
        waydroid session stop
        ;;
    install)
        if [ -z "$2" ]; then
            echo "Usage: $0 install <app.apk>"
            exit 1
        fi
        echo "Installing Android app: $2"
        waydroid app install "$2"
        ;;
    shell)
        echo "Opening Waydroid shell..."
        waydroid shell
        ;;
    status)
        waydroid status
        ;;
    apps)
        echo "Installed Android apps:"
        waydroid app list
        ;;
    setup-marketing)
        echo "Setting up marketing apps..."
        # Install F-Droid for open source apps
        wget -O /tmp/fdroid.apk https://f-droid.org/F-Droid.apk
        waydroid app install /tmp/fdroid.apk
        
        # Note: Users need to manually install apps from Google Play
        echo "Waydroid is ready! You can now:"
        echo "1. Open Google Play Store in Waydroid"
        echo "2. Install marketing apps like Instagram, TikTok, etc."
        echo "3. Use apps for content creation and social media management"
        ;;
    *)
        echo "Waydroid Manager for Marketing Agency"
        echo "Usage: $0 {start|stop|install|shell|status|apps|setup-marketing}"
        echo ""
        echo "Commands:"
        echo "  start          - Start Waydroid and show Android UI"
        echo "  stop           - Stop Waydroid session"
        echo "  install <apk>  - Install an Android app from APK file"
        echo "  shell          - Open Waydroid shell"
        echo "  status         - Show Waydroid status"
        echo "  apps           - List installed Android apps"
        echo "  setup-marketing- Setup marketing-focused Android environment"
        ;;
esac
EOF

chmod +x "${HOME_DIR}/waydroid-manager.sh"

# Create desktop shortcuts for Waydroid
cat > "${HOME_DIR}/.local/share/applications/waydroid.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android (Waydroid)
Comment=Run Android applications
Exec=${HOME_DIR}/waydroid-manager.sh start
Icon=android
StartupNotify=true
Categories=System;Emulator;
EOF

cat > "${HOME_DIR}/.local/share/applications/waydroid-manager.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid Manager
Comment=Manage Android environment
Exec=konsole -e ${HOME_DIR}/waydroid-manager.sh
Icon=android
StartupNotify=true
Categories=System;Settings;
EOF

# Create Android marketing apps folder
mkdir -p "${HOME_DIR}/Desktop/Android Apps"

# Copy shortcuts to desktop
cp "${HOME_DIR}/.local/share/applications/waydroid"*.desktop "${HOME_DIR}/Desktop/Android Apps/" || true

# Create instructions for marketing apps
cat > "${HOME_DIR}/Desktop/Android Apps/ANDROID_MARKETING_APPS.txt" << 'EOF'
ANDROID MARKETING APPS FOR BUSINESS

Recommended apps to install via Google Play Store in Waydroid:

SOCIAL MEDIA MANAGEMENT:
- Instagram Business
- TikTok for Business
- Facebook Business Suite
- LinkedIn Business
- Twitter Business
- Pinterest Business
- Snapchat Ads Manager

CONTENT CREATION:
- Canva
- Adobe Lightroom
- VSCO
- InShot Video Editor
- CapCut
- Unfold
- Over
- Reels Maker

ANALYTICS & INSIGHTS:
- Google Analytics
- Facebook Analytics
- Instagram Insights
- TikTok Analytics
- Hootsuite
- Buffer
- Later

PROJECT MANAGEMENT:
- Trello
- Asana
- Monday.com
- Slack
- Microsoft Teams
- Notion

EMAIL MARKETING:
- Mailchimp
- Constant Contact
- Campaign Monitor

To install apps:
1. Run 'waydroid-manager.sh start' to start Android
2. Open Google Play Store in Waydroid
3. Sign in with your Google account
4. Install the marketing apps you need
5. Access them through the Waydroid interface

For APK installation:
./waydroid-manager.sh install /path/to/app.apk
EOF

# Install Android File Transfer for easier file management
apt-get install -y android-file-transfer || true

# Create file sharing directory
mkdir -p "${HOME_DIR}/Android-Shared"
mkdir -p "${HOME_DIR}/Android-Shared/Marketing-Assets"
mkdir -p "${HOME_DIR}/Android-Shared/Content-Creation"
mkdir -p "${HOME_DIR}/Android-Shared/Projects"

# Set ownership
chown -R ${DEV_USERNAME}:${DEV_USERNAME} "${HOME_DIR}" 2>/dev/null || true

echo "Waydroid setup completed!"
echo "Run '${HOME_DIR}/waydroid-manager.sh setup-marketing' to configure for marketing use."
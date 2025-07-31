#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"

echo "🎨 Setting up KDE desktop and applications..."

# Function to safely copy desktop files
safe_copy() {
    local src="$1"
    local dest="$2"
    if [ -f "$src" ]; then
        cp "$src" "$dest" && echo "✓ Copied $(basename $src)" || echo "⚠ Failed to copy $(basename $src)"
    else
        echo "⚠ Source file not found: $src"
    fi
}

# Function to modify exec lines safely
modify_exec() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"
    if [ -f "$file" ]; then
        sed -i "s|$pattern|$replacement|g" "$file" && echo "✓ Modified $(basename $file)" || echo "⚠ Failed to modify $(basename $file)"
    fi
}

# Wait for Flatpak installation to complete if it's running
if command -v flatpak >/dev/null 2>&1; then
    echo "📦 Waiting for Flatpak applications to finish installing..."
    timeout=60
    while [ $timeout -gt 0 ] && pgrep -f "flatpak.*install" >/dev/null 2>&1; do
        echo "Waiting for Flatpak install to complete... ($timeout seconds left)"
        sleep 5
        timeout=$((timeout-5))
    done
    echo "✅ Flatpak installation check complete"
fi

# Create desktop directory
mkdir -p "/home/$DEV_USERNAME/Desktop"

# APT/DEB applications to add to desktop
apt_apps=(
    "google-chrome" "brave-browser" "opera" "code"
    "libreoffice-writer" "libreoffice-calc" "libreoffice-draw"
    "vlc" "gimp" "inkscape" "krita" "blender" "darktable"
    "okular" "obs" "calibre-gui" "gitkraken" "postman"
    "dbeaver" "wire-desktop" "element-desktop" "signal-desktop"
    "nextcloud" "gnome-tweaks" "org.kde.konsole" "org.kde.dolphin"
    "gnome-terminal" "lxterminal" "terminator"
)

# Copy APT/DEB application shortcuts
echo "📱 Setting up APT/DEB application shortcuts..."
for app in "${apt_apps[@]}"; do
    src_file="/usr/share/applications/$app.desktop"
    dest_file="/home/$DEV_USERNAME/Desktop/$app.desktop"
    
    if [ -f "$src_file" ]; then
        safe_copy "$src_file" "$dest_file"
        
        # Modify specific applications to run without sandbox
        case "$app" in
            "google-chrome" | "brave-browser")
                modify_exec "$dest_file" "Exec=/usr/bin/google-chrome-stable" "Exec=/usr/bin/google-chrome-stable --no-sandbox"
                modify_exec "$dest_file" "Exec=/usr/bin/brave-browser-stable" "Exec=/usr/bin/brave-browser-stable --no-sandbox"
                ;;
        esac
        
        echo "✓ Added $app to desktop"
    else
        echo "⚠ Desktop file not found for $app"
    fi
done

# Flatpak applications to add to desktop
flatpak_apps=(
    "com.bitwarden.desktop" "com.adobe.Reader" "com.bluemail.BlueMail"
    "com.simplenote.Simplenote" "com.blackmagicdesign.resolve"
    "com.github.phase1geo.minder" "org.onlyoffice.desktopeditors"
    "com.wps.Office" "io.gitkraken.GitKraken" "com.getpostman.Postman"
    "com.obsproject.Studio" "com.calibre_ebook.calibre"
    "org.chromium.Chromium" "org.mozilla.firefox" "com.usebottles.bottles"
    "org.phoenicis.playonlinux" "com.mysql.Workbench" "com.google.AndroidStudio"
)

# Copy Flatpak application shortcuts
echo "📦 Setting up Flatpak application shortcuts..."
for app_id in "${flatpak_apps[@]}"; do
    # Search for the desktop file in Flatpak export directories
    desktop_file=""
    for export_dir in "/var/lib/flatpak/exports/share/applications" "/home/$DEV_USERNAME/.local/share/flatpak/exports/share/applications"; do
        if [ -f "$export_dir/$app_id.desktop" ]; then
            desktop_file="$export_dir/$app_id.desktop"
            break
        fi
    done
    
    if [ -n "$desktop_file" ]; then
        safe_copy "$desktop_file" "/home/$DEV_USERNAME/Desktop/$app_id.desktop"
        
        # Modify specific Flatpak applications to run without sandbox
        case "$app_id" in
            "com.bitwarden.desktop" | "org.chromium.Chromium")
                modify_exec "/home/$DEV_USERNAME/Desktop/$app_id.desktop" "Exec=.*flatpak run.*" "& --no-sandbox"
                ;;
        esac
        
        echo "✓ Added Flatpak app $app_id to desktop"
    else
        echo "⚠ Flatpak desktop file not found for $app_id"
    fi
done

# Setup autostart
echo "🚀 Setting up autostart applications..."
mkdir -p "/home/$DEV_USERNAME/.config/autostart"
if [ -f "/usr/share/applications/plank.desktop" ]; then
    safe_copy "/usr/share/applications/plank.desktop" "/home/$DEV_USERNAME/.config/autostart/plank.desktop"
    echo "✓ Added Plank to autostart"
else
    echo "⚠ Plank desktop file not found"
fi

# Create custom desktop shortcuts
echo "🎯 Creating custom application shortcuts..."

# Waydroid shortcut
cat > "/home/$DEV_USERNAME/Desktop/Waydroid.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid
Comment=Run Android applications
Exec=waydroid show-apps
Icon=waydroid
Categories=System;
Terminal=false
EOF

# Google Ads Editor shortcut  
cat > "/home/$DEV_USERNAME/Desktop/GoogleAdsEditor.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Ads Editor
Comment=Manage your Google Ads campaigns
Exec=wine "/home/DEV_USERNAME/.wine/drive_c/Program Files/Google/Google Ads Editor/google_ads_editor.exe"
Icon=wine
Categories=Office;
Terminal=false
EOF

# Download wallpaper
echo "🖼️ Downloading wallpaper..."
if ! wget -q -O /usr/share/backgrounds/marketing-wallpaper.jpg "https://images.unsplash.com/photo-1557804506-669a67965ba0?ixlib=rb-4.0.3&auto=format&fit=crop&w=1920&h=1080&q=80"; then
    echo "⚠ Failed to download wallpaper, creating fallback"
    mkdir -p /usr/share/backgrounds
    echo "Fallback wallpaper file" > /usr/share/backgrounds/marketing-wallpaper.jpg
fi

# Make all desktop files executable and set ownership
echo "🔧 Setting final permissions and ownership..."
if [ -d "/home/$DEV_USERNAME/Desktop" ]; then
    find "/home/$DEV_USERNAME/Desktop" -name "*.desktop" -exec chmod +x {} \; 2>/dev/null || true
fi
if [ -d "/home/$DEV_USERNAME/.config/autostart" ]; then
    find "/home/$DEV_USERNAME/.config/autostart" -name "*.desktop" -exec chmod +x {} \; 2>/dev/null || true
fi
chown -R "$DEV_USERNAME:$DEV_USERNAME" "/home/$DEV_USERNAME/Desktop" "/home/$DEV_USERNAME/.config" 2>/dev/null || true

echo "✅ Desktop setup completed successfully!"
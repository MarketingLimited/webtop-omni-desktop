#!/bin/bash
set -euxo pipefail

# Ensure flatpak is available
if ! command -v flatpak >/dev/null 2>&1; then
    echo "Flatpak is not installed" >&2
    exit 1
fi

# Make sure the Flathub remote exists
flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo

# Marketing Agency Focused Applications
apps=(
    # Core Design & Creative Tools
    "org.gimp.GIMP"
    "org.inkscape.Inkscape"
    "org.kde.krita"
    "org.blender.Blender"
    "com.adobe.Reader"
    
    # Video & Audio Production
    "org.kdenlive.kdenlive"
    "org.openshot.OpenShot"
    "org.shotcut.Shotcut"
    "org.audacityteam.Audacity"
    "com.obsproject.Studio"
    
    # Communication & Collaboration
    "com.slack.Slack"
    "com.discordapp.Discord"
    "us.zoom.Zoom"
    "com.microsoft.Teams"
    
    # Project Management & Productivity
    "com.notion.Notion"
    "com.toggl.TogglDesktop"
    "org.gnome.gitlab.somas.Apostrophe"
    
    # Development & API Tools
    "io.gitkraken.GitKraken"
    "com.getpostman.Postman"
    "org.onlyoffice.desktopeditors"
    "com.wps.Office"
    
    # Browsers for Testing
    "org.chromium.Chromium"
    "org.mozilla.firefox"
    "com.brave.Browser"
    
    # Security & Privacy
    "com.bitwarden.desktop"
    "org.signal.Signal"
    
    # File Management & Cloud
    "com.dropbox.Client"
    "com.nextcloud.desktopclient.nextcloud"
    
    # Email & Communication
    "com.bluemail.BlueMail"
    "org.mozilla.Thunderbird"
    
    # Legacy Applications (if needed)
    "com.blackmagicdesign.resolve"
    "com.mysql.Workbench"
    "com.google.AndroidStudio"
)

for app in "${apps[@]}"; do
    if ! flatpak info "$app" > /dev/null 2>&1; then
        flatpak install -y --noninteractive --or-update flathub "$app" || true
    fi
done

# Update any already installed Flatpak apps
flatpak update -y || true

#!/bin/bash
set -euo pipefail

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
    # Core Design & Creative Tools (APT provides GIMP, Inkscape, Krita, Blender)
    "com.adobe.Reader"

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

    # Security & Privacy (Signal installed via APT)
    "com.bitwarden.desktop"

    # File Management & Cloud (Nextcloud installed via APT)
    "com.dropbox.Client"

    # Email & Communication
    "com.bluemail.BlueMail"
    "org.mozilla.Thunderbird"

    # Media & Streaming
    "com.spotify.Client"

    # Legacy Applications (if needed)
    "com.blackmagicdesign.resolve"
    "com.mysql.Workbench"
    "com.google.AndroidStudio"
)

for app in "${apps[@]}"; do
    flatpak install -y --noninteractive --or-update flathub "$app" || true
done

# Update any already installed Flatpak apps
flatpak update -y --noninteractive || true

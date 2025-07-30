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

apps=(
    "com.bitwarden.desktop"
    "com.adobe.Reader"
    "com.bluemail.BlueMail"
    "com.simplenote.Simplenote"
    "com.blackmagicdesign.resolve"
    "com.github.phase1geo.minder"
    "org.onlyoffice.desktopeditors"
    "com.wps.Office"
    "io.gitkraken.GitKraken"
    "com.getpostman.Postman"
    "com.obsproject.Studio"
    "com.calibre_ebook.calibre"
    "org.chromium.Chromium"
    "org.mozilla.firefox"
    "com.usebottles.bottles"
    "org.phoenicis.playonlinux"
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

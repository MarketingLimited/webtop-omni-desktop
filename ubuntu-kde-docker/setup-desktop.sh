#!/bin/bash
set -euxo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DESKTOP_DIR="/home/${DEV_USERNAME}/Desktop"
mkdir -p "${DESKTOP_DIR}"

# Wait for flatpak apps to finish installing if flatpak is available
if command -v flatpak >/dev/null 2>&1; then
    for _ in {1..10}; do
        if flatpak list | grep -q "com.adobe.Reader"; then
            break
        fi
        sleep 5
    done
fi

# APT/DEB apps
apps=(
    "google-chrome.desktop"
    "brave-browser.desktop"
    "opera.desktop"
    "code.desktop"
    "libreoffice-writer.desktop"
    "libreoffice-calc.desktop"
    "libreoffice-draw.desktop"
    "vlc.desktop"
    "gimp.desktop"
    "inkscape.desktop"
    "krita.desktop"
    "blender.desktop"
    "darktable.desktop"
    "okular.desktop"
    "obs.desktop"
    "calibre-gui.desktop"
    "gitkraken.desktop"
    "postman.desktop"
    "dbeaver.desktop"
    "wire-desktop.desktop"
    "element-desktop.desktop"
    "signal-desktop.desktop"
    "nextcloud.desktop"
    "gnome-tweaks.desktop"
    "org.kde.konsole.desktop"
    "org.kde.dolphin.desktop"
    "gnome-terminal.desktop"
    "lxterminal.desktop"
    "terminator.desktop"
)

for app in "${apps[@]}"; do
    if [[ -f "/usr/share/applications/${app}" ]]; then
        cp "/usr/share/applications/${app}" "${DESKTOP_DIR}/"
        chmod +x "${DESKTOP_DIR}/${app}"
        case "${app}" in
            google-chrome.desktop|brave-browser.desktop|opera.desktop|code.desktop|element-desktop.desktop|signal-desktop.desktop|wire-desktop.desktop)
                sed -i '/^Exec=/ s@ %U@ --no-sandbox %U@; /^Exec=/ s@ %F@ --no-sandbox %F@; /^Exec=/ {/--no-sandbox/! s@$@ --no-sandbox@}' "${DESKTOP_DIR}/${app}"
                ;;
            *)
                ;;
        esac
    fi
done

# Flatpak Apps
flatpak_ids=(
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
for fapp in "${flatpak_ids[@]}"; do
    for exportdir in /var/lib/flatpak/exports/share/applications \
        /home/${DEV_USERNAME}/.local/share/flatpak/exports/share/applications; do
        desktop_path=$(find "${exportdir}" -maxdepth 1 -name "${fapp}*.desktop" 2>/dev/null | head -n1)
        if [[ -n "${desktop_path}" ]]; then
            cp "${desktop_path}" "${DESKTOP_DIR}/"
            desktop_file="${DESKTOP_DIR}/$(basename "${desktop_path}")"
            chmod +x "${desktop_file}"
            case "$(basename "${desktop_path}")" in
                com.bitwarden.desktop|org.chromium.Chromium*.desktop)
                    sed -i '/^Exec=/ s@ run @ run --no-sandbox @' "${desktop_file}"
                    ;;
                *)
                    ;;
            esac
        fi
    done
done

# Add plank to autostart
AUTOSTART_DIR="/home/${DEV_USERNAME}/.config/autostart"
mkdir -p "${AUTOSTART_DIR}"
if [[ -f /usr/share/applications/plank.desktop ]]; then
    cp /usr/share/applications/plank.desktop "${AUTOSTART_DIR}/"
fi

# Create Waydroid shortcut
cat <<EOF > "${DESKTOP_DIR}/Waydroid.desktop"
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
chmod +x "${DESKTOP_DIR}/Waydroid.desktop"

# Create Google Ads Editor shortcut
cat <<EOF > "${DESKTOP_DIR}/GoogleAdsEditor.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Ads Editor
Comment=Manage your Google Ads campaigns
Exec=wine "/home/${DEV_USERNAME}/.wine/drive_c/Program Files/Google/Google Ads Editor/google_ads_editor.exe"
Icon=wine
Categories=Office;
Terminal=false
EOF
chmod +x "${DESKTOP_DIR}/GoogleAdsEditor.desktop"

# Set wallpaper (optional)
WALLPAPER_URL="https://wallpaperaccess.com/full/3314875.jpg"
wget -O /usr/share/backgrounds/kde-custom-wallpaper.jpg "${WALLPAPER_URL}" || true

chmod -R +x "${DESKTOP_DIR}"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DESKTOP_DIR}" "${AUTOSTART_DIR}"

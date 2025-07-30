#!/bin/bash
set -euxo pipefail

# Setup Wine for Windows Applications
echo "Setting up Wine for Windows applications..."

DEV_USERNAME=${DEV_USERNAME:-devuser}
HOME_DIR="/home/${DEV_USERNAME}"
WINE_PREFIX="${HOME_DIR}/.wine"

# Ensure Wine directories exist
mkdir -p "${HOME_DIR}/.wine"
mkdir -p "${HOME_DIR}/.local/share/applications"
mkdir -p "${HOME_DIR}/Desktop"

# Initialize Wine prefix for the user
sudo -u ${DEV_USERNAME} WINEPREFIX="${WINE_PREFIX}" winecfg /v || true

# Configure Wine for Windows 10 compatibility
sudo -u ${DEV_USERNAME} WINEPREFIX="${WINE_PREFIX}" winetricks -q corefonts vcrun2019 dotnet48 || true

# Install essential Windows libraries
sudo -u ${DEV_USERNAME} WINEPREFIX="${WINE_PREFIX}" winetricks -q \
    gdiplus \
    msxml6 \
    vcrun2008 \
    vcrun2010 \
    vcrun2012 \
    vcrun2013 \
    vcrun2015 \
    d3dx9 \
    dxvk || true

# Download and install marketing tools via Wine

# Adobe Reader alternative - Foxit Reader
if [ ! -f "${HOME_DIR}/Downloads/FoxitReader.exe" ]; then
    mkdir -p "${HOME_DIR}/Downloads"
    wget -O "${HOME_DIR}/Downloads/FoxitReader.exe" \
        "https://www.foxit.com/downloads/pdf-reader-thanks.html?product=Foxit-Reader&platform=Windows&version=" || true
    
    if [ -f "${HOME_DIR}/Downloads/FoxitReader.exe" ]; then
        sudo -u ${DEV_USERNAME} WINEPREFIX="${WINE_PREFIX}" wine "${HOME_DIR}/Downloads/FoxitReader.exe" /S || true
    fi
fi

# Install IrfanView for image viewing/editing
if [ ! -f "${HOME_DIR}/Downloads/iview459_setup.exe" ]; then
    wget -O "${HOME_DIR}/Downloads/iview459_setup.exe" \
        "https://www.irfanview.com/files/iview459_setup.exe" || true
    
    if [ -f "${HOME_DIR}/Downloads/iview459_setup.exe" ]; then
        sudo -u ${DEV_USERNAME} WINEPREFIX="${WINE_PREFIX}" wine "${HOME_DIR}/Downloads/iview459_setup.exe" /silent || true
    fi
fi

# Create Wine application shortcuts
cat > "${HOME_DIR}/.local/share/applications/wine-notepad.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Windows Notepad
Comment=Simple text editor via Wine
Exec=env WINEPREFIX="${WINE_PREFIX}" wine notepad
Icon=wine-notepad
StartupNotify=true
Categories=Office;TextEditor;
EOF

cat > "${HOME_DIR}/.local/share/applications/wine-winecfg.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine Configuration
Comment=Configure Wine settings
Exec=env WINEPREFIX="${WINE_PREFIX}" winecfg
Icon=wine-winecfg
StartupNotify=true
Categories=System;Settings;
EOF

cat > "${HOME_DIR}/.local/share/applications/wine-uninstaller.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Wine Uninstaller
Comment=Uninstall Windows applications
Exec=env WINEPREFIX="${WINE_PREFIX}" wine uninstaller
Icon=wine-uninstaller
StartupNotify=true
Categories=System;Settings;
EOF

# Create Wine Programs folder on desktop
mkdir -p "${HOME_DIR}/Desktop/Windows Programs"

# Copy Wine shortcuts to desktop
cp "${HOME_DIR}/.local/share/applications/wine-"*.desktop "${HOME_DIR}/Desktop/Windows Programs/" || true

# Create script for easy Wine app installation
cat > "${HOME_DIR}/install-windows-app.sh" << 'EOF'
#!/bin/bash
# Easy Windows app installer via Wine
# Usage: ./install-windows-app.sh /path/to/installer.exe

if [ $# -eq 0 ]; then
    echo "Usage: $0 <installer.exe>"
    exit 1
fi

INSTALLER="$1"
WINEPREFIX="${HOME}/.wine"

if [ ! -f "$INSTALLER" ]; then
    echo "Installer file not found: $INSTALLER"
    exit 1
fi

echo "Installing Windows application via Wine..."
env WINEPREFIX="$WINEPREFIX" wine "$INSTALLER"
EOF

chmod +x "${HOME_DIR}/install-windows-app.sh"

# Create wine management scripts
cat > "${HOME_DIR}/wine-manager.sh" << 'EOF'
#!/bin/bash
# Wine Management Script

WINEPREFIX="${HOME}/.wine"

case "$1" in
    config)
        env WINEPREFIX="$WINEPREFIX" winecfg
        ;;
    uninstall)
        env WINEPREFIX="$WINEPREFIX" wine uninstaller
        ;;
    tricks)
        env WINEPREFIX="$WINEPREFIX" winetricks
        ;;
    reset)
        echo "This will delete your Wine prefix. Are you sure? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$WINEPREFIX"
            env WINEPREFIX="$WINEPREFIX" winecfg
        fi
        ;;
    *)
        echo "Wine Manager"
        echo "Usage: $0 {config|uninstall|tricks|reset}"
        echo "  config    - Configure Wine settings"
        echo "  uninstall - Uninstall Windows programs"
        echo "  tricks    - Run winetricks for additional components"
        echo "  reset     - Reset Wine prefix (removes all installed programs)"
        ;;
esac
EOF

chmod +x "${HOME_DIR}/wine-manager.sh"

# Set ownership
chown -R ${DEV_USERNAME}:${DEV_USERNAME} "${HOME_DIR}/.wine" "${HOME_DIR}/.local" "${HOME_DIR}/Desktop" "${HOME_DIR}"/*.sh 2>/dev/null || true

echo "Wine setup completed! Use wine-manager.sh to manage Windows applications."
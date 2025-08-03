#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "🔤 Setting up container font configuration..."

# Create font directories
mkdir -p "${DEV_HOME}/.config/fontconfig"
mkdir -p "${DEV_HOME}/.local/share/fonts"
mkdir -p /usr/share/fonts/container-fonts

# Create comprehensive font configuration
cat > "${DEV_HOME}/.config/fontconfig/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Font directories -->
  <dir>/usr/share/fonts</dir>
  <dir>/usr/local/share/fonts</dir>
  <dir prefix="xdg">fonts</dir>
  <dir>~/.local/share/fonts</dir>
  
  <!-- Cache directory -->
  <cachedir prefix="xdg">fontconfig</cachedir>
  <cachedir>~/.fontconfig</cachedir>
  
  <!-- Font rendering settings optimized for containers -->
  <match target="font">
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
    <edit name="lcdfilter" mode="assign">
      <const>lcddefault</const>
    </edit>
  </match>
  
  <!-- Default font preferences -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Liberation Serif</family>
      <family>DejaVu Serif</family>
      <family>Times New Roman</family>
    </prefer>
  </alias>
  
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Liberation Sans</family>
      <family>DejaVu Sans</family>
      <family>Arial</family>
    </prefer>
  </alias>
  
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Liberation Mono</family>
      <family>DejaVu Sans Mono</family>
      <family>Courier New</family>
    </prefer>
  </alias>
  
  <!-- KDE specific font settings -->
  <match target="pattern">
    <test qual="any" name="family">
      <string>system-ui</string>
    </test>
    <edit name="family" mode="assign" binding="same">
      <string>Liberation Sans</string>
    </edit>
  </match>
</fontconfig>
EOF

# Create KDE font configuration
mkdir -p "${DEV_HOME}/.config"
cat > "${DEV_HOME}/.config/kdeglobals" << 'EOF'
[General]
BrowserApplication=firefox
ColorScheme=Breeze
Name=Breeze
XftAntialias=true
XftHintStyle=hintslight
XftSubPixel=rgb
font=Liberation Sans,10,-1,5,50,0,0,0,0,0

[KDE]
ColorScheme=Breeze
LookAndFeelPackage=org.kde.breeze.desktop
widgetStyle=Breeze

[WM]
activeFont=Liberation Sans,10,-1,5,75,0,0,0,0,0
EOF

# Create Plasma font configuration
mkdir -p "${DEV_HOME}/.config/plasma-localerc"
cat > "${DEV_HOME}/.config/plasma-localerc" << 'EOF'
[Formats]
LANG=en_US.UTF-8
LC_NUMERIC=en_US.UTF-8
LC_TIME=en_US.UTF-8
LC_MONETARY=en_US.UTF-8
LC_MEASUREMENT=en_US.UTF-8
LC_COLLATE=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
useDetailed=true
EOF

# Pre-generate font cache
echo "🔧 Generating font cache..."
sudo -u "$DEV_USERNAME" bash -c '
export HOME=/home/devuser
fc-cache -fv
fc-list | head -10
'

# Create font installation script
cat > "${DEV_HOME}/.local/bin/install-fonts" << 'EOF'
#!/bin/bash
echo "🔤 Installing additional fonts..."

# Install Google Fonts
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Download and install popular fonts
fonts=(
    "https://github.com/google/fonts/raw/main/ofl/roboto/Roboto-Regular.ttf"
    "https://github.com/google/fonts/raw/main/ofl/opensans/OpenSans-Regular.ttf"
    "https://github.com/google/fonts/raw/main/ofl/sourcecodepro/SourceCodePro-Regular.ttf"
)

for font_url in "${fonts[@]}"; do
    font_name=$(basename "$font_url")
    if [ ! -f "$FONT_DIR/$font_name" ]; then
        echo "⬇️ Downloading $font_name..."
        wget -q -O "$FONT_DIR/$font_name" "$font_url" || echo "❌ Failed to download $font_name"
    fi
done

# Update font cache
fc-cache -fv
echo "✅ Font installation complete"
EOF

chmod +x "${DEV_HOME}/.local/bin/install-fonts"

# Create font diagnostics
cat > "${DEV_HOME}/.local/bin/font-diagnostics" << 'EOF'
#!/bin/bash
echo "=== Font Configuration Diagnostics ==="
echo ""
echo "=== Font Config File ==="
if [ -f "$HOME/.config/fontconfig/fonts.conf" ]; then
    echo "✅ Font config exists"
else
    echo "❌ Font config missing"
fi
echo ""
echo "=== Font Cache ==="
fc-cache --version
echo "Font cache location: $(fc-cache --help 2>&1 | grep -o '/.*fontconfig' | head -1)"
echo ""
echo "=== Available Fonts ==="
fc-list | wc -l | xargs echo "Total fonts:"
echo ""
echo "=== System Fonts ==="
fc-list : family | sort | uniq | head -20
echo ""
echo "=== Font Rendering Test ==="
echo "Liberation Sans available: $(fc-list | grep -i liberation | wc -l) variants"
echo "DejaVu fonts available: $(fc-list | grep -i dejavu | wc -l) variants"
EOF

chmod +x "${DEV_HOME}/.local/bin/font-diagnostics"

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.config"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.local"

echo "✅ Font configuration complete"
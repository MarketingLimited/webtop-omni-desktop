#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
APPLICATIONS_DIR="/home/${DEV_USERNAME}/.local/share/applications"
DESKTOP_DIR="/home/${DEV_USERNAME}/Desktop"

echo "🎯 Setting up marketing agency shortcuts..."

# Ensure directories exist
mkdir -p "$APPLICATIONS_DIR" "$DESKTOP_DIR"

# Create marketing web app shortcuts
cat > "$APPLICATIONS_DIR/canva.desktop" << 'EOF'
[Desktop Entry]
Name=Canva
Comment=Design platform for marketing materials
Exec=${BROWSER} --app=https://www.canva.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Graphics;Design;Office;
EOF

cat > "$APPLICATIONS_DIR/figma.desktop" << 'EOF'
[Desktop Entry]
Name=Figma
Comment=Collaborative design tool
Exec=google-chrome --app=https://www.figma.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Graphics;Design;Development;
EOF

cat > "$APPLICATIONS_DIR/google-analytics.desktop" << 'EOF'
[Desktop Entry]
Name=Google Analytics
Comment=Web analytics service
Exec=google-chrome --app=https://analytics.google.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;Office;
EOF

cat > "$APPLICATIONS_DIR/google-ads.desktop" << 'EOF'
[Desktop Entry]
Name=Google Ads
Comment=Online advertising platform
Exec=google-chrome --app=https://ads.google.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;Office;
EOF

cat > "$APPLICATIONS_DIR/mailchimp.desktop" << 'EOF'
[Desktop Entry]
Name=Mailchimp
Comment=Email marketing platform
Exec=google-chrome --app=https://mailchimp.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;Office;
EOF

cat > "$APPLICATIONS_DIR/hootsuite.desktop" << 'EOF'
[Desktop Entry]
Name=Hootsuite
Comment=Social media management
Exec=google-chrome --app=https://hootsuite.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;Office;
EOF

cat > "$APPLICATIONS_DIR/buffer.desktop" << 'EOF'
[Desktop Entry]
Name=Buffer
Comment=Social media scheduling
Exec=google-chrome --app=https://buffer.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;Office;
EOF

cat > "$APPLICATIONS_DIR/unsplash.desktop" << 'EOF'
[Desktop Entry]
Name=Unsplash
Comment=Free high-quality photos
Exec=google-chrome --app=https://unsplash.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Graphics;Photography;
EOF

cat > "$APPLICATIONS_DIR/pexels.desktop" << 'EOF'
[Desktop Entry]
Name=Pexels
Comment=Free stock photos and videos
Exec=google-chrome --app=https://pexels.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Graphics;Photography;
EOF

cat > "$APPLICATIONS_DIR/trello.desktop" << 'EOF'
[Desktop Entry]
Name=Trello
Comment=Project management tool
Exec=google-chrome --app=https://trello.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Office;ProjectManagement;
EOF

# Marketing tools array for desktop copying
marketing_apps=(
    "canva"
    "figma"
    "google-analytics"
    "google-ads"
    "mailchimp"
    "hootsuite"
    "buffer"
    "unsplash"
    "pexels"
    "trello"
)

# Copy shortcuts to desktop
for app in "${marketing_apps[@]}"; do
    if [ -f "$APPLICATIONS_DIR/${app}.desktop" ]; then
        cp "$APPLICATIONS_DIR/${app}.desktop" "$DESKTOP_DIR/"
        chmod +x "$DESKTOP_DIR/${app}.desktop"
    fi
done

# Create Marketing Tools folder on desktop
mkdir -p "$DESKTOP_DIR/Marketing Tools"
for app in "${marketing_apps[@]}"; do
    if [ -f "$APPLICATIONS_DIR/${app}.desktop" ]; then
        cp "$APPLICATIONS_DIR/${app}.desktop" "$DESKTOP_DIR/Marketing Tools/"
    fi
done

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "$DESKTOP_DIR" "$APPLICATIONS_DIR"

echo "✅ Marketing shortcuts setup complete"
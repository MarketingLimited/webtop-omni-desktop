#!/bin/bash
set -euxo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DESKTOP_DIR="/home/${DEV_USERNAME}/Desktop"
APPLICATIONS_DIR="/home/${DEV_USERNAME}/.local/share/applications"

mkdir -p "${DESKTOP_DIR}" "${APPLICATIONS_DIR}"

echo "🎯 Creating Marketing Agency Web App Shortcuts..."

# Social Media Management Tools
cat <<EOF > "${APPLICATIONS_DIR}/buffer.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Buffer
Comment=Social Media Management
Exec=google-chrome --app=https://publish.buffer.com --no-sandbox
Icon=web-browser
Categories=Network;Marketing;
Terminal=false
EOF

cat <<EOF > "${APPLICATIONS_DIR}/hootsuite.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Hootsuite
Comment=Social Media Management Platform
Exec=google-chrome --app=https://hootsuite.com --no-sandbox
Icon=web-browser
Categories=Network;Marketing;
Terminal=false
EOF

cat <<EOF > "${APPLICATIONS_DIR}/later.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Later
Comment=Visual Marketing Platform
Exec=google-chrome --app=https://later.com --no-sandbox
Icon=web-browser
Categories=Network;Marketing;
Terminal=false
EOF

# Analytics & SEO Tools
cat <<EOF > "${APPLICATIONS_DIR}/google-analytics.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Analytics
Comment=Web Analytics Platform
Exec=google-chrome --app=https://analytics.google.com --no-sandbox
Icon=web-browser
Categories=Network;Analytics;
Terminal=false
EOF

cat <<EOF > "${APPLICATIONS_DIR}/google-ads.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Ads
Comment=Online Advertising Platform
Exec=google-chrome --app=https://ads.google.com --no-sandbox
Icon=web-browser
Categories=Network;Marketing;
Terminal=false
EOF

cat <<EOF > "${APPLICATIONS_DIR}/semrush.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=SEMrush
Comment=SEO & Marketing Toolkit
Exec=google-chrome --app=https://semrush.com --no-sandbox
Icon=web-browser
Categories=Network;SEO;
Terminal=false
EOF

# Design & Creative Tools
cat <<EOF > "${APPLICATIONS_DIR}/canva.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Canva
Comment=Graphic Design Platform
Exec=google-chrome --app=https://canva.com --no-sandbox
Icon=web-browser
Categories=Graphics;Design;
Terminal=false
EOF

cat <<EOF > "${APPLICATIONS_DIR}/unsplash.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Unsplash
Comment=Stock Photos Platform
Exec=google-chrome --app=https://unsplash.com --no-sandbox
Icon=web-browser
Categories=Graphics;Photography;
Terminal=false
EOF

# Email Marketing
cat <<EOF > "${APPLICATIONS_DIR}/mailchimp.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Mailchimp
Comment=Email Marketing Platform
Exec=google-chrome --app=https://mailchimp.com --no-sandbox
Icon=web-browser
Categories=Network;Marketing;
Terminal=false
EOF

# Project Management
cat <<EOF > "${APPLICATIONS_DIR}/trello.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Trello
Comment=Project Management Tool
Exec=google-chrome --app=https://trello.com --no-sandbox
Icon=web-browser
Categories=Office;ProjectManagement;
Terminal=false
EOF

cat <<EOF > "${APPLICATIONS_DIR}/asana.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Asana
Comment=Team Collaboration Platform
Exec=google-chrome --app=https://app.asana.com --no-sandbox
Icon=web-browser
Categories=Office;ProjectManagement;
Terminal=false
EOF

# Copy shortcuts to desktop
marketing_apps=(
    "buffer.desktop"
    "hootsuite.desktop" 
    "later.desktop"
    "google-analytics.desktop"
    "google-ads.desktop"
    "canva.desktop"
    "mailchimp.desktop"
    "trello.desktop"
    "asana.desktop"
)

for app in "${marketing_apps[@]}"; do
    if [[ -f "${APPLICATIONS_DIR}/${app}" ]]; then
        cp "${APPLICATIONS_DIR}/${app}" "${DESKTOP_DIR}/"
        chmod +x "${DESKTOP_DIR}/${app}"
    fi
done

# Create Marketing Tools folder on desktop
mkdir -p "${DESKTOP_DIR}/Marketing Tools"
cp "${APPLICATIONS_DIR}"/*.desktop "${DESKTOP_DIR}/Marketing Tools/" 2>/dev/null || true

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DESKTOP_DIR}" "${APPLICATIONS_DIR}"

echo "✅ Marketing Agency shortcuts created successfully!"
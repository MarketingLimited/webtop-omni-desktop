#!/bin/bash
set -euo pipefail

# Default to google-chrome if BROWSER is not set
BROWSER="${BROWSER:-google-chrome}"

DEV_USERNAME="${DEV_USERNAME:-devuser}"
APPLICATIONS_DIR="/home/${DEV_USERNAME}/.local/share/applications"
DESKTOP_DIR="/home/${DEV_USERNAME}/Desktop"

echo "🎯 Setting up marketing agency shortcuts..."

# Ensure directories exist
mkdir -p "$APPLICATIONS_DIR" "$DESKTOP_DIR/Marketing Tools"

# App definitions: name|Display Name|Comment|URL|Categories
apps=(
  "canva|Canva|Design platform for marketing materials|https://www.canva.com|Graphics;Design;Office;"
  "figma|Figma|Collaborative design tool|https://www.figma.com|Graphics;Design;Development;"
  "google-analytics|Google Analytics|Web analytics service|https://analytics.google.com|Network;Office;"
  "google-ads|Google Ads|Online advertising platform|https://ads.google.com|Network;Office;"
  "mailchimp|Mailchimp|Email marketing platform|https://mailchimp.com|Network;Office;"
  "hootsuite|Hootsuite|Social media management|https://hootsuite.com|Network;Office;"
  "buffer|Buffer|Social media scheduling|https://buffer.com|Network;Office;"
  "later|Later|Social media scheduling|https://later.com|Network;Office;"
  "unsplash|Unsplash|Free high-quality photos|https://unsplash.com|Graphics;Photography;"
  "pexels|Pexels|Free stock photos and videos|https://pexels.com|Graphics;Photography;"
  "trello|Trello|Project management tool|https://trello.com|Office;ProjectManagement;"
  "asana|Asana|Project management platform|https://app.asana.com|Office;ProjectManagement;"
  "semrush|SEMrush|SEO and marketing analytics|https://www.semrush.com|Network;Office;"
  "ahrefs|Ahrefs|SEO and keyword tools|https://ahrefs.com|Network;Office;"
)

# Generate desktop entries and copy to desktop folders
for entry in "${apps[@]}"; do
  IFS='|' read -r file_id name comment url categories <<< "$entry"

  cat > "$APPLICATIONS_DIR/${file_id}.desktop" <<EOF
[Desktop Entry]
Name=$name
Comment=$comment
Exec=$BROWSER --app=$url
Icon=web-browser
Terminal=false
Type=Application
Categories=$categories
EOF

  for target in "$DESKTOP_DIR" "$DESKTOP_DIR/Marketing Tools"; do
    cp "$APPLICATIONS_DIR/${file_id}.desktop" "$target/"
    chmod +x "$target/${file_id}.desktop"
  done
done

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "$DESKTOP_DIR" "$APPLICATIONS_DIR"

echo "✅ Marketing shortcuts setup complete"


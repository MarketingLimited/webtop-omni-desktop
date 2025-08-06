#!/bin/bash
set -euo pipefail

# Setup desktop environment optimizations
echo "🖥️  Setting up desktop environment..."

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

# Ensure user exists
if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
    echo "⚠️  User $DEV_USERNAME not found, skipping desktop setup"
    exit 0
fi

# Create desktop directories
sudo -u "$DEV_USERNAME" mkdir -p "${DEV_HOME}/Desktop" "${DEV_HOME}/Documents" "${DEV_HOME}/Downloads"

# Set desktop wallpaper and theme (if possible)
if [ -d "/usr/share/plasma" ]; then
    echo "🎨 Configuring KDE desktop..."
    # Basic KDE configuration would go here
fi

# Set proper permissions
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Desktop setup completed"
#!/bin/bash
set -euo pipefail

# Setup desktop environment optimizations

# Icons: 🖥️ 🎨 📁 ✅ ⚠️

echo "🖥️  Setting up desktop environment..."

readonly DEV_USERNAME=${DEV_USERNAME:-devuser}
readonly DEV_HOME="/home/${DEV_USERNAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

export DEV_USERNAME DEV_HOME

# Ensure user exists
if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
    echo "⚠️  User $DEV_USERNAME not found, skipping desktop setup"
    exit 0
fi

# Create standard desktop directories
# Using install ensures proper permissions without separate chown
install -d -m 755 -o "$DEV_USERNAME" -g "$DEV_USERNAME" \
    "$DEV_HOME/Desktop" \
    "$DEV_HOME/Documents" \
    "$DEV_HOME/Downloads" \
    "$DEV_HOME/Pictures" \
    "$DEV_HOME/Videos" \
    "$DEV_HOME/Music" \
    "$DEV_HOME/Public" \
    "$DEV_HOME/Templates"

# Run KDE optimization script if KDE is installed
if [ -d "/usr/share/plasma" ] && [ -x "$SCRIPT_DIR/setup-kde-optimization.sh" ]; then
    echo "🎨 Running KDE optimization script..."
    "$SCRIPT_DIR/setup-kde-optimization.sh"
fi

# Ensure proper permissions on the home directory
chown -R "$DEV_USERNAME:$DEV_USERNAME" "$DEV_HOME"

echo "✅ Desktop setup completed"

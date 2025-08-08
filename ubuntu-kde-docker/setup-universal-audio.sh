#!/bin/bash
set -euo pipefail

# Setup universal audio integration for noVNC interfaces
echo "🔊 Setting up universal audio integration..."

NOVNC_DIR="/usr/share/novnc"
UNIVERSAL_AUDIO_SCRIPT="/opt/audio-bridge/universal-audio.js"

# Wait for noVNC to be ready
check_novnc_ready() {
    local timeout=30
    local count=0
    
    while [ $count -lt $timeout ]; do
        if [ -d "$NOVNC_DIR" ] && { [ -f "$NOVNC_DIR/vnc.html" ] || [ -f "$NOVNC_DIR/index.html" ]; }; then
            echo "✅ noVNC installation detected"
            return 0
        fi
        sleep 2
        count=$((count + 1))
    done
    
    echo "⚠️  noVNC not ready, skipping audio integration"
    return 1
}

# Copy universal audio script
if [ -f "$UNIVERSAL_AUDIO_SCRIPT" ] && check_novnc_ready; then
    echo "🔧 Copying universal audio script..."
    cp "$UNIVERSAL_AUDIO_SCRIPT" "$NOVNC_DIR/universal-audio.js" 2>/dev/null || {
        echo "⚠️  Could not copy audio script, continuing..."
    }

    # Set permissions
    chmod 644 "$NOVNC_DIR"/*.js 2>/dev/null || true
    chmod 644 "$NOVNC_DIR"/*.html 2>/dev/null || true

    echo "✅ Universal audio integration setup completed"
else
    echo "⚠️  Universal audio script not found or noVNC not ready, skipping"
fi

exit 0

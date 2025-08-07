#!/bin/bash
set -euo pipefail

# Setup universal audio integration for noVNC interfaces
echo "🔊 Setting up universal audio integration..."

NOVNC_DIR="/usr/share/novnc"
UNIVERSAL_WEBRTC_SCRIPT="/usr/local/bin/universal-webrtc.js"
HTML_FILES=("$NOVNC_DIR/index.html" "$NOVNC_DIR/vnc.html")

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

# Copy universal WebRTC script and inject references
if [ -f "$UNIVERSAL_WEBRTC_SCRIPT" ] && check_novnc_ready; then
    echo "🔧 Copying universal WebRTC script..."
    cp "$UNIVERSAL_WEBRTC_SCRIPT" "$NOVNC_DIR/" 2>/dev/null || {
        echo "⚠️  Could not copy WebRTC script, continuing..."
    }

    # Set permissions
    chmod 644 "$NOVNC_DIR"/*.js 2>/dev/null || true
    chmod 644 "$NOVNC_DIR"/*.html 2>/dev/null || true

    # Inject script tags into noVNC HTML files (idempotent)
    for html in "${HTML_FILES[@]}"; do
        [ -f "$html" ] || continue

        if ! grep -q 'audio-env.js' "$html"; then
            if grep -q 'universal-webrtc.js' "$html"; then
                sed -i '/universal-webrtc.js/i\\    <script src="audio-env.js"></script>' "$html"
            else
                sed -i '/<\/body>/i\\    <script src="audio-env.js"></script>' "$html"
            fi
        fi

        if ! grep -q 'universal-webrtc.js' "$html"; then
            sed -i '/<\/body>/i\\    <script src="universal-webrtc.js"></script>' "$html"
        fi
    done

    echo "✅ Universal audio integration setup completed"
else
    echo "⚠️  Universal WebRTC script not found or noVNC not ready, skipping"
fi

exit 0

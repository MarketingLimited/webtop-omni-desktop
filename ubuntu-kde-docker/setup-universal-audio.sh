#!/bin/bash

# Universal Audio Setup Script
# Sets up automatic audio connection for all noVNC interfaces

set -e

echo "🔊 Setting up universal audio integration for noVNC..."

# Define paths
NOVNC_DIR="/usr/share/novnc"
UNIVERSAL_AUDIO_SCRIPT="/usr/local/bin/universal-audio.js"

# Ensure noVNC directory exists
if [ ! -d "$NOVNC_DIR" ]; then
    echo "⚠️  noVNC directory not found at $NOVNC_DIR, creating placeholder..."
    mkdir -p "$NOVNC_DIR"
fi

# Copy universal audio script to noVNC directory
if [ -f "$UNIVERSAL_AUDIO_SCRIPT" ]; then
    cp "$UNIVERSAL_AUDIO_SCRIPT" "$NOVNC_DIR/universal-audio.js"
    echo "✅ Universal audio script copied to noVNC directory"
else
    echo "ℹ️  Universal audio script not found, will be created during integration"
fi

# Function to inject audio script into HTML files
inject_audio_script() {
    local html_file="$1"
    if [ -f "$html_file" ] && ! grep -q "universal-audio.js" "$html_file"; then
        # Create backup
        cp "$html_file" "${html_file}.backup.$(date +%s)" 2>/dev/null || true
        
        # Inject before closing body tag
        sed -i 's|</body>|    <script src="universal-audio.js"></script>\n</body>|' "$html_file"
        echo "✅ Enhanced $(basename "$html_file") with universal audio"
        return 0
    elif grep -q "universal-audio.js" "$html_file"; then
        echo "ℹ️  $(basename "$html_file") already has universal audio integration"
        return 0
    else
        echo "⚠️  $(basename "$html_file") not found"
        return 1
    fi
}

# Wait for noVNC installation if not ready
check_novnc_ready() {
    local retries=0
    while [ $retries -lt 30 ]; do
        if [ -f "$NOVNC_DIR/vnc.html" ] || [ -f "$NOVNC_DIR/index.html" ]; then
            return 0
        fi
        echo "⏳ Waiting for noVNC installation... (attempt $((retries + 1))/30)"
        sleep 2
        retries=$((retries + 1))
    done
    echo "⚠️  noVNC not ready after 60 seconds, proceeding anyway"
    return 1
}

# Check if noVNC is ready
check_novnc_ready

# Inject universal audio into all noVNC HTML files
echo "🔧 Injecting universal audio into noVNC files..."

# Standard noVNC files
inject_audio_script "$NOVNC_DIR/vnc.html"
inject_audio_script "$NOVNC_DIR/vnc_lite.html"
inject_audio_script "$NOVNC_DIR/index.html"

# Custom audio-enabled files
if [ -f "$NOVNC_DIR/vnc_audio.html" ]; then
    echo "ℹ️  vnc_audio.html already has built-in audio support"
fi

# Create universal audio redirect page if index.html doesn't exist
if [ ! -f "$NOVNC_DIR/index.html" ]; then
    cat > "$NOVNC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Desktop Environment</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #2d3748, #1a202c);
            color: white;
            margin: 0;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .loading-container {
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 16px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        h1 {
            margin-bottom: 20px;
            font-size: 32px;
            font-weight: 300;
        }
        p {
            margin-bottom: 30px;
            opacity: 0.9;
        }
        .btn {
            display: inline-block;
            background: #4299e1;
            color: white;
            text-decoration: none;
            padding: 12px 24px;
            border-radius: 8px;
            transition: all 0.2s ease;
            margin: 0 10px;
        }
        .btn:hover {
            background: #3182ce;
            transform: translateY(-2px);
        }
        .audio-indicator {
            font-size: 48px;
            margin-bottom: 20px;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 0.8; }
            50% { opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="loading-container">
        <div class="audio-indicator">🖥️🔊</div>
        <h1>Ubuntu KDE Desktop</h1>
        <p>Loading desktop environment with audio support...</p>
        <a href="vnc_audio.html" class="btn">🔊 Desktop with Audio</a>
        <a href="vnc.html" class="btn">🖥️ Desktop Only</a>
    </div>
    
    <script src="universal-audio.js"></script>
    <script>
        // Auto-redirect to audio-enabled version after 3 seconds
        setTimeout(() => {
            if (!localStorage.getItem('audio-disabled')) {
                window.location.href = 'vnc_audio.html';
            }
        }, 3000);
    </script>
</body>
</html>
EOF
    echo "✅ Created enhanced index.html with audio integration"
fi

# Set proper permissions
chmod 644 "$NOVNC_DIR"/*.html 2>/dev/null || true
chmod 644 "$NOVNC_DIR"/*.js 2>/dev/null || true

echo "✅ Universal audio integration completed!"
echo "🎯 Features enabled:"
echo "   - Auto-connect overlay on all noVNC pages"
echo "   - Click anywhere to enable audio streaming"
echo "   - Floating audio controls on all interfaces"
echo "   - Keyboard shortcut: Ctrl+Alt+A"
echo "   - Cross-browser compatibility (Chrome, Firefox, Safari)"
echo "   - Automatic connection fallback methods"
echo "   - Volume persistence across sessions"
echo "   - Mobile browser support"
echo ""
echo "🌐 Access methods:"
echo "   - Main interface: http://localhost:32768"
echo "   - Direct VNC: http://localhost:32768/vnc.html"
echo "   - Audio-enhanced: http://localhost:32768/vnc_audio.html"
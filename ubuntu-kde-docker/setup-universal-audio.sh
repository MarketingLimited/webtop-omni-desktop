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
    echo "Creating comprehensive noVNC home page..."
    # Use the same home page as integrate-audio-ui.sh creates
    cat > "$NOVNC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Desktop Environment Hub</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
            background: linear-gradient(135deg, #1a202c, #2d3748, #4a5568);
            color: white;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        .header h1 {
            font-size: 2.5rem;
            font-weight: 300;
            margin-bottom: 10px;
            background: linear-gradient(135deg, #4299e1, #63b3ed);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .header p {
            opacity: 0.8;
            font-size: 1.1rem;
        }
        .interfaces-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .interface-card {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            padding: 24px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: all 0.3s ease;
            text-decoration: none;
            color: inherit;
            display: block;
        }
        .interface-card:hover {
            transform: translateY(-4px);
            background: rgba(255, 255, 255, 0.15);
            border-color: rgba(66, 153, 225, 0.5);
        }
        .interface-icon {
            font-size: 2.5rem;
            margin-bottom: 16px;
            display: block;
        }
        .interface-title {
            font-size: 1.3rem;
            font-weight: 600;
            margin-bottom: 8px;
        }
        .interface-description {
            opacity: 0.8;
            line-height: 1.5;
            margin-bottom: 12px;
        }
        .interface-features {
            font-size: 0.9rem;
            opacity: 0.7;
        }
        .quick-actions {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 30px;
        }
        .quick-actions h3 {
            margin-bottom: 15px;
            color: #4299e1;
        }
        .action-buttons {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
        }
        .action-btn {
            background: rgba(66, 153, 225, 0.2);
            border: 1px solid rgba(66, 153, 225, 0.3);
            color: white;
            padding: 8px 16px;
            border-radius: 8px;
            text-decoration: none;
            font-size: 0.9rem;
            transition: all 0.3s ease;
        }
        .action-btn:hover {
            background: rgba(66, 153, 225, 0.3);
            border-color: rgba(66, 153, 225, 0.5);
        }
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-left: 8px;
        }
        .status-available { background: #68d391; }
        .status-unknown { background: #f6ad55; }
        .footer {
            text-align: center;
            opacity: 0.6;
            font-size: 0.9rem;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            padding-top: 20px;
        }
        @media (max-width: 768px) {
            .interfaces-grid {
                grid-template-columns: 1fr;
            }
            .header h1 {
                font-size: 2rem;
            }
            .action-buttons {
                justify-content: center;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ Desktop Environment Hub</h1>
            <p>Choose your preferred interface to access the remote desktop environment</p>
        </div>

        <div class="quick-actions">
            <h3>⚡ Quick Actions</h3>
            <div class="action-buttons">
                <a href="vnc_audio.html" class="action-btn">🔊 Full Desktop (Recommended)</a>
                <a href="vnc.html" class="action-btn">🖥️ Standard Desktop</a>
                <a href="vnc_lite.html" class="action-btn">⚡ Lightweight</a>
                <a href="#" class="action-btn" onclick="testAllConnections()">🔍 Test Connections</a>
            </div>
        </div>

        <div class="interfaces-grid">
            <a href="vnc_audio.html" class="interface-card" id="vnc-audio">
                <div class="interface-icon">🔊</div>
                <div class="interface-title">Desktop with Audio <span class="status-indicator status-available"></span></div>
                <div class="interface-description">
                    Full-featured desktop environment with integrated audio controls and optimized performance.
                </div>
                <div class="interface-features">
                    ✅ Audio streaming • ✅ Full desktop • ✅ Keyboard shortcuts • ✅ Mobile friendly
                </div>
            </a>

            <a href="vnc.html" class="interface-card" id="vnc-standard">
                <div class="interface-icon">🖥️</div>
                <div class="interface-title">Standard Desktop <span class="status-indicator status-available"></span></div>
                <div class="interface-description">
                    Classic noVNC interface with universal audio support for maximum compatibility.
                </div>
                <div class="interface-features">
                    ✅ Universal audio • ✅ High compatibility • ✅ Proven stability
                </div>
            </a>

            <a href="vnc_lite.html" class="interface-card" id="vnc-lite">
                <div class="interface-icon">⚡</div>
                <div class="interface-title">Lightweight Desktop <span class="status-indicator status-unknown"></span></div>
                <div class="interface-description">
                    Minimal interface for slower connections or older devices with essential features only.
                </div>
                <div class="interface-features">
                    ⚡ Fast loading • 📱 Low bandwidth • 🔧 Basic controls
                </div>
            </a>

            <a href="vnc_auto.html" class="interface-card" id="vnc-auto" style="display: none;">
                <div class="interface-icon">🚀</div>
                <div class="interface-title">Auto-Connect Desktop <span class="status-indicator status-unknown"></span></div>
                <div class="interface-description">
                    Automatically connects to the desktop without manual configuration.
                </div>
                <div class="interface-features">
                    🚀 Auto-connect • ⚙️ Pre-configured • 📺 Instant access
                </div>
            </a>

            <a href="audio-player.html" class="interface-card" id="audio-only" style="display: none;">
                <div class="interface-icon">🎧</div>
                <div class="interface-title">Audio-Only Player <span class="status-indicator status-unknown"></span></div>
                <div class="interface-description">
                    Standalone audio streaming without video for audio-focused applications.
                </div>
                <div class="interface-features">
                    🎧 Audio only • 📡 Low latency • 🔇 Lightweight
                </div>
            </a>
        </div>

        <div class="footer">
            <p>💡 Tip: Use Ctrl+Alt+A to toggle audio in any interface | Press F11 for fullscreen</p>
            <p>🔧 Having issues? Check browser compatibility and ensure audio permissions are granted</p>
        </div>
    </div>

    <script>
        // Auto-detect available interfaces
        document.addEventListener('DOMContentLoaded', function() {
            const interfaces = [
                { id: 'vnc-auto', url: 'vnc_auto.html' },
                { id: 'audio-only', url: 'audio-player.html' }
            ];

            interfaces.forEach(interface => {
                fetch(interface.url, { method: 'HEAD' })
                    .then(response => {
                        if (response.ok) {
                            document.getElementById(interface.id).style.display = 'block';
                            updateStatusIndicator(interface.id, 'available');
                        }
                    })
                    .catch(() => {
                        // Interface not available - keep hidden
                    });
            });

            // Test main interfaces
            testInterface('vnc-audio', 'vnc_audio.html');
            testInterface('vnc-standard', 'vnc.html');
            testInterface('vnc-lite', 'vnc_lite.html');

            // Load user preference
            const lastUsed = localStorage.getItem('lastUsedInterface');
            if (lastUsed) {
                const card = document.querySelector(`a[href="${lastUsed}"]`);
                if (card) {
                    card.style.borderColor = 'rgba(66, 153, 225, 0.7)';
                    card.style.background = 'rgba(66, 153, 225, 0.1)';
                }
            }
        });

        function testInterface(id, url) {
            fetch(url, { method: 'HEAD' })
                .then(response => {
                    updateStatusIndicator(id, response.ok ? 'available' : 'unknown');
                })
                .catch(() => {
                    updateStatusIndicator(id, 'unknown');
                });
        }

        function updateStatusIndicator(id, status) {
            const indicator = document.querySelector(`#${id} .status-indicator`);
            if (indicator) {
                indicator.className = `status-indicator status-${status}`;
            }
        }

        function testAllConnections() {
            alert('Testing all connections...\n\nThis will check if all interfaces are responding properly.');
            
            const interfaces = ['vnc_audio.html', 'vnc.html', 'vnc_lite.html', 'vnc_auto.html', 'audio-player.html'];
            const results = [];
            
            Promise.allSettled(
                interfaces.map(url => 
                    fetch(url, { method: 'HEAD' }).then(r => ({ url, status: r.ok ? 'OK' : 'Error' }))
                )
            ).then(responses => {
                responses.forEach((result, index) => {
                    if (result.status === 'fulfilled') {
                        results.push(`${interfaces[index]}: ${result.value.status}`);
                    } else {
                        results.push(`${interfaces[index]}: Not Found`);
                    }
                });
                alert('Connection Test Results:\n\n' + results.join('\n'));
            });
        }

        // Save user preference when clicking interface
        document.querySelectorAll('.interface-card').forEach(card => {
            card.addEventListener('click', function() {
                localStorage.setItem('lastUsedInterface', this.href.split('/').pop());
            });
        });
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
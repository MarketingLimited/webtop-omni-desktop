#!/bin/bash

# Audio Bridge Setup Script
# Sets up web-based audio streaming from PulseAudio to browser

set -e

echo "Setting up PulseAudio Web Audio Bridge..."

# Create audio bridge directory
mkdir -p /opt/audio-bridge
cd /opt/audio-bridge

# Create package.json for the audio bridge
cat > package.json << 'EOF'
{
  "name": "webtop-audio-bridge",
  "version": "1.0.0",
  "description": "WebRTC and WebSocket audio bridge for webtop",
  "main": "webrtc-audio-server.cjs",
  "dependencies": {
    "express": "^4.18.2",
    "ws": "^8.14.2"
  },
  "optionalDependencies": {
    "wrtc": "^0.4.7"
  },
  "scripts": {
    "start": "node webrtc-audio-server.cjs"
  }
}
EOF

# Install declared dependencies
echo "Installing Node.js dependencies..."
npm install --omit=dev || {
    echo "Failed to install basic dependencies, trying alternative approach..."
    npm install --omit=dev --no-optional
}

# Ensure node-pre-gyp is available for native builds
echo "Installing node-pre-gyp for native module support..."
npm install node-pre-gyp || {
    echo "Warning: node-pre-gyp installation failed; continuing without it"
}

# Try to install wrtc, but don't fail if it doesn't work
echo "Attempting to install WebRTC support..."
npm install wrtc --omit=dev --build-from-source || {
    echo "Warning: wrtc module failed to install, WebRTC will be disabled"
    echo "WebSocket fallback will still work"
}

# Copy the WebRTC audio server
cp /usr/local/bin/webrtc-audio-server.cjs ./webrtc-audio-server.cjs

# Copy shared audio client
cp /usr/local/bin/shared-audio-client.js ./shared-audio-client.js
# Create public directory for web assets
mkdir -p public

# Create improved audio player web page using shared client
cat > public/audio-player.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebTop Audio Player</title>
    <script src="../shared-audio-client.js"></script>
    <script src="../audio-env.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #1a202c, #2d3748);
            color: white;
            margin: 0;
            padding: 20px;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .audio-player {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            padding: 40px;
            text-align: center;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            max-width: 500px;
            width: 100%;
        }
        .audio-icon {
            font-size: 64px;
            margin-bottom: 20px;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); opacity: 0.8; }
            50% { transform: scale(1.1); opacity: 1; }
        }
        .status {
            margin: 20px 0;
            padding: 10px;
            border-radius: 8px;
            font-weight: 500;
        }
        .status.disconnected { background: rgba(229, 62, 62, 0.2); }
        .status.connecting { background: rgba(237, 137, 54, 0.2); }
        .status.connected { background: rgba(56, 161, 105, 0.2); }
        .controls {
            display: flex;
            gap: 15px;
            justify-content: center;
            margin: 30px 0;
        }
        button {
            background: #4299e1;
            border: none;
            color: white;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 16px;
            transition: all 0.2s ease;
        }
        button:hover { background: #3182ce; transform: translateY(-1px); }
        button:disabled { background: #718096; cursor: not-allowed; transform: none; }
        .volume-control {
            margin: 20px 0;
        }
        .volume-slider {
            width: 100%;
            height: 6px;
            border-radius: 3px;
            background: #4a5568;
            outline: none;
            cursor: pointer;
        }
        .info {
            margin-top: 30px;
            font-size: 14px;
            opacity: 0.8;
        }
        .method-indicator {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            margin-left: 10px;
        }
        .webrtc { background: rgba(56, 161, 105, 0.3); }
        .websocket { background: rgba(66, 153, 225, 0.3); }
    </style>
</head>
<body>
    <div class="audio-player">
        <div class="audio-icon">🎵</div>
        <h1>WebTop Audio Player</h1>
        <div id="status" class="status disconnected">
            Audio Disconnected
            <span id="method-indicator" class="method-indicator" style="display: none;"></span>
        </div>
        
        <div class="controls">
            <button id="connect-btn">Connect Audio</button>
            <button id="disconnect-btn" disabled>Disconnect</button>
        </div>
        
        <div class="volume-control">
            <label>Volume: <span id="volume-display">50%</span></label>
            <input type="range" id="volume-slider" class="volume-slider" min="0" max="100" value="50">
        </div>
        
        <div class="info">
            <p>This player attempts WebRTC first, then falls back to WebSocket streaming.</p>
            <p>Audio source: Desktop applications and system sounds</p>
        </div>
    </div>

    <script>
        class AudioPlayerUI {
            constructor() {
                this.audioClient = new SharedAudioClient({ debug: true });
                
                this.initElements();
                this.setupEventListeners();
                
                // Setup status handler
                this.audioClient.onStatusChange((status) => {
                    this.updateStatus(status.message, status.state, status.method);
                    this.updateUI(status);
                });
            }
            
            initElements() {
                this.elements = {
                    status: document.getElementById('status'),
                    methodIndicator: document.getElementById('method-indicator'),
                    connectBtn: document.getElementById('connect-btn'),
                    disconnectBtn: document.getElementById('disconnect-btn'),
                    volumeSlider: document.getElementById('volume-slider'),
                    volumeDisplay: document.getElementById('volume-display')
                };
            }
            
            setupEventListeners() {
                this.elements.connectBtn.addEventListener('click', () => this.audioClient.connect());
                this.elements.disconnectBtn.addEventListener('click', () => this.audioClient.disconnect());
                this.elements.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
            }
            
            updateStatus(message, state, method = null) {
                this.elements.status.textContent = message;
                this.elements.status.className = `status ${state}`;
                
                if (method) {
                    this.elements.methodIndicator.textContent = method.toUpperCase();
                    this.elements.methodIndicator.className = `method-indicator ${method}`;
                    this.elements.methodIndicator.style.display = 'inline-block';
                } else {
                    this.elements.methodIndicator.style.display = 'none';
                }
            }
            
            updateUI(status) {
                this.elements.connectBtn.disabled = status.isConnected;
                this.elements.disconnectBtn.disabled = !status.isConnected;
            }
            
            setVolume(value) {
                this.audioClient.setVolume(value);
                this.elements.volumeDisplay.textContent = `${value}%`;
            }
        }
        
        // Initialize player when page loads
        document.addEventListener('DOMContentLoaded', () => {
            new AudioPlayerUI();
        });
    </script>
</body>
</html>
EOF

echo "✅ Audio bridge setup completed"
echo "📁 Files created in /opt/audio-bridge/"
echo "🌐 Audio player available at: /audio-player.html"
echo "🔧 WebRTC endpoint: /offer"
echo "🔌 WebSocket endpoint: /audio-stream"
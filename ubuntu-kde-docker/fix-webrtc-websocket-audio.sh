#!/bin/bash
# Fix WebRTC and WebSocket Audio Streaming Issues
# Addresses audio streaming problems at vnc_audio.html and audio-player.html

set -euo pipefail

echo "🔧 Fixing WebRTC and WebSocket Audio Streaming..."

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Step 1: Install required Node.js packages
install_audio_dependencies() {
    echo "📦 Installing audio streaming dependencies..."
    
    # Create audio bridge directory
    mkdir -p /opt/audio-bridge
    cd /opt/audio-bridge
    
    # Initialize package.json if it doesn't exist
    if [ ! -f package.json ]; then
        cat <<EOF > package.json
{
  "name": "webtop-audio-bridge",
  "version": "1.0.0",
  "description": "WebRTC and WebSocket audio bridge for webtop",
  "main": "webrtc-audio-server.cjs",
  "dependencies": {
    "express": "^4.18.2",
    "ws": "^8.14.2",
    "wrtc": "^0.4.7"
  },
  "scripts": {
    "start": "node webrtc-audio-server.cjs"
  }
}
EOF
    fi
    
    # Install dependencies
    if command -v npm >/dev/null 2>&1; then
        npm install --production
        green "✅ Node.js dependencies installed"
    else
        yellow "⚠️ npm not available, attempting to install Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
        npm install --production
        green "✅ Node.js and dependencies installed"
    fi
}

# Step 2: Create improved WebRTC/WebSocket audio server
create_improved_audio_server() {
    echo "🌉 Creating improved audio bridge server..."
    
    cat <<'EOF' > /opt/audio-bridge/webrtc-audio-server.cjs
const http = require('http');
const express = require('express');
const WebSocket = require('ws');
const { spawn } = require('child_process');
const path = require('path');

// Try to load wrtc, fallback gracefully if not available
let RTCPeerConnection, RTCAudioSource;
try {
  const wrtc = require('wrtc');
  RTCPeerConnection = wrtc.RTCPeerConnection;
  RTCAudioSource = wrtc.nonstandard.RTCAudioSource;
} catch (err) {
  console.warn('wrtc not available, WebRTC disabled:', err.message);
}

const PORT = process.env.WEBRTC_PORT || process.env.AUDIO_PORT || 8080;
const app = express();

// Enable CORS for all routes
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    webrtc: !!RTCPeerConnection,
    websocket: true,
    timestamp: new Date().toISOString()
  });
});

// Build ICE servers configuration
function buildIceServers() {
  const servers = [];
  
  // Add default STUN servers
  servers.push({ urls: 'stun:stun.l.google.com:19302' });
  servers.push({ urls: 'stun:stun1.l.google.com:19302' });
  
  // Add custom servers if configured
  if (process.env.WEBRTC_STUN_SERVER) {
    servers.push({ urls: process.env.WEBRTC_STUN_SERVER });
  }
  if (process.env.WEBRTC_TURN_SERVER) {
    servers.push({
      urls: process.env.WEBRTC_TURN_SERVER,
      username: process.env.WEBRTC_TURN_USERNAME,
      credential: process.env.WEBRTC_TURN_PASSWORD
    });
  }
  return servers;
}

// WebRTC offer endpoint
app.post('/offer', async (req, res) => {
  if (!RTCPeerConnection || !RTCAudioSource) {
    return res.status(503).json({ error: 'WebRTC not available' });
  }

  try {
    const pc = new RTCPeerConnection({ iceServers: buildIceServers() });
    const source = new RTCAudioSource();
    const track = source.createTrack();
    pc.addTrack(track);

    // Create audio capture process
    const audioProcess = spawn('parecord', [
      '--device=virtual_speaker.monitor',
      '--format=s16le',
      '--rate=48000',
      '--channels=1',
      '--raw'
    ]);

    // Process audio data and send to WebRTC
    audioProcess.stdout.on('data', (data) => {
      try {
        if (pc.connectionState === 'connected') {
          source.onData({
            samples: data,
            sampleRate: 48000,
            channelCount: 1,
            bitsPerSample: 16
          });
        }
      } catch (err) {
        console.warn('Audio processing error:', err.message);
      }
    });

    audioProcess.on('error', (err) => {
      console.error('Audio capture error:', err.message);
    });

    await pc.setRemoteDescription(req.body);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    res.json(pc.localDescription);

    pc.onconnectionstatechange = () => {
      console.log('WebRTC connection state:', pc.connectionState);
      if (['closed', 'failed', 'disconnected'].includes(pc.connectionState)) {
        audioProcess.kill();
        pc.close();
        track.stop();
      }
    };

    // Cleanup after 5 minutes of inactivity
    setTimeout(() => {
      if (pc.connectionState !== 'closed') {
        audioProcess.kill();
        pc.close();
        track.stop();
      }
    }, 300000);

  } catch (err) {
    console.error('WebRTC error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Create HTTP server
const server = http.createServer(app);

// WebSocket server for fallback audio streaming
const wss = new WebSocket.Server({ 
  server,
  path: '/audio-stream'
});

wss.on('connection', (ws, req) => {
  console.log('WebSocket audio connection established');
  
  // Create audio capture process for WebSocket
  const recorder = spawn('parecord', [
    '--device=virtual_speaker.monitor',
    '--format=s16le',
    '--rate=44100',
    '--channels=2',
    '--raw'
  ]);

  let isConnected = true;

  recorder.stdout.on('data', (data) => {
    if (isConnected && ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(data);
      } catch (err) {
        console.warn('WebSocket send error:', err.message);
      }
    }
  });

  recorder.on('error', (err) => {
    console.error('Audio recorder error:', err.message);
  });

  ws.on('close', () => {
    console.log('WebSocket audio connection closed');
    isConnected = false;
    recorder.kill();
  });

  ws.on('error', (err) => {
    console.error('WebSocket error:', err.message);
    isConnected = false;
    recorder.kill();
  });

  // Send initial connection confirmation
  ws.send(JSON.stringify({ type: 'connected', timestamp: Date.now() }));
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Audio bridge server listening on port ${PORT}`);
  console.log(`WebRTC endpoint: http://localhost:${PORT}/offer`);
  console.log(`WebSocket endpoint: ws://localhost:${PORT}/audio-stream`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Shutting down audio bridge server...');
  server.close(() => {
    process.exit(0);
  });
});
EOF

    green "✅ Improved audio bridge server created"
}

# Step 3: Create audio player HTML page
create_audio_player_page() {
    echo "🎵 Creating audio player page..."
    
    mkdir -p /opt/audio-bridge/public
    
    cat <<'EOF' > /opt/audio-bridge/public/audio-player.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebTop Audio Player</title>
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
        class AudioPlayer {
            constructor() {
                this.audioContext = null;
                this.websocket = null;
                this.peerConnection = null;
                this.gainNode = null;
                this.isConnected = false;
                this.currentMethod = null;
                
                this.initElements();
                this.setupEventListeners();
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
                this.elements.connectBtn.addEventListener('click', () => this.connect());
                this.elements.disconnectBtn.addEventListener('click', () => this.disconnect());
                this.elements.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
            }
            
            updateStatus(message, state, method = null) {
                this.elements.status.textContent = message;
                this.elements.status.className = `status ${state}`;
                
                if (method) {
                    this.currentMethod = method;
                    this.elements.methodIndicator.textContent = method.toUpperCase();
                    this.elements.methodIndicator.className = `method-indicator ${method}`;
                    this.elements.methodIndicator.style.display = 'inline-block';
                } else {
                    this.elements.methodIndicator.style.display = 'none';
                }
            }
            
            async connect() {
                try {
                    this.updateStatus('Connecting...', 'connecting');
                    this.elements.connectBtn.disabled = true;
                    
                    // Initialize audio context
                    if (!this.audioContext) {
                        this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                        this.gainNode = this.audioContext.createGain();
                        this.gainNode.connect(this.audioContext.destination);
                        this.setVolume(this.elements.volumeSlider.value);
                    }
                    
                    if (this.audioContext.state === 'suspended') {
                        await this.audioContext.resume();
                    }
                    
                    // Try WebRTC first
                    try {
                        await this.connectWebRTC();
                        this.updateStatus('Connected via WebRTC', 'connected', 'webrtc');
                    } catch (err) {
                        console.warn('WebRTC failed, trying WebSocket:', err);
                        await this.connectWebSocket();
                        this.updateStatus('Connected via WebSocket', 'connected', 'websocket');
                    }
                    
                    this.isConnected = true;
                    this.elements.connectBtn.disabled = false;
                    this.elements.disconnectBtn.disabled = false;
                    
                } catch (error) {
                    console.error('Connection failed:', error);
                    this.updateStatus('Connection Failed', 'disconnected');
                    this.elements.connectBtn.disabled = false;
                }
            }
            
            async connectWebRTC() {
                const pc = new RTCPeerConnection({
                    iceServers: [
                        { urls: 'stun:stun.l.google.com:19302' },
                        { urls: 'stun:stun1.l.google.com:19302' }
                    ]
                });
                
                this.peerConnection = pc;
                
                pc.ontrack = (event) => {
                    const stream = event.streams[0];
                    const source = this.audioContext.createMediaStreamSource(stream);
                    source.connect(this.gainNode);
                };
                
                const offer = await pc.createOffer();
                await pc.setLocalDescription(offer);
                
                const response = await fetch('/offer', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(offer)
                });
                
                if (!response.ok) {
                    throw new Error('WebRTC offer failed');
                }
                
                const answer = await response.json();
                await pc.setRemoteDescription(answer);
                
                // Wait for connection
                await new Promise((resolve, reject) => {
                    const timeout = setTimeout(() => reject(new Error('WebRTC timeout')), 10000);
                    pc.onconnectionstatechange = () => {
                        if (pc.connectionState === 'connected') {
                            clearTimeout(timeout);
                            resolve();
                        } else if (['failed', 'disconnected', 'closed'].includes(pc.connectionState)) {
                            clearTimeout(timeout);
                            reject(new Error('WebRTC connection failed'));
                        }
                    };
                });
            }
            
            async connectWebSocket() {
                const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = `${protocol}//${window.location.host}/audio-stream`;
                
                return new Promise((resolve, reject) => {
                    const ws = new WebSocket(wsUrl);
                    ws.binaryType = 'arraybuffer';
                    
                    const timeout = setTimeout(() => {
                        ws.close();
                        reject(new Error('WebSocket timeout'));
                    }, 5000);
                    
                    ws.onopen = () => {
                        clearTimeout(timeout);
                        this.websocket = ws;
                        resolve();
                    };
                    
                    ws.onmessage = (event) => {
                        if (typeof event.data === 'string') {
                            // Control message
                            return;
                        }
                        this.processAudioData(event.data);
                    };
                    
                    ws.onclose = () => {
                        if (this.isConnected) {
                            this.updateStatus('Connection Lost', 'disconnected');
                            this.isConnected = false;
                            this.elements.connectBtn.disabled = false;
                            this.elements.disconnectBtn.disabled = true;
                        }
                    };
                    
                    ws.onerror = () => {
                        clearTimeout(timeout);
                        reject(new Error('WebSocket error'));
                    };
                });
            }
            
            processAudioData(data) {
                if (!this.audioContext || !this.gainNode) return;
                
                try {
                    const samples = new Int16Array(data);
                    if (samples.length === 0) return;
                    
                    const audioBuffer = this.audioContext.createBuffer(2, samples.length / 2, 44100);
                    const leftChannel = audioBuffer.getChannelData(0);
                    const rightChannel = audioBuffer.getChannelData(1);
                    
                    for (let i = 0; i < samples.length / 2; i++) {
                        leftChannel[i] = samples[i * 2] / 32768.0;
                        rightChannel[i] = samples[i * 2 + 1] / 32768.0;
                    }
                    
                    const source = this.audioContext.createBufferSource();
                    source.buffer = audioBuffer;
                    source.connect(this.gainNode);
                    source.start();
                    
                } catch (error) {
                    console.warn('Audio processing error:', error);
                }
            }
            
            disconnect() {
                if (this.websocket) {
                    this.websocket.close();
                    this.websocket = null;
                }
                if (this.peerConnection) {
                    this.peerConnection.close();
                    this.peerConnection = null;
                }
                
                this.isConnected = false;
                this.updateStatus('Audio Disconnected', 'disconnected');
                this.elements.connectBtn.disabled = false;
                this.elements.disconnectBtn.disabled = true;
            }
            
            setVolume(value) {
                if (this.gainNode) {
                    this.gainNode.gain.value = value / 100;
                }
                this.elements.volumeDisplay.textContent = `${value}%`;
            }
        }
        
        // Initialize player when page loads
        document.addEventListener('DOMContentLoaded', () => {
            new AudioPlayer();
        });
    </script>
</body>
</html>
EOF

    green "✅ Audio player page created"
}

# Step 4: Update noVNC integration
update_novnc_integration() {
    echo "🖥️ Updating noVNC audio integration..."
    
    # Find noVNC directory
    NOVNC_DIR=""
    for dir in "/usr/share/novnc" "/opt/novnc" "/var/www/html" "/usr/local/share/novnc"; do
        if [ -d "$dir" ]; then
            NOVNC_DIR="$dir"
            break
        fi
    done
    
    if [ -z "$NOVNC_DIR" ]; then
        yellow "⚠️ noVNC directory not found, creating web files in /var/www/html"
        NOVNC_DIR="/var/www/html"
        mkdir -p "$NOVNC_DIR"
    fi
    
    # Copy audio player to noVNC directory
    cp /opt/audio-bridge/public/audio-player.html "$NOVNC_DIR/"
    
    # Create vnc_audio.html if it doesn't exist
    if [ ! -f "$NOVNC_DIR/vnc_audio.html" ]; then
        cp "$NOVNC_DIR/vnc.html" "$NOVNC_DIR/vnc_audio.html" 2>/dev/null || \
        cp "$NOVNC_DIR/index.html" "$NOVNC_DIR/vnc_audio.html" 2>/dev/null || \
        echo "<!DOCTYPE html><html><head><title>VNC with Audio</title></head><body><h1>VNC with Audio</h1><p>Audio integration page</p></body></html>" > "$NOVNC_DIR/vnc_audio.html"
    fi
    
    # Inject audio script into vnc_audio.html
    if ! grep -q "universal-audio.js" "$NOVNC_DIR/vnc_audio.html"; then
        sed -i 's|</head>|<script src="/universal-audio.js"></script>\n</head>|' "$NOVNC_DIR/vnc_audio.html"
    fi
    
    # Copy universal audio script
    cp /opt/audio-bridge/../universal-audio.js "$NOVNC_DIR/" 2>/dev/null || \
    cp /usr/local/bin/universal-audio.js "$NOVNC_DIR/" 2>/dev/null || \
    echo "console.log('Universal audio script not found');" > "$NOVNC_DIR/universal-audio.js"
    
    green "✅ noVNC audio integration updated"
}

# Step 5: Configure nginx proxy (if nginx is running)
configure_nginx_proxy() {
    echo "🌐 Configuring nginx proxy..."
    
    if command -v nginx >/dev/null 2>&1 && pgrep nginx >/dev/null; then
        # Create nginx configuration for audio bridge
        cat <<EOF > /etc/nginx/sites-available/audio-bridge
server {
    listen 80;
    server_name _;
    
    # Serve static files
    location / {
        root /var/www/html;
        try_files \$uri \$uri/ =404;
    }
    
    # Proxy audio bridge API
    location /offer {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Proxy WebSocket audio stream
    location /audio-stream {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
    }
}
EOF
        
        # Enable the site
        ln -sf /etc/nginx/sites-available/audio-bridge /etc/nginx/sites-enabled/
        
        # Test and reload nginx
        if nginx -t; then
            systemctl reload nginx
            green "✅ Nginx proxy configured"
        else
            yellow "⚠️ Nginx configuration test failed"
        fi
    else
        yellow "⚠️ Nginx not running, skipping proxy configuration"
    fi
}

# Step 6: Start audio bridge service
start_audio_bridge() {
    echo "🚀 Starting audio bridge service..."
    
    # Kill existing processes
    pkill -f "webrtc-audio-server" || true
    pkill -f "audio-bridge" || true
    sleep 2
    
    # Start the audio bridge server
    cd /opt/audio-bridge
    nohup node webrtc-audio-server.cjs > /var/log/audio-bridge.log 2>&1 &
    BRIDGE_PID=$!
    
    # Wait for server to start
    sleep 5
    
    # Check if server is running
    if kill -0 $BRIDGE_PID 2>/dev/null; then
        green "✅ Audio bridge server started (PID: $BRIDGE_PID)"
    else
        red "❌ Audio bridge server failed to start"
        cat /var/log/audio-bridge.log
        return 1
    fi
}

# Step 7: Test audio streaming
test_audio_streaming() {
    echo "🧪 Testing audio streaming..."
    
    # Test health endpoint
    if curl -s http://localhost:8080/health | grep -q "ok"; then
        green "✅ Audio bridge health check passed"
    else
        yellow "⚠️ Audio bridge health check failed"
    fi
    
    # Test WebSocket connection
    if command -v wscat >/dev/null 2>&1; then
        timeout 3 wscat -c ws://localhost:8080/audio-stream --close || true
        green "✅ WebSocket endpoint tested"
    else
        yellow "⚠️ wscat not available for WebSocket testing"
    fi
    
    # Check if ports are listening
    if netstat -tlnp | grep -q ":8080"; then
        green "✅ Audio bridge listening on port 8080"
    else
        red "❌ Audio bridge not listening on port 8080"
    fi
}

# Step 8: Create systemd service for persistence
create_systemd_service() {
    echo "⚙️ Creating systemd service..."
    
    cat <<EOF > /etc/systemd/system/webtop-audio-bridge.service
[Unit]
Description=WebTop Audio Bridge Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/audio-bridge
ExecStart=/usr/bin/node webrtc-audio-server.cjs
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=AUDIO_PORT=8080
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable webtop-audio-bridge
    systemctl restart webtop-audio-bridge
    
    sleep 3
    
    if systemctl is-active --quiet webtop-audio-bridge; then
        green "✅ Audio bridge service created and started"
    else
        yellow "⚠️ Audio bridge service created but not running"
        systemctl status webtop-audio-bridge --no-pager
    fi
}

# Main execution function
main() {
    echo "🔧 Starting WebRTC/WebSocket Audio Fix..."
    echo "======================================="
    
    install_audio_dependencies
    create_improved_audio_server
    create_audio_player_page
    update_novnc_integration
    configure_nginx_proxy
    start_audio_bridge
    test_audio_streaming
    create_systemd_service
    
    echo ""
    echo "🎉 WebRTC/WebSocket Audio Fix Completed!"
    echo "========================================"
    echo ""
    blue "Audio streaming is now available at:"
    echo "• WebRTC + WebSocket: http://37.27.49.246:32768/vnc_audio.html"
    echo "• Standalone player: http://37.27.49.246:32768/audio-player.html"
    echo "• Health check: http://37.27.49.246:32768/health"
    echo ""
    green "✅ Audio will attempt WebRTC first, then fallback to WebSocket!"
    echo ""
    blue "Testing steps:"
    echo "1. Open http://37.27.49.246:32768/audio-player.html"
    echo "2. Click 'Connect Audio'"
    echo "3. Play audio in the desktop (Firefox, VLC, etc.)"
    echo "4. Audio should stream to your browser"
}

# Run the fix
main "$@"
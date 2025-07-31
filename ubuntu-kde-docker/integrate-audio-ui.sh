#!/bin/bash

# Audio UI Integration Script
# Integrates audio controls into the noVNC interface

set -e

echo "Integrating audio controls into noVNC interface..."

# Find noVNC installation directory
NOVNC_DIR="/usr/share/novnc"

if [ ! -d "$NOVNC_DIR" ]; then
    echo "noVNC directory not found at $NOVNC_DIR"
    exit 1
fi

# Backup original vnc.html
if [ -f "$NOVNC_DIR/vnc.html" ] && [ ! -f "$NOVNC_DIR/vnc.html.backup" ]; then
    cp "$NOVNC_DIR/vnc.html" "$NOVNC_DIR/vnc.html.backup"
    echo "Backed up original vnc.html"
fi

# Create custom noVNC with audio integration
cat > "$NOVNC_DIR/vnc_audio.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Desktop with Audio</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: Arial, sans-serif;
            background: #2d3748;
            overflow: hidden;
        }
        
        #container {
            display: flex;
            flex-direction: column;
            height: 100vh;
        }
        
        #vnc-container {
            flex: 1;
            position: relative;
        }
        
        #vnc-frame {
            width: 100%;
            height: 100%;
            border: none;
        }
        
        #audio-controls {
            background: #1a202c;
            padding: 10px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-top: 1px solid #4a5568;
            height: 60px;
            min-height: 60px;
        }
        
        .audio-section {
            display: flex;
            align-items: center;
            gap: 15px;
        }
        
        .audio-button {
            background: #4299e1;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
        }
        
        .audio-button:hover {
            background: #3182ce;
        }
        
        .audio-button:disabled {
            background: #718096;
            cursor: not-allowed;
        }
        
        .volume-control {
            display: flex;
            align-items: center;
            gap: 8px;
            color: white;
        }
        
        .volume-slider {
            width: 80px;
        }
        
        .status-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
            color: white;
            font-size: 14px;
        }
        
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #e53e3e;
        }
        
        .status-dot.connected {
            background: #38a169;
        }
        
        .minimize-btn {
            background: none;
            color: #a0aec0;
            border: none;
            font-size: 16px;
            cursor: pointer;
            padding: 5px;
        }
        
        .minimize-btn:hover {
            color: white;
        }
        
        #audio-controls.minimized {
            height: 30px;
            min-height: 30px;
        }
        
        #audio-controls.minimized .audio-section {
            display: none;
        }
        
        #audio-controls.minimized .status-indicator {
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div id="container">
        <div id="vnc-container">
            <iframe id="vnc-frame" src="vnc.html"></iframe>
        </div>
        
        <div id="audio-controls">
            <div class="audio-section">
                <button id="connect-audio" class="audio-button">🔊 Connect Audio</button>
                <button id="disconnect-audio" class="audio-button" disabled>Disconnect</button>
                
                <div class="volume-control">
                    <span>Volume:</span>
                    <input type="range" id="volume-slider" class="volume-slider" min="0" max="100" value="50">
                    <span id="volume-label">50%</span>
                </div>
            </div>
            
            <div class="status-indicator">
                <div id="status-dot" class="status-dot"></div>
                <span id="status-text">Audio Disconnected</span>
            </div>
            
            <button id="minimize-btn" class="minimize-btn" title="Minimize audio controls">−</button>
        </div>
    </div>

    <script>
        class DesktopAudioManager {
            constructor() {
                this.audioContext = null;
                this.websocket = null;
                this.gainNode = null;
                this.isConnected = false;
                this.isMinimized = false;
                
                this.elements = {
                    connectBtn: document.getElementById('connect-audio'),
                    disconnectBtn: document.getElementById('disconnect-audio'),
                    volumeSlider: document.getElementById('volume-slider'),
                    volumeLabel: document.getElementById('volume-label'),
                    statusDot: document.getElementById('status-dot'),
                    statusText: document.getElementById('status-text'),
                    audioControls: document.getElementById('audio-controls'),
                    minimizeBtn: document.getElementById('minimize-btn')
                };
                
                this.setupEventListeners();
                this.checkAudioBridge();
            }
            
            setupEventListeners() {
                this.elements.connectBtn.addEventListener('click', () => this.connectAudio());
                this.elements.disconnectBtn.addEventListener('click', () => this.disconnectAudio());
                this.elements.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
                this.elements.minimizeBtn.addEventListener('click', () => this.toggleMinimize());
            }
            
            async checkAudioBridge() {
                try {
                    const response = await fetch('/audio-player.html');
                    if (response.ok) {
                        this.updateStatus('Audio bridge available', 'ready');
                    } else {
                        this.updateStatus('Audio bridge not available', 'error');
                    }
                } catch (error) {
                    this.updateStatus('Audio bridge check failed', 'error');
                }
            }
            
            async connectAudio() {
                try {
                    this.updateStatus('Connecting...', 'connecting');
                    
                    // Initialize Web Audio API
                    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    this.gainNode = this.audioContext.createGain();
                    this.gainNode.connect(this.audioContext.destination);
                    this.setVolume(this.elements.volumeSlider.value);
                    
                    // Connect to audio bridge WebSocket
                    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                    const wsUrl = `${protocol}//${window.location.hostname}:8080`;
                    
                    this.websocket = new WebSocket(wsUrl);
                    this.websocket.binaryType = 'arraybuffer';
                    
                    this.websocket.onopen = () => {
                        this.isConnected = true;
                        this.updateUI();
                        this.updateStatus('Audio connected', 'connected');
                    };
                    
                    this.websocket.onmessage = (event) => {
                        this.processAudioData(event.data);
                    };
                    
                    this.websocket.onclose = () => {
                        this.isConnected = false;
                        this.updateUI();
                        this.updateStatus('Audio disconnected', 'disconnected');
                    };
                    
                    this.websocket.onerror = (error) => {
                        console.error('Audio WebSocket error:', error);
                        this.updateStatus('Connection failed', 'error');
                    };
                    
                } catch (error) {
                    console.error('Failed to connect audio:', error);
                    this.updateStatus('Failed to connect: ' + error.message, 'error');
                }
            }
            
            disconnectAudio() {
                if (this.websocket) {
                    this.websocket.close();
                }
                if (this.audioContext) {
                    this.audioContext.close();
                }
                this.isConnected = false;
                this.updateUI();
                this.updateStatus('Audio disconnected', 'disconnected');
            }
            
            processAudioData(data) {
                if (!this.audioContext || !this.gainNode) return;
                
                try {
                    const samples = new Int16Array(data);
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
                    console.error('Error processing audio data:', error);
                }
            }
            
            setVolume(value) {
                if (this.gainNode) {
                    this.gainNode.gain.value = value / 100;
                }
                this.elements.volumeLabel.textContent = value + '%';
            }
            
            updateUI() {
                this.elements.connectBtn.disabled = this.isConnected;
                this.elements.disconnectBtn.disabled = !this.isConnected;
            }
            
            updateStatus(message, type) {
                this.elements.statusText.textContent = message;
                this.elements.statusDot.className = `status-dot ${type === 'connected' ? 'connected' : ''}`;
            }
            
            toggleMinimize() {
                this.isMinimized = !this.isMinimized;
                this.elements.audioControls.classList.toggle('minimized', this.isMinimized);
                this.elements.minimizeBtn.textContent = this.isMinimized ? '+' : '−';
                this.elements.minimizeBtn.title = this.isMinimized ? 'Expand audio controls' : 'Minimize audio controls';
            }
        }
        
        // Initialize when page loads
        window.addEventListener('load', () => {
            new DesktopAudioManager();
        });
    </script>
</body>
</html>
EOF

# Update the default noVNC page to redirect to audio-enabled version
cat > "$NOVNC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Desktop Environment</title>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=vnc_audio.html">
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: #2d3748;
            color: white;
        }
    </style>
</head>
<body>
    <h1>Loading Desktop Environment...</h1>
    <p>If you are not redirected automatically, <a href="vnc_audio.html" style="color: #4299e1;">click here</a>.</p>
</body>
</html>
EOF

echo "Audio UI integration completed!"
echo "The noVNC interface now includes audio controls"
echo "Audio will be available at http://localhost:32768"
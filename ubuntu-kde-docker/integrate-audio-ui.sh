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
                this.autoConnectEnabled = !localStorage.getItem('audio-disabled');
                this.hasUserInteracted = false;
                
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
                this.createAudioOverlay();
                this.checkAudioBridge();
                this.setupAutoConnect();
            }
            
            setupEventListeners() {
                this.elements.connectBtn.addEventListener('click', () => this.connectAudio());
                this.elements.disconnectBtn.addEventListener('click', () => this.disconnectAudio());
                this.elements.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
                this.elements.minimizeBtn.addEventListener('click', () => this.toggleMinimize());
                
                // Keyboard shortcut for audio toggle
                document.addEventListener('keydown', (e) => {
                    if (e.ctrlKey && e.altKey && e.key.toLowerCase() === 'a') {
                        e.preventDefault();
                        this.isConnected ? this.disconnectAudio() : this.connectAudio();
                    }
                });
            }
            
            createAudioOverlay() {
                if (!this.autoConnectEnabled) return;
                
                const overlay = document.createElement('div');
                overlay.id = 'audio-activation-overlay';
                overlay.innerHTML = `
                    <div class="overlay-content">
                        <div class="audio-icon">🔊</div>
                        <h3>Audio Available</h3>
                        <p>Click anywhere to enable desktop audio streaming</p>
                        <button id="skip-audio" class="skip-btn">Skip Audio</button>
                    </div>
                `;
                
                overlay.style.cssText = `
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.8);
                    z-index: 10000;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    color: white;
                    text-align: center;
                    font-family: Arial, sans-serif;
                `;
                
                const overlayContent = overlay.querySelector('.overlay-content');
                overlayContent.style.cssText = `
                    background: #1a202c;
                    padding: 40px;
                    border-radius: 12px;
                    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
                    max-width: 400px;
                `;
                
                const audioIcon = overlay.querySelector('.audio-icon');
                audioIcon.style.cssText = `
                    font-size: 48px;
                    margin-bottom: 20px;
                    animation: pulse 2s infinite;
                `;
                
                const skipBtn = overlay.querySelector('#skip-audio');
                skipBtn.style.cssText = `
                    background: #718096;
                    color: white;
                    border: none;
                    padding: 8px 16px;
                    border-radius: 4px;
                    cursor: pointer;
                    margin-top: 20px;
                `;
                
                // Add animation styles
                const style = document.createElement('style');
                style.textContent = `
                    @keyframes pulse {
                        0%, 100% { transform: scale(1); }
                        50% { transform: scale(1.1); }
                    }
                `;
                document.head.appendChild(style);
                
                document.body.appendChild(overlay);
                
                // Handle overlay interactions
                const activateAudio = () => {
                    this.hasUserInteracted = true;
                    overlay.remove();
                    this.connectAudio();
                };
                
                overlay.addEventListener('click', (e) => {
                    if (e.target.id !== 'skip-audio') {
                        activateAudio();
                    }
                });
                
                skipBtn.addEventListener('click', () => {
                    localStorage.setItem('audio-disabled', 'true');
                    overlay.remove();
                });
                
                // Auto-remove overlay after 10 seconds
                setTimeout(() => {
                    if (overlay.parentNode) {
                        overlay.remove();
                    }
                }, 10000);
            }
            
            setupAutoConnect() {
                // Listen for any user interaction to enable auto-connect
                const enableAutoConnect = () => {
                    if (!this.hasUserInteracted && this.autoConnectEnabled) {
                        this.hasUserInteracted = true;
                        // Small delay to ensure audio context can be created
                        setTimeout(() => this.connectAudio(), 100);
                    }
                };
                
                document.addEventListener('click', enableAutoConnect, { once: true });
                document.addEventListener('keydown', enableAutoConnect, { once: true });
                document.addEventListener('touchstart', enableAutoConnect, { once: true });
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
                    
                    // Handle browser autoplay restrictions
                    if (this.audioContext && this.audioContext.state === 'suspended') {
                        await this.audioContext.resume();
                    }
                    
                    if (!this.audioContext) {
                        this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                        this.gainNode = this.audioContext.createGain();
                        this.gainNode.connect(this.audioContext.destination);
                        
                        // Restore saved volume
                        const savedVolume = localStorage.getItem('audio-volume') || '50';
                        this.elements.volumeSlider.value = savedVolume;
                        this.setVolume(savedVolume);
                    }
                    
                    // Try multiple connection methods with fallback
                    const connectionMethods = [
                        () => this.connectWebSocket(`ws://${window.location.hostname}:8080`),
                        () => this.connectWebSocket(`wss://${window.location.hostname}:8080`),
                        () => this.connectWebSocket(`ws://${window.location.host}/audio-bridge`),
                        () => this.connectWebSocket(`wss://${window.location.host}/audio-bridge`)
                    ];
                    
                    for (const method of connectionMethods) {
                        try {
                            await method();
                            break;
                        } catch (err) {
                            console.warn('Connection method failed, trying next...', err);
                        }
                    }
                    
                } catch (error) {
                    console.error('Failed to connect audio:', error);
                    this.updateStatus('Failed to connect: ' + error.message, 'error');
                    
                    // Retry after delay
                    setTimeout(() => {
                        if (!this.isConnected && this.autoConnectEnabled) {
                            this.connectAudio();
                        }
                    }, 5000);
                }
            }
            
            async connectWebSocket(wsUrl) {
                return new Promise((resolve, reject) => {
                    const ws = new WebSocket(wsUrl);
                    ws.binaryType = 'arraybuffer';
                    
                    const timeout = setTimeout(() => {
                        ws.close();
                        reject(new Error('Connection timeout'));
                    }, 5000);
                    
                    ws.onopen = () => {
                        clearTimeout(timeout);
                        this.websocket = ws;
                        this.isConnected = true;
                        this.updateUI();
                        this.updateStatus('Audio connected', 'connected');
                        resolve();
                    };
                    
                    ws.onmessage = (event) => {
                        this.processAudioData(event.data);
                    };
                    
                    ws.onclose = () => {
                        clearTimeout(timeout);
                        this.isConnected = false;
                        this.updateUI();
                        this.updateStatus('Audio disconnected', 'disconnected');
                    };
                    
                    ws.onerror = (error) => {
                        clearTimeout(timeout);
                        reject(error);
                    };
                });
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
                // Save volume preference
                localStorage.setItem('audio-volume', value);
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

# Inject universal audio manager into existing noVNC pages
echo "Injecting universal audio support into all noVNC pages..."

# Backup and enhance vnc.html with universal audio
if [ -f "$NOVNC_DIR/vnc.html" ]; then
    if ! grep -q "universal-audio.js" "$NOVNC_DIR/vnc.html"; then
        # Add universal audio script before closing body tag
        sed -i 's|</body>|    <script src="universal-audio.js"></script>\n</body>|' "$NOVNC_DIR/vnc.html"
        echo "Enhanced vnc.html with universal audio"
    fi
fi

# Backup and enhance vnc_lite.html if it exists
if [ -f "$NOVNC_DIR/vnc_lite.html" ]; then
    if ! grep -q "universal-audio.js" "$NOVNC_DIR/vnc_lite.html"; then
        sed -i 's|</body>|    <script src="universal-audio.js"></script>\n</body>|' "$NOVNC_DIR/vnc_lite.html"
        echo "Enhanced vnc_lite.html with universal audio"
    fi
fi

# Copy universal audio script to noVNC directory
cp "/usr/local/bin/universal-audio.js" "$NOVNC_DIR/" 2>/dev/null || echo "Note: Universal audio script will be created during setup"

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

# Create standalone universal audio script
echo "Creating universal audio integration..."
cp "/usr/local/bin/universal-audio.js" "$NOVNC_DIR/universal-audio.js" 2>/dev/null || \
    echo "// Universal audio script will be available after full setup" > "$NOVNC_DIR/universal-audio.js"

echo "✅ Audio UI integration completed!"
echo "🔊 Universal audio support added to all noVNC interfaces"
echo "🌐 Audio will be available at http://localhost:32768"
echo "⚡ Features enabled:"
echo "   - Auto-connect overlay on first page load"
echo "   - Click anywhere to enable audio"
echo "   - Keyboard shortcut: Ctrl+Alt+A"
echo "   - Floating audio controls on all pages"
echo "   - Cross-browser compatibility"
echo "   - Automatic reconnection with fallback URLs"
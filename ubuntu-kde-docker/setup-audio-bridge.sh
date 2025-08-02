#!/bin/bash

# Audio Bridge Setup Script
# Sets up web-based audio streaming from PulseAudio to browser

set -euo pipefail

echo "Setting up PulseAudio Web Audio Bridge..."

# Ensure Node.js is available (installed via Dockerfile)
if ! command -v node >/dev/null; then
    echo "Node.js is required but not installed" >&2
    exit 1
fi

# Create audio bridge directory
mkdir -p /opt/audio-bridge
cd /opt/audio-bridge

# Create package.json for the audio bridge
cat > package.json << 'EOF'
{
  "name": "pulseaudio-web-bridge",
  "version": "1.0.0",
  "description": "Web bridge for PulseAudio streaming",
  "main": "server.js",
  "dependencies": {
    "ws": "^8.14.2",
    "express": "^4.18.2"
  }
}
EOF

# Install dependencies
npm install --omit=dev --no-audit --no-fund

# Create the audio bridge server
cat > server.js << 'EOF'
const WebSocket = require('ws');
const express = require('express');
const { spawn } = require('child_process');
const path = require('path');

const app = express();
const PORT = 8080;

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

const server = app.listen(PORT, () => {
    console.log(`Audio bridge server listening on port ${PORT}`);
});

// WebSocket server for audio streaming
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
    console.log('Client connected for audio streaming');
    
    // Start PulseAudio capture and stream to client with connection retry
    let parecord;
    const startRecording = () => {
        // Try different PulseAudio connection methods
        const parecordOptions = [
            // Try default (local socket)
            ['--format=s16le', '--rate=44100', '--channels=2', '--raw'],
            // Try TCP server fallback
            ['--server=tcp:localhost:4713', '--format=s16le', '--rate=44100', '--channels=2', '--raw'],
            // Try specific device fallback
            ['--device=virtual_speaker.monitor', '--format=s16le', '--rate=44100', '--channels=2', '--raw']
        ];
        
        let optionIndex = 0;
        
        const tryNextOption = () => {
            if (optionIndex >= parecordOptions.length) {
                console.error('All PulseAudio connection methods failed');
                ws.close();
                return;
            }
            
            console.log(`Trying PulseAudio connection method ${optionIndex + 1}/${parecordOptions.length}`);
            parecord = spawn('parecord', parecordOptions[optionIndex]);
            
            parecord.stdout.on('data', (data) => {
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send(data);
                }
            });
            
            parecord.stderr.on('data', (data) => {
                console.error(`PulseAudio error (method ${optionIndex + 1}):`, data.toString());
            });
            
            parecord.on('error', (err) => {
                console.error(`PulseAudio spawn error (method ${optionIndex + 1}):`, err);
                optionIndex++;
                setTimeout(tryNextOption, 1000);
            });
            
            parecord.on('exit', (code) => {
                if (code !== 0) {
                    console.log(`PulseAudio exited with code ${code}, trying next method...`);
                    optionIndex++;
                    setTimeout(tryNextOption, 1000);
                }
            });
        };
        
        tryNextOption();
    };
    
    startRecording();

    ws.on('close', () => {
        console.log('Client disconnected');
        if (parecord) parecord.kill();
    });

    ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        if (parecord) parecord.kill();
    });
});

console.log('PulseAudio Web Audio Bridge started');
EOF

# Create public directory for web assets
mkdir -p public

# Create audio player web page
cat > public/audio-player.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Desktop Audio</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background: #2d3748;
            color: white;
            font-family: Arial, sans-serif;
        }
        .audio-controls {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 20px;
        }
        button {
            padding: 10px 20px;
            background: #4299e1;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
        button:hover {
            background: #3182ce;
        }
        button:disabled {
            background: #718096;
            cursor: not-allowed;
        }
        .volume-control {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        input[type="range"] {
            width: 100px;
        }
        .status {
            margin-top: 10px;
            padding: 10px;
            border-radius: 5px;
        }
        .status.connected {
            background: #38a169;
        }
        .status.disconnected {
            background: #e53e3e;
        }
    </style>
</head>
<body>
    <h1>Desktop Audio Stream</h1>
    
    <div class="audio-controls">
        <button id="connectBtn">Connect Audio</button>
        <button id="disconnectBtn" disabled>Disconnect</button>
        
        <div class="volume-control">
            <label>Volume:</label>
            <input type="range" id="volumeSlider" min="0" max="100" value="50">
            <span id="volumeLabel">50%</span>
        </div>
    </div>
    
    <div id="status" class="status disconnected">Disconnected</div>
    
    <script>
        class AudioStreamer {
            constructor() {
                this.audioContext = null;
                this.websocket = null;
                this.gainNode = null;
                this.isConnected = false;
                
                this.connectBtn = document.getElementById('connectBtn');
                this.disconnectBtn = document.getElementById('disconnectBtn');
                this.volumeSlider = document.getElementById('volumeSlider');
                this.volumeLabel = document.getElementById('volumeLabel');
                this.status = document.getElementById('status');
                
                this.setupEventListeners();
            }
            
            setupEventListeners() {
                this.connectBtn.addEventListener('click', () => this.connect());
                this.disconnectBtn.addEventListener('click', () => this.disconnect());
                this.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
            }
            
            async connect() {
                try {
                    // Initialize audio context
                    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    this.gainNode = this.audioContext.createGain();
                    this.gainNode.connect(this.audioContext.destination);
                    this.setVolume(this.volumeSlider.value);
                    
                    // Connect WebSocket
                    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                    this.websocket = new WebSocket(`${protocol}//${window.location.host}`);
                    this.websocket.binaryType = 'arraybuffer';
                    
                    this.websocket.onopen = () => {
                        this.isConnected = true;
                        this.updateUI();
                        this.updateStatus('Connected to audio stream', 'connected');
                    };
                    
                    this.websocket.onmessage = (event) => {
                        this.processAudioData(event.data);
                    };
                    
                    this.websocket.onclose = () => {
                        this.isConnected = false;
                        this.updateUI();
                        this.updateStatus('Disconnected from audio stream', 'disconnected');
                    };
                    
                    this.websocket.onerror = (error) => {
                        console.error('WebSocket error:', error);
                        this.updateStatus('Connection error', 'disconnected');
                    };
                    
                } catch (error) {
                    console.error('Failed to connect:', error);
                    this.updateStatus('Failed to connect: ' + error.message, 'disconnected');
                }
            }
            
            disconnect() {
                if (this.websocket) {
                    this.websocket.close();
                }
                if (this.audioContext) {
                    this.audioContext.close();
                }
                this.isConnected = false;
                this.updateUI();
            }
            
            processAudioData(data) {
                if (!this.audioContext || !this.gainNode) return;
                
                try {
                    // Convert raw PCM data to AudioBuffer
                    const samples = new Int16Array(data);
                    const audioBuffer = this.audioContext.createBuffer(2, samples.length / 2, 44100);
                    
                    // Deinterleave stereo data
                    const leftChannel = audioBuffer.getChannelData(0);
                    const rightChannel = audioBuffer.getChannelData(1);
                    
                    for (let i = 0; i < samples.length / 2; i++) {
                        leftChannel[i] = samples[i * 2] / 32768.0;
                        rightChannel[i] = samples[i * 2 + 1] / 32768.0;
                    }
                    
                    // Play the audio
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
                this.volumeLabel.textContent = value + '%';
            }
            
            updateUI() {
                this.connectBtn.disabled = this.isConnected;
                this.disconnectBtn.disabled = !this.isConnected;
            }
            
            updateStatus(message, type) {
                this.status.textContent = message;
                this.status.className = `status ${type}`;
            }
        }
        
        // Initialize audio streamer when page loads
        window.addEventListener('load', () => {
            new AudioStreamer();
        });
    </script>
</body>
</html>
EOF

# Make the setup script executable
chmod +x /opt/audio-bridge/server.js

# Create supervisor configuration for the audio bridge
mkdir -p /etc/supervisor/conf.d
cat >/etc/supervisor/conf.d/audiobridge.conf <<'EOF'
[program:audiobridge]
command=/usr/bin/node /opt/audio-bridge/server.js
directory=/opt/audio-bridge
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/audio-bridge.log
stderr_logfile=/var/log/supervisor/audio-bridge.log
EOF

echo "✅ Audio bridge setup completed!"
echo "🔊 Audio streaming server will be available on port 8080"
echo "⚡ Features available:"
echo "   - WebSocket audio streaming on port 8080"
echo "   - Cross-browser audio playback support"
echo "   - Automatic fallback connection methods"

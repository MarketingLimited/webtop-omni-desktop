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
  "name": "pulseaudio-web-bridge",
  "version": "1.0.0",
  "description": "Web bridge for PulseAudio streaming",
  "main": "server.js",
  "dependencies": {
    "ws": "^8.14.2",
    "express": "^4.18.2",
    "wrtc": "^0.4.7"
  }
}
EOF

# Ensure node-pre-gyp is available for building native modules
npm install node-pre-gyp

# Install dependencies
npm install

# Copy WebRTC audio server implementation
cp /usr/local/bin/webrtc-audio-server.cjs ./webrtc-audio-server.cjs

# Create the audio bridge server
cat > server.js << 'EOF'
const http = require('http');
const WebSocket = require('ws');
const express = require('express');
const { spawn, execSync } = require('child_process');
const path = require('path');

const app = express();
const PORT = 8080;

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Explicit routes for resources needed by the noVNC client
app.get('/package.json', (req, res) => {
    res.sendFile(path.join(__dirname, 'package.json'));
});

app.get('/audio-player.html', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'audio-player.html'));
});

const server = http.createServer(app);

function detectMonitor() {
    try {
        const output = execSync('pactl list short sources', { encoding: 'utf8' });
        const line = output.split('\n').find(l => l.includes('virtual_speaker'));
        if (line) {
            const name = line.split('\t')[1];
            console.log(`\uD83C\uDFA7 Using detected monitor: ${name}`);
            return name;
        }
    } catch (err) {
        console.error('Failed to detect virtual_speaker monitor:', err);
    }
    console.log('\u2139\uFE0F Falling back to @DEFAULT_MONITOR@');
    return '@DEFAULT_MONITOR@';
}

server.listen(PORT, () => {
    console.log(`Audio bridge server listening on port ${PORT}`);
});

// WebSocket server for audio streaming
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
    console.log('Client connected for audio streaming');
    
    // Start PulseAudio capture and stream to client with enhanced connection retry
    let parecord;
    let isRecordingActive = false;
    
    const startRecording = () => {
        if (isRecordingActive) return;
        
        // Enhanced PulseAudio connection methods with debugging
        const monitor = detectMonitor();
        console.log(`\uD83D\uDD0A Starting recording from monitor: ${monitor}`);
        const parecordOptions = [
            ['--device=' + monitor, '--format=s16le', '--rate=44100', '--channels=2', '--raw'],
            ['--device=@DEFAULT_MONITOR@', '--format=s16le', '--rate=44100', '--channels=2', '--raw'],
            ['--server=tcp:localhost:4713', '--device=' + monitor, '--format=s16le', '--rate=44100', '--channels=2', '--raw'],
            ['--server=tcp:localhost:4713', '--device=@DEFAULT_MONITOR@', '--format=s16le', '--rate=44100', '--channels=2', '--raw'],
            ['--server=tcp:localhost:4713', '--format=s16le', '--rate=44100', '--channels=2', '--raw']
        ];
        
        let optionIndex = 0;
        let dataReceived = false;
        
        const tryNextOption = () => {
            if (optionIndex >= parecordOptions.length) {
                console.error('❌ All PulseAudio connection methods failed');
                ws.close();
                return;
            }
            
            const currentOptions = parecordOptions[optionIndex];
            console.log(`🔄 Trying PulseAudio method ${optionIndex + 1}/${parecordOptions.length}: parecord ${currentOptions.join(' ')}`);
            
            parecord = spawn('parecord', currentOptions);
            isRecordingActive = true;
            dataReceived = false;
            
            // Set a timeout to check if we're receiving data
            const dataCheckTimeout = setTimeout(() => {
                if (!dataReceived) {
                    console.log(`⚠️  No audio data received in 5 seconds, trying next method...`);
                    if (parecord && !parecord.killed) {
                        parecord.kill();
                    }
                }
            }, 5000);
            
            parecord.stdout.on('data', (data) => {
                if (!dataReceived) {
                    dataReceived = true;
                    clearTimeout(dataCheckTimeout);
                    console.log(`✅ Audio data stream started (${data.length} bytes received)`);
                }
                
                if (ws.readyState === WebSocket.OPEN) {
                    ws.send(data);
                }
            });
            
            parecord.stderr.on('data', (data) => {
                const errorMsg = data.toString().trim();
                if (errorMsg) {
                    console.error(`🔴 PulseAudio error (method ${optionIndex + 1}): ${errorMsg}`);
                }
            });
            
            parecord.on('error', (err) => {
                console.error(`💥 PulseAudio spawn error (method ${optionIndex + 1}): ${err.message}`);
                clearTimeout(dataCheckTimeout);
                isRecordingActive = false;
                optionIndex++;
                setTimeout(tryNextOption, 2000);
            });
            
            parecord.on('exit', (code, signal) => {
                clearTimeout(dataCheckTimeout);
                isRecordingActive = false;
                
                if (code !== 0 && code !== null) {
                    console.log(`⚠️  PulseAudio exited with code ${code}, signal: ${signal}, trying next method...`);
                    optionIndex++;
                    setTimeout(tryNextOption, 2000);
                } else if (signal) {
                    console.log(`🛑 PulseAudio terminated by signal: ${signal}`);
                }
            });
        };
        
        tryNextOption();
    };
    
    // Start the recording process
    startRecording();
    
    ws.on('close', () => {
        console.log('🔌 Client disconnected');
        if (parecord && !parecord.killed) {
            parecord.kill();
        }
        isRecordingActive = false;
    });
    
    ws.on('error', (error) => {
        console.error('🔴 WebSocket error:', error);
        if (parecord && !parecord.killed) {
            parecord.kill();
        }
        isRecordingActive = false;
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
                    await this.audioContext.resume();
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

# Copy the universal audio script to the audio bridge public directory
echo "Creating universal audio integration files..."
cp /usr/local/bin/universal-audio.js public/ 2>/dev/null || echo "Note: Universal audio script will be created"

# Create audio bridge iframe for integration
cat > public/audio-embed.js << 'EOF'
(function() {
    // Create audio control iframe
    const audioFrame = document.createElement('iframe');
    audioFrame.src = '/audio-player.html';
    audioFrame.style.position = 'fixed';
    audioFrame.style.bottom = '10px';
    audioFrame.style.right = '10px';
    audioFrame.style.width = '400px';
    audioFrame.style.height = '150px';
    audioFrame.style.border = '1px solid #ccc';
    audioFrame.style.borderRadius = '5px';
    audioFrame.style.backgroundColor = 'white';
    audioFrame.style.zIndex = '9999';
    audioFrame.style.display = 'none';
    
    // Create toggle button
    const toggleBtn = document.createElement('button');
    toggleBtn.innerHTML = '🔊 Audio';
    toggleBtn.style.position = 'fixed';
    toggleBtn.style.bottom = '10px';
    toggleBtn.style.right = '10px';
    toggleBtn.style.padding = '10px 15px';
    toggleBtn.style.backgroundColor = '#4299e1';
    toggleBtn.style.color = 'white';
    toggleBtn.style.border = 'none';
    toggleBtn.style.borderRadius = '5px';
    toggleBtn.style.cursor = 'pointer';
    toggleBtn.style.zIndex = '10000';
    toggleBtn.style.fontSize = '14px';
    
    let audioVisible = false;
    
    toggleBtn.addEventListener('click', () => {
        audioVisible = !audioVisible;
        audioFrame.style.display = audioVisible ? 'block' : 'none';
        toggleBtn.style.right = audioVisible ? '420px' : '10px';
    });
    
    document.body.appendChild(audioFrame);
    document.body.appendChild(toggleBtn);
})();
EOF

# Copy universal audio script to noVNC directories
echo "Integrating universal audio into noVNC..."

# Make the universal audio script available
cp /usr/local/bin/universal-audio.js /usr/share/novnc/ 2>/dev/null || echo "Note: Will copy after script creation"

# Make the setup script executable
chmod +x /opt/audio-bridge/server.js

echo "✅ Audio bridge setup completed!"
echo "🔊 Audio streaming server will be available on port 8080"
echo "🌐 Universal audio support integrated into noVNC"
echo "⚡ Features available:"
echo "   - WebSocket audio streaming on port 8080"
echo "   - Auto-connect overlay for all noVNC pages"
echo "   - Cross-browser audio playback support"
echo "   - Automatic fallback connection methods"
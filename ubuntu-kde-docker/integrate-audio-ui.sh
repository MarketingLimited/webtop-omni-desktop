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

    <script src="audio-env.js"></script>
    <script>
        class AudioDiagnostics {
            constructor() {
                this.enabled = new URLSearchParams(window.location.search).has('debug');
                this.metrics = {
                    processedFrames: 0,
                    underruns: 0,
                    overruns: 0,
                    bytesReceived: 0,
                    rmsHistory: [],
                    peakHistory: [],
                    queueDepth: 0,
                    maxQueueDepth: 0,
                    lastEnqueueTime: 0,
                    errors: []
                };
                this.analyser = null;
                this.meterWorklet = null;
                this.pingInterval = null;
                this.lastPing = 0;
                this.devices = [];
                this.testTone = null;
                
                if (this.enabled) {
                    this.init();
                }
            }
            
            async init() {
                this.log('AudioDiagnostics', 'Initializing comprehensive audio diagnostics');
                this.createDebugHUD();
                await this.enumerateDevices();
                this.startMetricsCollection();
                this.setupSelfTests();
                this.logEnvironment();
                
                // Show initialization message
                console.log('%c🎵 Audio Diagnostics Enabled', 'color: #4299e1; font-size: 16px; font-weight: bold;');
                console.log('📊 Debug HUD visible in top-left corner');
                console.log('🔧 Available methods: window.audioDiagnostics.runBeepTest(), .unlockAudio(), .copyDebugReport()');
                console.log('💡 Add ?debug=1 to URL to enable diagnostics on any audio page');
                
                this.metrics.startTime = Date.now();
            }
            
            log(category, message, data = null) {
                if (!this.enabled) return;
                const timestamp = new Date().toISOString();
                const logEntry = { timestamp, category, message, data };
                console.log(`[${category}] ${message}`, data || '');
                this.metrics.errors.push(logEntry);
                if (this.metrics.errors.length > 100) this.metrics.errors.shift();
            }
            
            createDebugHUD() {
                const hud = document.createElement('div');
                hud.id = 'audio-debug-hud';
                hud.innerHTML = `
                    <div class="debug-header">
                        <h3>🔧 Audio Diagnostics</h3>
                        <button id="toggle-debug" title="Toggle Debug Panel">⚙️</button>
                        <button id="copy-report" title="Copy Debug Report">📋</button>
                    </div>
                    <div class="debug-content">
                        <div class="debug-section">
                            <h4>Environment</h4>
                            <div id="env-info"></div>
                        </div>
                        <div class="debug-section">
                            <h4>Real-time Metrics</h4>
                            <div id="metrics-display"></div>
                            <div class="meter-bars">
                                <div class="meter">
                                    <label>Input RMS:</label>
                                    <div class="meter-bar"><div id="input-rms-bar"></div></div>
                                    <span id="input-rms-value">0.000</span>
                                </div>
                                <div class="meter">
                                    <label>Output RMS:</label>
                                    <div class="meter-bar"><div id="output-rms-bar"></div></div>
                                    <span id="output-rms-value">0.000</span>
                                </div>
                            </div>
                        </div>
                        <div class="debug-section">
                            <h4>Connection Status</h4>
                            <div id="connection-info"></div>
                        </div>
                        <div class="debug-section">
                            <h4>Output Devices</h4>
                            <select id="output-device-selector"></select>
                            <button id="refresh-devices">Refresh</button>
                        </div>
                        <div class="debug-section">
                            <h4>Self Tests</h4>
                            <div class="test-buttons">
                                <button id="beep-test">🔊 Beep Test</button>
                                <button id="unlock-audio">🔓 Unlock Audio</button>
                                <button id="format-test">📊 Format Test</button>
                                <button id="loopback-test">🔄 Loopback Test</button>
                            </div>
                        </div>
                    </div>
                `;
                
                hud.style.cssText = `
                    position: fixed;
                    top: 10px;
                    left: 10px;
                    width: 350px;
                    background: rgba(26, 32, 44, 0.98);
                    color: white;
                    border: 1px solid #4a5568;
                    border-radius: 8px;
                    z-index: 20000;
                    font-family: 'Courier New', monospace;
                    font-size: 12px;
                    max-height: 80vh;
                    overflow-y: auto;
                `;
                
                document.body.appendChild(hud);
                this.setupDebugEventListeners();
                this.addDebugStyles();
            }
            
            addDebugStyles() {
                const style = document.createElement('style');
                style.textContent = `
                    .debug-header {
                        background: #2d3748;
                        padding: 8px 12px;
                        border-bottom: 1px solid #4a5568;
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                    }
                    .debug-header h3 {
                        margin: 0;
                        font-size: 14px;
                    }
                    .debug-header button {
                        background: #4299e1;
                        border: none;
                        color: white;
                        padding: 4px 8px;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 12px;
                        margin-left: 4px;
                    }
                    .debug-content {
                        padding: 12px;
                        max-height: 70vh;
                        overflow-y: auto;
                    }
                    .debug-section {
                        margin-bottom: 16px;
                        border-bottom: 1px solid #4a5568;
                        padding-bottom: 12px;
                    }
                    .debug-section h4 {
                        margin: 0 0 8px 0;
                        color: #4299e1;
                        font-size: 13px;
                    }
                    .meter-bars {
                        margin-top: 8px;
                    }
                    .meter {
                        display: flex;
                        align-items: center;
                        margin-bottom: 4px;
                        gap: 8px;
                    }
                    .meter label {
                        width: 80px;
                        font-size: 11px;
                    }
                    .meter-bar {
                        flex: 1;
                        height: 12px;
                        background: #2d3748;
                        border-radius: 6px;
                        overflow: hidden;
                    }
                    .meter-bar div {
                        height: 100%;
                        background: linear-gradient(90deg, #38a169, #fbb040, #e53e3e);
                        width: 0%;
                        transition: width 0.1s ease;
                    }
                    .test-buttons {
                        display: grid;
                        grid-template-columns: 1fr 1fr;
                        gap: 4px;
                    }
                    .test-buttons button {
                        background: #38a169;
                        border: none;
                        color: white;
                        padding: 6px;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 11px;
                    }
                    .test-buttons button:hover {
                        background: #2f855a;
                    }
                    #output-device-selector {
                        width: 70%;
                        background: #2d3748;
                        color: white;
                        border: 1px solid #4a5568;
                        padding: 4px;
                        border-radius: 4px;
                    }
                    #refresh-devices {
                        background: #4299e1;
                        border: none;
                        color: white;
                        padding: 4px 8px;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 11px;
                        margin-left: 4px;
                    }
                `;
                document.head.appendChild(style);
            }
            
            setupDebugEventListeners() {
                document.getElementById('toggle-debug').addEventListener('click', () => {
                    const content = document.querySelector('.debug-content');
                    content.style.display = content.style.display === 'none' ? 'block' : 'none';
                });
                
                document.getElementById('copy-report').addEventListener('click', () => {
                    this.copyDebugReport();
                });
                
                document.getElementById('beep-test').addEventListener('click', () => {
                    this.runBeepTest();
                });
                
                document.getElementById('unlock-audio').addEventListener('click', () => {
                    this.unlockAudio();
                });
                
                document.getElementById('format-test').addEventListener('click', () => {
                    this.runFormatTest();
                });
                
                document.getElementById('loopback-test').addEventListener('click', () => {
                    this.runLoopbackTest();
                });
                
                document.getElementById('refresh-devices').addEventListener('click', () => {
                    this.enumerateDevices();
                });
            }
            
            logEnvironment() {
                const info = {
                    wsUrl: this.computeWebSocketURL(),
                    protocol: window.location.protocol,
                    isSecureContext: window.isSecureContext,
                    userAgent: navigator.userAgent,
                    audioHost: window.AUDIO_HOST,
                    audioPort: window.AUDIO_PORT,
                    wsScheme: window.AUDIO_WS_SCHEME
                };
                
                this.log('Environment', 'Browser environment', info);
                document.getElementById('env-info').innerHTML = Object.entries(info)
                    .map(([key, value]) => `<div><strong>${key}:</strong> ${value}</div>`)
                    .join('');
            }
            
            computeWebSocketURL() {
                const protocol = window.AUDIO_WS_SCHEME || (window.location.protocol === 'https:' ? 'wss' : 'ws');
                const host = window.AUDIO_HOST || window.location.hostname;
                const port = window.AUDIO_PORT || 8080;
                return `${protocol}://${host}:${port}/audio-stream`;
            }
            
            async enumerateDevices() {
                try {
                    this.devices = await navigator.mediaDevices.enumerateDevices();
                    const audioOutputs = this.devices.filter(d => d.kind === 'audiooutput');
                    
                    const selector = document.getElementById('output-device-selector');
                    selector.innerHTML = '';
                    
                    audioOutputs.forEach((device, index) => {
                        const option = document.createElement('option');
                        option.value = device.deviceId;
                        option.textContent = device.label || `Audio Output ${index + 1}`;
                        selector.appendChild(option);
                    });
                    
                    this.log('Devices', 'Audio output devices enumerated', audioOutputs);
                } catch (error) {
                    this.log('Devices', 'Failed to enumerate devices', error);
                }
            }
            
            startMetricsCollection() {
                setInterval(() => {
                    this.updateMetricsDisplay();
                }, 100);
                
                // Start ping monitoring
                this.pingInterval = setInterval(() => {
                    if (window.audioManager?.websocket?.readyState === WebSocket.OPEN) {
                        this.lastPing = performance.now();
                        window.audioManager.websocket.send('ping');
                    }
                }, 5000);
            }
            
            updateMetricsDisplay() {
                const audioCtx = window.audioManager?.audioContext;
                if (!audioCtx) return;
                
                const info = {
                    'AudioContext State': audioCtx.state,
                    'Sample Rate': audioCtx.sampleRate + ' Hz',
                    'Base Latency': (audioCtx.baseLatency * 1000).toFixed(1) + ' ms',
                    'Processed Frames': this.metrics.processedFrames,
                    'Bytes Received': this.metrics.bytesReceived,
                    'Queue Depth': this.metrics.queueDepth,
                    'Max Queue Depth': this.metrics.maxQueueDepth,
                    'Underruns': this.metrics.underruns,
                    'Overruns': this.metrics.overruns
                };
                
                document.getElementById('metrics-display').innerHTML = Object.entries(info)
                    .map(([key, value]) => `<div><strong>${key}:</strong> ${value}</div>`)
                    .join('');
                
                // Update WebSocket connection info
                const ws = window.audioManager?.websocket;
                const connectionInfo = {
                    'WebSocket State': ws ? this.getWebSocketStateText(ws.readyState) : 'Not connected',
                    'URL': this.computeWebSocketURL(),
                    'Ping Latency': this.lastPing ? (performance.now() - this.lastPing).toFixed(1) + ' ms' : 'N/A',
                    'Bytes/sec': this.calculateBytesPerSecond()
                };
                
                document.getElementById('connection-info').innerHTML = Object.entries(connectionInfo)
                    .map(([key, value]) => `<div><strong>${key}:</strong> ${value}</div>`)
                    .join('');
            }
            
            getWebSocketStateText(state) {
                const states = ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED'];
                return states[state] || 'UNKNOWN';
            }
            
            calculateBytesPerSecond() {
                // Calculate bytes per second based on recent history
                const now = Date.now();
                const recentBytes = this.metrics.bytesReceived;
                const timeDiff = (now - (this.metrics.startTime || now)) / 1000;
                return timeDiff > 0 ? Math.round(recentBytes / timeDiff) : 0;
            }
            
            trackAudioProcessing(audioData, inputRMS = 0, outputRMS = 0) {
                if (!this.enabled) return;
                
                this.metrics.processedFrames++;
                this.metrics.bytesReceived += audioData?.byteLength || 0;
                
                // Track RMS levels
                this.metrics.rmsHistory.push({ input: inputRMS, output: outputRMS, time: Date.now() });
                if (this.metrics.rmsHistory.length > 100) this.metrics.rmsHistory.shift();
                
                // Update visual meters
                this.updateRMSBars(inputRMS, outputRMS);
            }
            
            updateRMSBars(inputRMS, outputRMS) {
                const inputBar = document.getElementById('input-rms-bar');
                const outputBar = document.getElementById('output-rms-bar');
                const inputValue = document.getElementById('input-rms-value');
                const outputValue = document.getElementById('output-rms-value');
                
                if (inputBar) {
                    const inputPercent = Math.min(100, inputRMS * 100);
                    inputBar.style.width = inputPercent + '%';
                    inputValue.textContent = inputRMS.toFixed(3);
                }
                
                if (outputBar) {
                    const outputPercent = Math.min(100, outputRMS * 100);
                    outputBar.style.width = outputPercent + '%';
                    outputValue.textContent = outputRMS.toFixed(3);
                }
            }
            
            async runBeepTest() {
                try {
                    const audioCtx = window.audioManager?.audioContext || new AudioContext();
                    await this.unlockAudio();
                    
                    const oscillator = audioCtx.createOscillator();
                    const gainNode = audioCtx.createGain();
                    
                    oscillator.connect(gainNode);
                    gainNode.connect(audioCtx.destination);
                    
                    oscillator.frequency.value = 440;
                    gainNode.gain.value = 0.1;
                    
                    oscillator.start();
                    setTimeout(() => oscillator.stop(), 2000);
                    
                    this.log('SelfTest', 'Beep test completed - should hear 440Hz tone for 2 seconds');
                } catch (error) {
                    this.log('SelfTest', 'Beep test failed', error);
                }
            }
            
            async unlockAudio() {
                try {
                    const audioCtx = window.audioManager?.audioContext;
                    if (audioCtx && audioCtx.state === 'suspended') {
                        await audioCtx.resume();
                        this.log('Unlock', `AudioContext resumed: ${audioCtx.state}`);
                    }
                    
                    // Test media element play
                    const testAudio = new Audio();
                    testAudio.src = 'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA=';
                    await testAudio.play();
                    this.log('Unlock', 'Media element play successful');
                } catch (error) {
                    this.log('Unlock', 'Failed to unlock audio', error);
                }
            }
            
            runFormatTest() {
                try {
                    const testData = new Int16Array([1000, -1000, 2000, -2000]);
                    const audioCtx = window.audioManager?.audioContext || new AudioContext();
                    
                    const buffer = audioCtx.createBuffer(2, 2, 44100);
                    const leftChannel = buffer.getChannelData(0);
                    const rightChannel = buffer.getChannelData(1);
                    
                    leftChannel[0] = testData[0] / 32768;
                    leftChannel[1] = testData[2] / 32768;
                    rightChannel[0] = testData[1] / 32768;
                    rightChannel[1] = testData[3] / 32768;
                    
                    const source = audioCtx.createBufferSource();
                    source.buffer = buffer;
                    source.connect(audioCtx.destination);
                    source.start();
                    
                    this.log('SelfTest', 'Format test completed - int16 to float32 conversion test');
                } catch (error) {
                    this.log('SelfTest', 'Format test failed', error);
                }
            }
            
            runLoopbackTest() {
                try {
                    const audioCtx = window.audioManager?.audioContext || new AudioContext();
                    
                    // Create silent processing chain to test meter
                    const source = audioCtx.createBufferSource();
                    const buffer = audioCtx.createBuffer(2, 1024, 44100);
                    source.buffer = buffer;
                    
                    const analyser = audioCtx.createAnalyser();
                    source.connect(analyser);
                    
                    const dataArray = new Float32Array(analyser.fftSize);
                    analyser.getFloatTimeDomainData(dataArray);
                    
                    const rms = Math.sqrt(dataArray.reduce((sum, val) => sum + val * val, 0) / dataArray.length);
                    
                    this.log('SelfTest', `Loopback test completed - silent RMS: ${rms.toFixed(6)} (should be ~0)`);
                } catch (error) {
                    this.log('SelfTest', 'Loopback test failed', error);
                }
            }
            
            copyDebugReport() {
                const report = {
                    timestamp: new Date().toISOString(),
                    environment: {
                        userAgent: navigator.userAgent,
                        isSecureContext: window.isSecureContext,
                        protocol: window.location.protocol,
                        audioConfig: {
                            host: window.AUDIO_HOST,
                            port: window.AUDIO_PORT,
                            scheme: window.AUDIO_WS_SCHEME
                        }
                    },
                    metrics: this.metrics,
                    audioContext: window.audioManager?.audioContext ? {
                        state: window.audioManager.audioContext.state,
                        sampleRate: window.audioManager.audioContext.sampleRate,
                        baseLatency: window.audioManager.audioContext.baseLatency
                    } : null,
                    websocket: window.audioManager?.websocket ? {
                        readyState: window.audioManager.websocket.readyState,
                        url: window.audioManager.websocket.url
                    } : null,
                    devices: this.devices,
                    recentLogs: this.metrics.errors.slice(-20)
                };
                
                navigator.clipboard.writeText(JSON.stringify(report, null, 2)).then(() => {
                    this.log('Report', 'Debug report copied to clipboard');
                    alert('Debug report copied to clipboard!');
                }).catch(() => {
                    this.log('Report', 'Failed to copy to clipboard');
                    console.log('Debug Report:', report);
                });
            }
        }
        
        class DesktopAudioManager {
            constructor() {
                this.audioContext = null;
                this.websocket = null;
                this.gainNode = null;
                this.isConnected = false;
                this.isMinimized = false;
                this.autoConnectEnabled = !localStorage.getItem('audio-disabled');
                this.hasUserInteracted = false;
                this.diagnostics = new AudioDiagnostics();
                
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
                    
                    // Determine WebSocket protocol, allow override via environment
                    const wsProtocol = window.AUDIO_WS_SCHEME || (window.location.protocol === 'https:' ? 'wss' : 'ws');

                    // Try multiple connection methods with fallback using the matched protocol
                    const connectionMethods = [
                        () => this.connectWebSocket(`${wsProtocol}://${window.AUDIO_HOST || window.location.hostname}:${window.AUDIO_PORT || 8080}`),
                        () => this.connectWebSocket(`${wsProtocol}://${window.location.host}/audio-bridge`)
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
                    this.diagnostics.log('WebSocket', 'Attempting connection', { url: wsUrl });
                    
                    const ws = new WebSocket(wsUrl);
                    ws.binaryType = 'arraybuffer';
                    
                    const timeout = setTimeout(() => {
                        ws.close();
                        this.diagnostics.log('WebSocket', 'Connection timeout', { url: wsUrl });
                        reject(new Error('Connection timeout'));
                    }, 5000);
                    
                    ws.onopen = () => {
                        clearTimeout(timeout);
                        this.websocket = ws;
                        this.isConnected = true;
                        this.updateUI();
                        this.updateStatus('Audio connected', 'connected');
                        this.diagnostics.log('WebSocket', 'Connected successfully', { url: wsUrl });
                        this.diagnostics.metrics.startTime = Date.now();
                        resolve();
                    };
                    
                    ws.onmessage = (event) => {
                        // Handle ping/pong for latency measurement
                        if (event.data === 'pong' || (typeof event.data === 'string' && event.data === 'pong')) {
                            const latency = performance.now() - this.diagnostics.lastPing;
                            this.diagnostics.log('WebSocket', `Pong received, latency: ${latency.toFixed(1)}ms`);
                            return;
                        }
                        
                        this.processAudioData(event.data);
                    };
                    
                    ws.onclose = (event) => {
                        clearTimeout(timeout);
                        this.isConnected = false;
                        this.updateUI();
                        this.updateStatus('Audio disconnected', 'disconnected');
                        this.diagnostics.log('WebSocket', 'Connection closed', { 
                            code: event.code, 
                            reason: event.reason,
                            wasClean: event.wasClean 
                        });
                    };
                    
                    ws.onerror = (error) => {
                        clearTimeout(timeout);
                        this.diagnostics.log('WebSocket', 'Connection error', error);
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
                if (!this.audioContext || !this.gainNode || this.audioContext.state === 'closed') return;
                
                try {
                    // Validate data size
                    if (data.byteLength === 0) {
                        console.warn('⚠️  Received empty audio data');
                        this.diagnostics.log('Audio', 'Received empty audio data');
                        return;
                    }
                    
                    const samples = new Int16Array(data);
                    if (samples.length === 0 || samples.length % 2 !== 0) {
                        console.warn('⚠️  Invalid audio data length:', samples.length);
                        this.diagnostics.log('Audio', 'Invalid audio data length', { length: samples.length });
                        return;
                    }
                    
                    // Resume audio context if suspended (Chrome autoplay policy)
                    if (this.audioContext.state === 'suspended') {
                        this.audioContext.resume().catch(e => {
                            console.warn('Could not resume audio context:', e);
                            this.diagnostics.log('AudioContext', 'Failed to resume', e);
                        });
                        return; // Skip this frame, context will be ready next time
                    }
                    
                    const frameLength = samples.length / 2;
                    const audioBuffer = this.audioContext.createBuffer(2, frameLength, 44100);
                    
                    const leftChannel = audioBuffer.getChannelData(0);
                    const rightChannel = audioBuffer.getChannelData(1);
                    
                    // Calculate input RMS for diagnostics
                    let inputRMS = 0;
                    let maxSample = 0;
                    
                    // Convert 16-bit PCM to float with proper range checking
                    for (let i = 0; i < frameLength; i++) {
                        const leftSample = samples[i * 2];
                        const rightSample = samples[i * 2 + 1];
                        
                        // Convert to float (-1.0 to 1.0) with proper scaling
                        const leftFloat = Math.max(-1, Math.min(1, leftSample / 32768.0));
                        const rightFloat = Math.max(-1, Math.min(1, rightSample / 32768.0));
                        
                        leftChannel[i] = leftFloat;
                        rightChannel[i] = rightFloat;
                        
                        // Calculate RMS and peak for diagnostics
                        const sample = (Math.abs(leftFloat) + Math.abs(rightFloat)) / 2;
                        inputRMS += sample * sample;
                        maxSample = Math.max(maxSample, sample);
                    }
                    
                    inputRMS = Math.sqrt(inputRMS / frameLength);
                    
                    // Create output analyser for measuring final output
                    if (!this.outputAnalyser) {
                        this.outputAnalyser = this.audioContext.createAnalyser();
                        this.outputAnalyser.fftSize = 2048;
                        this.gainNode.connect(this.outputAnalyser);
                        this.outputAnalyser.connect(this.audioContext.destination);
                        this.outputBuffer = new Float32Array(this.outputAnalyser.fftSize);
                    }
                    
                    const source = this.audioContext.createBufferSource();
                    source.buffer = audioBuffer;
                    source.connect(this.gainNode);
                    
                    // Schedule playback immediately but handle potential overlap
                    const playTime = this.audioContext.currentTime;
                    source.start(playTime);
                    
                    // Measure output RMS
                    let outputRMS = 0;
                    if (this.outputAnalyser) {
                        this.outputAnalyser.getFloatTimeDomainData(this.outputBuffer);
                        let sum = 0;
                        for (let i = 0; i < this.outputBuffer.length; i++) {
                            sum += this.outputBuffer[i] * this.outputBuffer[i];
                        }
                        outputRMS = Math.sqrt(sum / this.outputBuffer.length);
                    }
                    
                    // Track audio processing metrics
                    this.diagnostics.trackAudioProcessing(data, inputRMS, outputRMS);
                    
                    // Clean up source after playback
                    setTimeout(() => {
                        try {
                            source.disconnect();
                        } catch (e) {
                            // Source already disconnected
                        }
                    }, (frameLength / 44100) * 1000 + 100);
                    
                    this.diagnostics.log('Audio', `Processed frame: ${frameLength} samples, inputRMS: ${inputRMS.toFixed(4)}, outputRMS: ${outputRMS.toFixed(4)}`);
                    
                } catch (error) {
                    console.error('❌ Error processing audio data:', error);
                    this.diagnostics.log('Audio', 'Processing error', error);
                    
                    // Attempt to recover audio context if it's in an error state
                    if (this.audioContext && this.audioContext.state === 'closed') {
                        console.log('🔄 Audio context closed, attempting to recreate...');
                        this.diagnostics.log('Recovery', 'AudioContext closed, recreating');
                        this.disconnectAudio();
                        setTimeout(() => this.connectAudio(), 1000);
                    }
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
            window.audioManager = new DesktopAudioManager();
            window.audioDiagnostics = window.audioManager.diagnostics;
            
            // Auto-start diagnostics if debug mode is enabled
            const urlParams = new URLSearchParams(window.location.search);
            if (urlParams.has('debug')) {
                console.log('🔧 Audio diagnostics enabled. Access via window.audioDiagnostics');
                console.log('📊 Debug HUD available on screen');
                console.log('🎵 To test: window.audioDiagnostics.runBeepTest()');
            }
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
        # Add audio configuration and universal audio scripts before closing body tag
        sed -i 's|</body>|    <script src="audio-env.js"></script>\n    <script src="universal-audio.js"></script>\n</body>|' "$NOVNC_DIR/vnc.html"
        echo "Enhanced vnc.html with universal audio"
    fi
fi

# Backup and enhance vnc_lite.html if it exists
if [ -f "$NOVNC_DIR/vnc_lite.html" ]; then
    if ! grep -q "universal-audio.js" "$NOVNC_DIR/vnc_lite.html"; then
        sed -i 's|</body>|    <script src="audio-env.js"></script>\n    <script src="universal-audio.js"></script>\n</body>|' "$NOVNC_DIR/vnc_lite.html"
        echo "Enhanced vnc_lite.html with universal audio"
    fi
fi

# Copy universal audio script to noVNC directory
cp "/usr/local/bin/universal-audio.js" "$NOVNC_DIR/" 2>/dev/null || echo "Note: Universal audio script will be created during setup"

# Create placeholder audio configuration file for runtime overrides
cat > "$NOVNC_DIR/audio-env.js" <<'EOF'
window.AUDIO_HOST = window.AUDIO_HOST || window.location.hostname;
window.AUDIO_PORT = window.AUDIO_PORT || 8080;
window.AUDIO_WS_SCHEME = window.AUDIO_WS_SCHEME || '';
EOF

# Create standalone audio player for testing
cat > "$NOVNC_DIR/audio-player.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Standalone Audio Player</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #2d3748;
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
        }
        .player {
            background: #1a202c;
            padding: 40px;
            border-radius: 12px;
            text-align: center;
        }
        .player-button {
            background: #4299e1;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            margin: 10px;
        }
        .player-button:disabled {
            background: #718096;
        }
        .status {
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="player">
        <h2>🎧 Standalone Audio Player</h2>
        <button id="connect-audio" class="player-button">Connect</button>
        <button id="disconnect-audio" class="player-button" disabled>Disconnect</button>
        <div id="status" class="status">Status: Disconnected</div>
    </div>
    <script src="audio-env.js"></script>
    <script>
        // Simplified Audio Manager for standalone player
        const connectBtn = document.getElementById('connect-audio');
        const disconnectBtn = document.getElementById('disconnect-audio');
        const statusEl = document.getElementById('status');
        let audioContext, websocket, gainNode;

        connectBtn.addEventListener('click', connectAudio);
        disconnectBtn.addEventListener('click', disconnectAudio);

        async function connectAudio() {
            updateStatus('Connecting...');
            connectBtn.disabled = true;

            try {
                if (!audioContext) {
                    audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    gainNode = audioContext.createGain();
                    gainNode.connect(audioContext.destination);
                }

                const wsProtocol = window.AUDIO_WS_SCHEME || (window.location.protocol === 'https:' ? 'wss' : 'ws');
                const wsUrl = `${wsProtocol}://${window.AUDIO_HOST || window.location.hostname}:${window.AUDIO_PORT || 8080}`;

                websocket = new WebSocket(wsUrl);
                websocket.binaryType = 'arraybuffer';

                websocket.onopen = () => {
                    updateStatus('Connected');
                    disconnectBtn.disabled = false;
                };

                websocket.onmessage = (event) => processAudioData(event.data);

                websocket.onclose = () => {
                    updateStatus('Disconnected');
                    connectBtn.disabled = false;
                    disconnectBtn.disabled = true;
                };

                websocket.onerror = (err) => {
                    updateStatus('Error: ' + err.message);
                    connectBtn.disabled = false;
                };

            } catch (error) {
                updateStatus('Error: ' + error.message);
                connectBtn.disabled = false;
            }
        }

        function disconnectAudio() {
            if (websocket) {
                websocket.close();
            }
            if (audioContext) {
                audioContext.close().then(() => {
                    audioContext = null;
                });
            }
            updateStatus('Disconnected');
            disconnectBtn.disabled = true;
            connectBtn.disabled = false;
        }

        function processAudioData(data) {
            if (!audioContext) return;
            const samples = new Int16Array(data);
            const buffer = audioContext.createBuffer(2, samples.length / 2, 44100);
            const left = buffer.getChannelData(0);
            const right = buffer.getChannelData(1);
            for (let i = 0; i < samples.length / 2; i++) {
                left[i] = samples[i * 2] / 32768.0;
                right[i] = samples[i * 2 + 1] / 32768.0;
            }
            const source = audioContext.createBufferSource();
            source.buffer = buffer;
            source.connect(gainNode);
            source.start();
        }

        function updateStatus(message) {
            statusEl.textContent = 'Status: ' + message;
        }
    </script>
</body>
</html>
EOF

# Create comprehensive noVNC home page with interface navigation
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
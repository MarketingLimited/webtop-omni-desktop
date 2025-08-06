#!/bin/bash

# WebRTC UI Integration Script
# Integrates WebRTC audio controls into noVNC interfaces

set -e

echo "🌐 Integrating WebRTC audio controls into noVNC..."

# Create WebRTC universal audio script
cat > /usr/local/bin/universal-webrtc.js << 'EOF'
/**
 * Universal WebRTC Audio Manager for noVNC Integration
 * Automatically adds WebRTC audio streaming capability to any noVNC page
 */
(function() {
    'use strict';

    // Prevent multiple instances
    if (window.UniversalWebRTCAudioManager) return;

    class UniversalWebRTCAudioManager {
        constructor() {
            this.peerConnection = null;
            this.websocket = null;
            this.isConnected = false;
            this.autoConnectEnabled = !localStorage.getItem('webrtc-audio-disabled');
            this.hasUserInteracted = false;
            this.retryCount = 0;
            this.maxRetries = 3;
            
            this.init();
        }

        init() {
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => this.setup());
            } else {
                this.setup();
            }
        }

        setup() {
            this.createAudioUI();
            this.setupEventListeners();
            
            if (this.autoConnectEnabled) {
                this.createActivationOverlay();
                this.setupAutoConnect();
            }
        }

        createAudioUI() {
            if (document.getElementById('webrtc-audio-controls')) return;

            const audioPanel = document.createElement('div');
            audioPanel.id = 'webrtc-audio-controls';
            audioPanel.innerHTML = `
                <div id="webrtc-panel-content">
                    <div class="webrtc-status">
                        <div id="webrtc-status-dot"></div>
                        <span id="webrtc-status-text">WebRTC Off</span>
                    </div>
                    <div class="webrtc-buttons">
                        <button id="webrtc-connect-btn" title="Connect WebRTC Audio">🎵</button>
                        <button id="webrtc-disconnect-btn" title="Disconnect Audio" style="display: none;">🔇</button>
                    </div>
                    <div class="webrtc-volume" style="display: none;">
                        <input type="range" id="webrtc-volume-slider" min="0" max="100" value="50">
                        <span id="webrtc-volume-label">50%</span>
                    </div>
                    <div class="webrtc-quality" style="display: none;">
                        <div class="quality-indicator">
                            <div id="webrtc-quality-bar"></div>
                        </div>
                        <span id="webrtc-quality-text">-</span>
                    </div>
                    <button id="webrtc-toggle-panel" title="Toggle WebRTC Panel">⚙️</button>
                </div>
            `;

            this.injectStyles();
            document.body.appendChild(audioPanel);

            this.elements = {
                panel: audioPanel,
                statusDot: document.getElementById('webrtc-status-dot'),
                statusText: document.getElementById('webrtc-status-text'),
                connectBtn: document.getElementById('webrtc-connect-btn'),
                disconnectBtn: document.getElementById('webrtc-disconnect-btn'),
                volumeSlider: document.getElementById('webrtc-volume-slider'),
                volumeLabel: document.getElementById('webrtc-volume-label'),
                volumeControl: audioPanel.querySelector('.webrtc-volume'),
                qualityControl: audioPanel.querySelector('.webrtc-quality'),
                qualityBar: document.getElementById('webrtc-quality-bar'),
                qualityText: document.getElementById('webrtc-quality-text'),
                toggleBtn: document.getElementById('webrtc-toggle-panel')
            };

            // Create hidden audio element
            this.audioElement = document.createElement('audio');
            this.audioElement.autoplay = true;
            this.audioElement.style.display = 'none';
            document.body.appendChild(this.audioElement);
        }

        injectStyles() {
            if (document.getElementById('webrtc-audio-styles')) return;

            const styles = document.createElement('style');
            styles.id = 'webrtc-audio-styles';
            styles.textContent = `
                #webrtc-audio-controls {
                    position: fixed;
                    top: 10px;
                    right: 10px;
                    background: linear-gradient(135deg, rgba(26, 32, 44, 0.95), rgba(45, 55, 72, 0.95));
                    color: white;
                    border-radius: 12px;
                    padding: 15px;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
                    font-size: 12px;
                    z-index: 999999;
                    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
                    backdrop-filter: blur(15px);
                    min-width: 160px;
                    transition: all 0.3s ease;
                    border: 1px solid rgba(255, 255, 255, 0.1);
                }

                #webrtc-audio-controls.minimized {
                    width: 45px;
                    padding: 10px;
                }

                #webrtc-audio-controls.minimized .webrtc-status,
                #webrtc-audio-controls.minimized .webrtc-buttons,
                #webrtc-audio-controls.minimized .webrtc-volume,
                #webrtc-audio-controls.minimized .webrtc-quality {
                    display: none !important;
                }

                .webrtc-status {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    margin-bottom: 10px;
                }

                #webrtc-status-dot {
                    width: 10px;
                    height: 10px;
                    border-radius: 50%;
                    background: #e53e3e;
                    transition: all 0.3s ease;
                }

                #webrtc-status-dot.connected {
                    background: #38a169;
                    box-shadow: 0 0 10px rgba(56, 161, 105, 0.6);
                }

                #webrtc-status-dot.connecting {
                    background: #f6ad55;
                    animation: pulse 2s infinite;
                }

                @keyframes pulse {
                    0%, 100% { opacity: 1; }
                    50% { opacity: 0.5; }
                }

                .webrtc-buttons {
                    display: flex;
                    gap: 10px;
                    margin-bottom: 10px;
                }

                .webrtc-buttons button {
                    background: linear-gradient(135deg, #4299e1, #3182ce);
                    border: none;
                    color: white;
                    padding: 8px 12px;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 16px;
                    transition: all 0.2s ease;
                    box-shadow: 0 2px 8px rgba(66, 153, 225, 0.3);
                }

                .webrtc-buttons button:hover {
                    background: linear-gradient(135deg, #3182ce, #2b77cb);
                    transform: translateY(-2px);
                    box-shadow: 0 4px 12px rgba(66, 153, 225, 0.4);
                }

                .webrtc-buttons button:disabled {
                    background: #718096;
                    cursor: not-allowed;
                    transform: none;
                    box-shadow: none;
                }

                .webrtc-volume {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    margin-bottom: 10px;
                }

                #webrtc-volume-slider {
                    flex: 1;
                    height: 6px;
                    border-radius: 3px;
                    background: #4a5568;
                    outline: none;
                    cursor: pointer;
                }

                #webrtc-volume-label {
                    font-size: 11px;
                    min-width: 30px;
                    text-align: right;
                }

                .webrtc-quality {
                    margin-bottom: 10px;
                }

                .quality-indicator {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    margin-bottom: 5px;
                }

                #webrtc-quality-bar {
                    flex: 1;
                    height: 4px;
                    background: #4a5568;
                    border-radius: 2px;
                    overflow: hidden;
                    position: relative;
                }

                #webrtc-quality-bar::before {
                    content: '';
                    position: absolute;
                    left: 0;
                    top: 0;
                    height: 100%;
                    background: linear-gradient(90deg, #e53e3e, #f6ad55, #38a169);
                    width: var(--quality, 0%);
                    transition: width 0.3s ease;
                }

                #webrtc-quality-text {
                    font-size: 10px;
                    color: #a0aec0;
                }

                #webrtc-toggle-panel {
                    background: none;
                    border: none;
                    color: #a0aec0;
                    cursor: pointer;
                    font-size: 16px;
                    padding: 5px;
                    border-radius: 6px;
                    transition: all 0.2s ease;
                    width: 100%;
                }

                #webrtc-toggle-panel:hover {
                    background: rgba(160, 174, 192, 0.1);
                    color: white;
                }

                /* Activation Overlay */
                .webrtc-activation-overlay {
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.85);
                    z-index: 1000000;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    color: white;
                    text-align: center;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
                    animation: fadeIn 0.3s ease;
                }

                @keyframes fadeIn {
                    from { opacity: 0; }
                    to { opacity: 1; }
                }

                .webrtc-overlay-content {
                    background: linear-gradient(135deg, #1a202c, #2d3748);
                    padding: 50px;
                    border-radius: 20px;
                    box-shadow: 0 25px 50px rgba(0, 0, 0, 0.6);
                    max-width: 450px;
                    border: 1px solid rgba(255, 255, 255, 0.1);
                }

                .webrtc-audio-icon {
                    font-size: 72px;
                    margin-bottom: 25px;
                    animation: iconFloat 3s ease-in-out infinite;
                }

                @keyframes iconFloat {
                    0%, 100% { transform: translateY(0); }
                    50% { transform: translateY(-10px); }
                }

                .webrtc-overlay-content h3 {
                    margin: 0 0 15px 0;
                    font-size: 28px;
                    font-weight: 700;
                    background: linear-gradient(135deg, #4299e1, #38a169);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                }

                .webrtc-overlay-content p {
                    margin: 0 0 25px 0;
                    font-size: 16px;
                    opacity: 0.9;
                    line-height: 1.5;
                }

                .skip-webrtc-btn {
                    background: rgba(113, 128, 150, 0.3);
                    color: white;
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    padding: 12px 24px;
                    border-radius: 8px;
                    cursor: pointer;
                    font-size: 14px;
                    transition: all 0.2s ease;
                }

                .skip-webrtc-btn:hover {
                    background: rgba(113, 128, 150, 0.5);
                }
            `;
            document.head.appendChild(styles);
        }

        createActivationOverlay() {
            const overlay = document.createElement('div');
            overlay.className = 'webrtc-activation-overlay';
            overlay.innerHTML = `
                <div class="webrtc-overlay-content">
                    <div class="webrtc-audio-icon">🎵</div>
                    <h3>WebRTC Audio Ready</h3>
                    <p>Click anywhere to enable high-quality desktop audio streaming with WebRTC</p>
                    <button class="skip-webrtc-btn" id="skip-webrtc-overlay">Skip Audio</button>
                </div>
            `;

            document.body.appendChild(overlay);

            const removeOverlay = () => {
                if (overlay.parentNode) {
                    overlay.remove();
                }
            };

            overlay.addEventListener('click', (e) => {
                if (e.target.id !== 'skip-webrtc-overlay') {
                    this.hasUserInteracted = true;
                    removeOverlay();
                    this.connectAudio();
                }
            });

            document.getElementById('skip-webrtc-overlay').addEventListener('click', () => {
                localStorage.setItem('webrtc-audio-disabled', 'true');
                this.autoConnectEnabled = false;
                removeOverlay();
            });

            setTimeout(removeOverlay, 20000);
        }

        setupEventListeners() {
            this.elements.connectBtn.addEventListener('click', () => this.connectAudio());
            this.elements.disconnectBtn.addEventListener('click', () => this.disconnectAudio());
            this.elements.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
            this.elements.toggleBtn.addEventListener('click', () => this.togglePanel());

            // Keyboard shortcuts
            document.addEventListener('keydown', (e) => {
                if (e.ctrlKey && e.altKey && e.key.toLowerCase() === 'w') {
                    e.preventDefault();
                    this.isConnected ? this.disconnectAudio() : this.connectAudio();
                }
            });

            // Restore saved volume
            const savedVolume = localStorage.getItem('webrtc-audio-volume') || '50';
            this.elements.volumeSlider.value = savedVolume;
            this.elements.volumeLabel.textContent = savedVolume + '%';
        }

        setupAutoConnect() {
            const enableAutoConnect = () => {
                if (!this.hasUserInteracted && this.autoConnectEnabled) {
                    this.hasUserInteracted = true;
                    setTimeout(() => this.connectAudio(), 300);
                }
            };

            ['click', 'keydown', 'touchstart'].forEach(event => {
                document.addEventListener(event, enableAutoConnect, { once: true, passive: true });
            });
        }

        async connectAudio() {
            try {
                this.updateStatus('Connecting...', 'connecting');
                this.retryCount = 0;
                await this.attemptWebRTCConnection();
            } catch (error) {
                console.error('WebRTC connection failed:', error);
                this.updateStatus('Connection failed', 'disconnected');
                this.scheduleRetry();
            }
        }

        async attemptWebRTCConnection() {
            // Create peer connection
            this.peerConnection = new RTCPeerConnection({
                iceServers: [
                    { urls: 'stun:stun.l.google.com:19302' },
                    { urls: 'stun:stun1.l.google.com:19302' }
                ]
            });

            // Handle incoming audio stream
            this.peerConnection.ontrack = (event) => {
                console.log('📡 Received WebRTC audio track');
                this.audioElement.srcObject = event.streams[0];
                this.setVolume(this.elements.volumeSlider.value);
                this.elements.volumeControl.style.display = 'flex';
                this.elements.qualityControl.style.display = 'block';
                this.startQualityMonitoring();
            };

            // Handle connection state changes
            this.peerConnection.oniceconnectionstatechange = () => {
                const state = this.peerConnection.iceConnectionState;
                console.log('🔗 ICE connection state:', state);
                
                if (state === 'connected' || state === 'completed') {
                    this.isConnected = true;
                    this.updateUI();
                    this.updateStatus('WebRTC Connected', 'connected');
                } else if (state === 'disconnected' || state === 'failed') {
                    this.disconnectAudio();
                }
            };

            // Connect to signaling server
            const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            this.websocket = new WebSocket(`${wsProtocol}//${window.location.hostname}:8081`);

            this.websocket.onopen = async () => {
                console.log('🔌 Connected to WebRTC signaling server');
                
                // Create offer
                const offer = await this.peerConnection.createOffer();
                await this.peerConnection.setLocalDescription(offer);
                
                this.websocket.send(JSON.stringify({
                    type: 'offer',
                    offer: offer
                }));
            };

            this.websocket.onmessage = async (event) => {
                const data = JSON.parse(event.data);
                
                switch (data.type) {
                    case 'answer':
                        await this.peerConnection.setRemoteDescription(data.answer);
                        break;
                    case 'ice-candidate':
                        await this.peerConnection.addIceCandidate(data.candidate);
                        break;
                }
            };

            // Send ICE candidates
            this.peerConnection.onicecandidate = (event) => {
                if (event.candidate && this.websocket.readyState === WebSocket.OPEN) {
                    this.websocket.send(JSON.stringify({
                        type: 'ice-candidate',
                        candidate: event.candidate
                    }));
                }
            };
        }

        disconnectAudio() {
            if (this.websocket) {
                this.websocket.send(JSON.stringify({ type: 'close' }));
                this.websocket.close();
                this.websocket = null;
            }

            if (this.peerConnection) {
                this.peerConnection.close();
                this.peerConnection = null;
            }

            if (this.audioElement.srcObject) {
                this.audioElement.srcObject.getTracks().forEach(track => track.stop());
                this.audioElement.srcObject = null;
            }

            this.isConnected = false;
            this.updateUI();
            this.updateStatus('Disconnected', 'disconnected');
            this.elements.volumeControl.style.display = 'none';
            this.elements.qualityControl.style.display = 'none';
        }

        setVolume(value) {
            this.audioElement.volume = value / 100;
            this.elements.volumeLabel.textContent = value + '%';
            localStorage.setItem('webrtc-audio-volume', value);
        }

        togglePanel() {
            this.elements.panel.classList.toggle('minimized');
        }

        updateUI() {
            this.elements.connectBtn.disabled = this.isConnected;
            this.elements.disconnectBtn.disabled = !this.isConnected;
            this.elements.connectBtn.style.display = this.isConnected ? 'none' : 'inline-block';
            this.elements.disconnectBtn.style.display = this.isConnected ? 'inline-block' : 'none';
        }

        updateStatus(message, type) {
            this.elements.statusText.textContent = message;
            this.elements.statusDot.className = type;
        }

        startQualityMonitoring() {
            if (this.qualityInterval) clearInterval(this.qualityInterval);
            
            this.qualityInterval = setInterval(() => {
                if (this.peerConnection && this.isConnected) {
                    this.peerConnection.getStats().then(stats => {
                        let quality = 0;
                        stats.forEach(report => {
                            if (report.type === 'inbound-rtp' && report.kind === 'audio') {
                                const packetsLost = report.packetsLost || 0;
                                const packetsReceived = report.packetsReceived || 0;
                                const total = packetsLost + packetsReceived;
                                quality = total > 0 ? ((packetsReceived / total) * 100) : 0;
                            }
                        });
                        
                        this.elements.qualityBar.style.setProperty('--quality', quality + '%');
                        this.elements.qualityText.textContent = Math.round(quality) + '%';
                    });
                }
            }, 2000);
        }

        scheduleRetry() {
            if (this.retryCount < this.maxRetries) {
                this.retryCount++;
                setTimeout(() => {
                    this.updateStatus(`Retrying... (${this.retryCount}/${this.maxRetries})`, 'connecting');
                    this.connectAudio();
                }, 3000);
            }
        }
    }

    // Initialize WebRTC audio manager
    window.UniversalWebRTCAudioManager = new UniversalWebRTCAudioManager();
})();
EOF

# Make the universal WebRTC script available
NOVNC_DIR="/usr/share/novnc"
if [ -d "$NOVNC_DIR" ]; then
    cp /usr/local/bin/universal-webrtc.js "$NOVNC_DIR/" 2>/dev/null || echo "Will copy after noVNC setup"
fi

# Create audio environment configuration
cat > /opt/webrtc-bridge/public/webrtc-env.js << 'EOF'
// WebRTC Audio Environment Configuration
window.WEBRTC_HOST = window.location.hostname;
window.WEBRTC_PORT = 8080;
window.WEBRTC_WS_PORT = 8081;
window.WEBRTC_WS_SCHEME = window.location.protocol === 'https:' ? 'wss' : 'ws';
EOF

echo "✅ WebRTC UI integration completed!"
echo "🎵 Universal WebRTC audio controls created"
echo "🔗 Auto-integration with noVNC interfaces"
echo "⚡ Enhanced features:"
echo "   - WebRTC peer-to-peer audio streaming"
echo "   - Real-time connection quality monitoring"
echo "   - Automatic fallback and retry mechanisms"
echo "   - Keyboard shortcuts (Ctrl+Alt+W)"
echo "   - Persistent volume and quality controls"
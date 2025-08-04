/**
 * Universal Audio Manager for noVNC Integration
 * Automatically adds audio streaming capability to any noVNC page
 */
(function() {
    'use strict';

    // Allow runtime override of audio service location
    const audioHost = window.AUDIO_HOST || window.location.hostname;
    const audioPort = window.AUDIO_PORT || 8080;

    // Prevent multiple instances
    if (window.UniversalAudioManager) return;

    class UniversalAudioManager {
        constructor() {
            this.audioContext = null;
            this.websocket = null;
            this.gainNode = null;
            this.isConnected = false;
            this.autoConnectEnabled = !localStorage.getItem('audio-disabled');
            this.hasUserInteracted = false;
            this.retryCount = 0;
            this.maxRetries = 3;
            
            this.init();
        }

        init() {
            // Wait for DOM to be ready
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

            this.checkAudioBridge();
        }

        createAudioUI() {
            // Check if audio UI already exists
            if (document.getElementById('universal-audio-controls')) return;

            // Create floating audio control panel
            const audioPanel = document.createElement('div');
            audioPanel.id = 'universal-audio-controls';
            audioPanel.innerHTML = `
                <div id="audio-panel-content">
                    <div class="audio-status">
                        <div id="audio-status-dot"></div>
                        <span id="audio-status-text">Audio Off</span>
                    </div>
                    <div class="audio-buttons">
                        <button id="audio-connect-btn" title="Connect Audio (Ctrl+Alt+A)">🔊</button>
                        <button id="audio-disconnect-btn" title="Disconnect Audio" style="display: none;">🔇</button>
                    </div>
                    <div class="audio-volume" style="display: none;">
                        <input type="range" id="audio-volume-slider" min="0" max="100" value="50">
                    </div>
                    <button id="audio-toggle-panel" title="Toggle Audio Panel">⚙️</button>
                </div>
            `;

            // Inject CSS styles
            this.injectStyles();
            document.body.appendChild(audioPanel);

            // Store element references
            this.elements = {
                panel: audioPanel,
                statusDot: document.getElementById('audio-status-dot'),
                statusText: document.getElementById('audio-status-text'),
                connectBtn: document.getElementById('audio-connect-btn'),
                disconnectBtn: document.getElementById('audio-disconnect-btn'),
                volumeSlider: document.getElementById('audio-volume-slider'),
                volumeControl: audioPanel.querySelector('.audio-volume'),
                toggleBtn: document.getElementById('audio-toggle-panel')
            };
        }

        injectStyles() {
            if (document.getElementById('universal-audio-styles')) return;

            const styles = document.createElement('style');
            styles.id = 'universal-audio-styles';
            styles.textContent = `
                #universal-audio-controls {
                    position: fixed;
                    top: 10px;
                    right: 10px;
                    background: rgba(26, 32, 44, 0.95);
                    color: white;
                    border-radius: 8px;
                    padding: 12px;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
                    font-size: 12px;
                    z-index: 999999;
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
                    backdrop-filter: blur(10px);
                    min-width: 150px;
                    transition: all 0.3s ease;
                }

                #universal-audio-controls.minimized {
                    width: 40px;
                    padding: 8px;
                }

                #universal-audio-controls.minimized .audio-status,
                #universal-audio-controls.minimized .audio-buttons,
                #universal-audio-controls.minimized .audio-volume {
                    display: none !important;
                }

                .audio-status {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    margin-bottom: 8px;
                }

                #audio-status-dot {
                    width: 8px;
                    height: 8px;
                    border-radius: 50%;
                    background: #e53e3e;
                    transition: background 0.3s ease;
                }

                #audio-status-dot.connected {
                    background: #38a169;
                    box-shadow: 0 0 8px rgba(56, 161, 105, 0.5);
                }

                .audio-buttons {
                    display: flex;
                    gap: 8px;
                    margin-bottom: 8px;
                }

                .audio-buttons button {
                    background: #4299e1;
                    border: none;
                    color: white;
                    padding: 6px 10px;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 14px;
                    transition: all 0.2s ease;
                }

                .audio-buttons button:hover {
                    background: #3182ce;
                    transform: translateY(-1px);
                }

                .audio-buttons button:disabled {
                    background: #718096;
                    cursor: not-allowed;
                    transform: none;
                }

                .audio-volume {
                    margin-bottom: 8px;
                }

                #audio-volume-slider {
                    width: 100%;
                    height: 4px;
                    border-radius: 2px;
                    background: #4a5568;
                    outline: none;
                    cursor: pointer;
                }

                #audio-toggle-panel {
                    background: none;
                    border: none;
                    color: #a0aec0;
                    cursor: pointer;
                    font-size: 14px;
                    padding: 4px;
                    border-radius: 4px;
                    transition: all 0.2s ease;
                    width: 100%;
                }

                #audio-toggle-panel:hover {
                    background: rgba(160, 174, 192, 0.1);
                    color: white;
                }

                /* Activation Overlay Styles */
                .audio-activation-overlay {
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.8);
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

                .overlay-content {
                    background: linear-gradient(135deg, #1a202c, #2d3748);
                    padding: 40px;
                    border-radius: 16px;
                    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
                    max-width: 400px;
                    border: 1px solid rgba(255, 255, 255, 0.1);
                }

                .audio-icon {
                    font-size: 64px;
                    margin-bottom: 20px;
                    animation: audioIconPulse 2s infinite;
                }

                @keyframes audioIconPulse {
                    0%, 100% { transform: scale(1); opacity: 0.8; }
                    50% { transform: scale(1.1); opacity: 1; }
                }

                .overlay-content h3 {
                    margin: 0 0 10px 0;
                    font-size: 24px;
                    font-weight: 600;
                }

                .overlay-content p {
                    margin: 0 0 20px 0;
                    font-size: 16px;
                    opacity: 0.9;
                }

                .skip-audio-btn {
                    background: rgba(113, 128, 150, 0.3);
                    color: white;
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    padding: 10px 20px;
                    border-radius: 8px;
                    cursor: pointer;
                    font-size: 14px;
                    transition: all 0.2s ease;
                }

                .skip-audio-btn:hover {
                    background: rgba(113, 128, 150, 0.5);
                }
            `;
            document.head.appendChild(styles);
        }

        createActivationOverlay() {
            const overlay = document.createElement('div');
            overlay.className = 'audio-activation-overlay';
            overlay.innerHTML = `
                <div class="overlay-content">
                    <div class="audio-icon">🔊</div>
                    <h3>Audio Available</h3>
                    <p>Click anywhere to enable desktop audio streaming</p>
                    <button class="skip-audio-btn" id="skip-audio-overlay">Skip Audio</button>
                </div>
            `;

            document.body.appendChild(overlay);

            // Handle interactions
            const removeOverlay = () => {
                if (overlay.parentNode) {
                    overlay.remove();
                }
            };

            overlay.addEventListener('click', (e) => {
                if (e.target.id !== 'skip-audio-overlay') {
                    this.hasUserInteracted = true;
                    removeOverlay();
                    this.connectAudio();
                }
            });

            document.getElementById('skip-audio-overlay').addEventListener('click', () => {
                localStorage.setItem('audio-disabled', 'true');
                this.autoConnectEnabled = false;
                removeOverlay();
            });

            // Auto-remove after 15 seconds
            setTimeout(removeOverlay, 15000);
        }

        setupEventListeners() {
            // Audio control buttons
            this.elements.connectBtn.addEventListener('click', () => this.connectAudio());
            this.elements.disconnectBtn.addEventListener('click', () => this.disconnectAudio());
            this.elements.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
            this.elements.toggleBtn.addEventListener('click', () => this.togglePanel());

            // Keyboard shortcuts
            document.addEventListener('keydown', (e) => {
                if (e.ctrlKey && e.altKey && e.key.toLowerCase() === 'a') {
                    e.preventDefault();
                    this.isConnected ? this.disconnectAudio() : this.connectAudio();
                }
            });

            // Restore saved volume
            const savedVolume = localStorage.getItem('audio-volume') || '50';
            this.elements.volumeSlider.value = savedVolume;
        }

        setupAutoConnect() {
            const enableAutoConnect = () => {
                if (!this.hasUserInteracted && this.autoConnectEnabled) {
                    this.hasUserInteracted = true;
                    setTimeout(() => this.connectAudio(), 200);
                }
            };

            ['click', 'keydown', 'touchstart'].forEach(event => {
                document.addEventListener(event, enableAutoConnect, { once: true, passive: true });
            });
        }

        async checkAudioBridge() {
            try {
                // Test multiple potential audio bridge endpoints
                const endpoints = [
                    '/audio-player.html',
                    `http://${audioHost}:${audioPort}`,
                    '/health'
                ];

                for (const endpoint of endpoints) {
                    try {
                        const response = await fetch(endpoint, { method: 'HEAD', timeout: 2000 });
                        if (response.ok) {
                            this.updateStatus('Audio bridge ready', 'ready');
                            return;
                        }
                    } catch (e) {
                        // Continue to next endpoint
                    }
                }
                
                this.updateStatus('Audio bridge unavailable', 'error');
            } catch (error) {
                this.updateStatus('Audio check failed', 'error');
            }
        }

        async connectAudio() {
            try {
                this.updateStatus('Connecting...', 'connecting');
                this.retryCount = 0;

                // Initialize or resume audio context
                if (!this.audioContext) {
                    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    this.gainNode = this.audioContext.createGain();
                    this.gainNode.connect(this.audioContext.destination);
                    
                    const savedVolume = localStorage.getItem('audio-volume') || '50';
                    this.setVolume(savedVolume);
                }

                if (this.audioContext.state === 'suspended') {
                    await this.audioContext.resume();
                }

                await this.attemptConnection();
                
            } catch (error) {
                console.error('Audio connection failed:', error);
                this.updateStatus('Connection failed', 'error');
                this.scheduleRetry();
            }
        }

        async attemptConnection() {
            const wsProtocol = window.AUDIO_WS_SCHEME || (window.location.protocol === 'https:' ? 'wss' : 'ws');
            const wsUrls = [
                `${wsProtocol}://${audioHost}:${audioPort}`,
                `${wsProtocol}://${window.location.host}/audio-bridge`
            ];

            for (const wsUrl of wsUrls) {
                try {
                    await this.connectWebSocket(wsUrl);
                    return; // Success
                } catch (error) {
                    console.warn(`Failed to connect to ${wsUrl}:`, error.message);
                }
            }
            
            throw new Error('All connection attempts failed');
        }

        async connectWebSocket(wsUrl) {
            return new Promise((resolve, reject) => {
                const ws = new WebSocket(wsUrl);
                ws.binaryType = 'arraybuffer';
                
                const timeout = setTimeout(() => {
                    ws.close();
                    reject(new Error('Connection timeout'));
                }, 3000);

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
                    if (this.isConnected) {
                        this.isConnected = false;
                        this.updateUI();
                        this.updateStatus('Audio disconnected', 'disconnected');
                    }
                };

                ws.onerror = (error) => {
                    clearTimeout(timeout);
                    reject(new Error('WebSocket error'));
                };
            });
        }

        disconnectAudio() {
            if (this.websocket) {
                this.websocket.close();
                this.websocket = null;
            }
            this.isConnected = false;
            this.updateUI();
            this.updateStatus('Audio disconnected', 'disconnected');
        }

        processAudioData(data) {
            if (!this.audioContext || !this.gainNode || this.audioContext.state === 'closed') return;

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

        setVolume(value) {
            if (this.gainNode) {
                this.gainNode.gain.value = value / 100;
            }
            localStorage.setItem('audio-volume', value);
        }

        updateUI() {
            this.elements.connectBtn.style.display = this.isConnected ? 'none' : 'inline-block';
            this.elements.disconnectBtn.style.display = this.isConnected ? 'inline-block' : 'none';
            this.elements.volumeControl.style.display = this.isConnected ? 'block' : 'none';
        }

        updateStatus(message, type) {
            this.elements.statusText.textContent = message;
            this.elements.statusDot.className = type === 'connected' ? 'connected' : '';
        }

        togglePanel() {
            this.elements.panel.classList.toggle('minimized');
        }

        scheduleRetry() {
            if (this.retryCount < this.maxRetries && this.autoConnectEnabled) {
                this.retryCount++;
                const delay = Math.min(1000 * Math.pow(2, this.retryCount), 10000);
                setTimeout(() => this.connectAudio(), delay);
            }
        }
    }

    // Initialize Universal Audio Manager
    window.UniversalAudioManager = new UniversalAudioManager();

})();
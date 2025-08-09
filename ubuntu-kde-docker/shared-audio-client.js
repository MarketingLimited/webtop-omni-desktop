/**
 * Shared Audio Client Library
 * WebRTC-first with WebSocket fallback for Ubuntu KDE WebTop
 */
class SharedAudioClient {
    constructor(options = {}) {
        this.audioHost = options.audioHost || window.AUDIO_HOST || window.location.hostname;
        this.audioPort =
            options.audioPort !== undefined ? options.audioPort :
            (typeof window.AUDIO_PORT !== 'undefined' ? window.AUDIO_PORT : 8080);
        this.webrtcPort =
            options.webrtcPort !== undefined ? options.webrtcPort :
            (typeof window.WEBRTC_PORT !== 'undefined' ? window.WEBRTC_PORT : this.audioPort);
        this.wsScheme = options.wsScheme || window.AUDIO_WS_SCHEME || (window.location.protocol === 'https:' ? 'wss' : 'ws');

        const fallbackConfig = options.enableWebSocketFallback ?? window.ENABLE_WEBSOCKET_FALLBACK;
        this.enableWebSocketFallback =
            typeof fallbackConfig === 'undefined' ? true : String(fallbackConfig).toLowerCase() !== 'false';
        
        this.audioContext = null;
        this.websocket = null;
        this.signalSocket = null;
        this.peerConnection = null;
        this.gainNode = null;
        this.isConnected = false;
        this.currentMethod = null;
        this.retryCount = 0;
        this.maxRetries = 3;
        this.statusHandlers = [];

        this.turnWarningLogged = false;
        
        this.debugMode = options.debug || false;
        
        this.log('SharedAudioClient initialized', {
            audioHost: this.audioHost,
            audioPort: this.audioPort,
            webrtcPort: this.webrtcPort,
            wsScheme: this.wsScheme,
            enableWebSocketFallback: this.enableWebSocketFallback
        });
    }
    
    log(message, data = null) {
        if (this.debugMode) {
            console.log(`[SharedAudioClient] ${message}`, data || '');
        }
    }
    
    onStatusChange(handler) {
        this.statusHandlers.push(handler);
    }
    
    updateStatus(message, state, method = null) {
        this.currentMethod = method;
        this.statusHandlers.forEach(handler => {
            try {
                handler({ message, state, method });
            } catch (e) {
                console.warn('Status handler error:', e);
            }
        });
        
        this.log(`Status: ${message} (${state}, method: ${method})`);
    }
    
    getIceServers() {
        const servers = [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' }
        ];
        
        if (window.WEBRTC_STUN_SERVER) {
            servers.push({ urls: window.WEBRTC_STUN_SERVER });
        }

        if (window.WEBRTC_TURN_SERVER) {
            let turnUrl = window.WEBRTC_TURN_SERVER;
            const host = window.location.hostname;
            if (turnUrl.includes('localhost') || turnUrl.includes('127.0.0.1')) {
                turnUrl = turnUrl.replace('localhost', host).replace('127.0.0.1', host);
            }
            servers.push({
                urls: turnUrl,
                username: window.WEBRTC_TURN_USERNAME || undefined,
                credential: window.WEBRTC_TURN_PASSWORD || undefined
            });
        } else if (!this.turnWarningLogged) {
            console.warn('WEBRTC_TURN_SERVER is not set; WebRTC may fail behind restrictive networks');
            this.turnWarningLogged = true;
        }
        
        this.log('ICE servers configured', servers);
        return servers;
    }
    
    async connect() {
        try {
            this.updateStatus('Connecting...', 'connecting');
            this.retryCount = 0;
            
            // Initialize or resume audio context
            if (!this.audioContext) {
                this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                this.gainNode = this.audioContext.createGain();
                this.gainNode.connect(this.audioContext.destination);
                
                // Restore saved volume
                const savedVolume = localStorage.getItem('audio-volume') || '50';
                this.setVolume(savedVolume);
                
                this.log('AudioContext created', {
                    sampleRate: this.audioContext.sampleRate,
                    state: this.audioContext.state
                });
            }
            
            if (this.audioContext.state === 'suspended') {
                await this.audioContext.resume();
                this.log('AudioContext resumed');
            }
            
            // Try WebRTC first
            try {
                await this.connectWebRTC();
                this.isConnected = true;
                this.updateStatus('Connected via WebRTC', 'connected', 'webrtc');
                return;
            } catch (err) {
                this.log('WebRTC failed', err.message);
                if (!this.enableWebSocketFallback) {
                    throw err;
                }
                this.log('Falling back to WebSocket', err.message);
            }

            if (this.enableWebSocketFallback) {
                // WebSocket fallback
                await this.connectWebSocket();
                this.isConnected = true;
                this.updateStatus('Connected via WebSocket', 'connected', 'websocket');
            }
            
        } catch (error) {
            this.log('Connection failed', error.message);
            this.updateStatus(`Connection failed: ${error.message}`, 'error');
            this.scheduleRetry();
        }
    }
    
    async connectWebRTC() {
        this.log('Attempting WebRTC connection...');
        
        const pc = new RTCPeerConnection({ iceServers: this.getIceServers() });
        this.peerConnection = pc;

        // Try multiple signaling URLs for ICE candidates
        const signalPort = this.webrtcPort ? `:${this.webrtcPort}` : '';
        const signalUrls = [
            `${this.wsScheme}://${this.audioHost}${signalPort}/webrtc`,
            `${this.wsScheme}://${window.location.host}/webrtc` // Same-origin fallback
        ];

        let signalSocket = null;
        for (const url of signalUrls) {
            try {
                this.log(`Trying signaling URL: ${url}`);
                signalSocket = await new Promise((resolve, reject) => {
                    const socket = new WebSocket(url);
                    const timer = setTimeout(() => {
                        socket.close();
                        reject(new Error('Signaling connection timeout'));
                    }, 5000);

                    socket.onopen = () => {
                        clearTimeout(timer);
                        resolve(socket);
                    };

                    socket.onerror = () => {
                        clearTimeout(timer);
                        reject(new Error('Signaling connection failed'));
                    };
                });
                this.log(`Signaling connected via: ${url}`);
                break;
            } catch (e) {
                this.log(`Signaling failed for ${url}:`, e.message);
            }
        }

        if (!signalSocket) {
            throw new Error('All signaling connection attempts failed');
        }

        this.signalSocket = signalSocket;

        // Forward local ICE candidates to server
        pc.onicecandidate = (event) => {
            if (signalSocket.readyState === WebSocket.OPEN) {
                try {
                    signalSocket.send(JSON.stringify({ type: 'candidate', candidate: event.candidate }));
                } catch (e) {
                    this.log('Failed to send ICE candidate', e.message);
                }
            }
        };

        // Apply remote ICE candidates from server
        signalSocket.onmessage = async (event) => {
            try {
                const data = JSON.parse(event.data);
                if (data.type === 'candidate') {
                    await pc.addIceCandidate(data.candidate || null);
                }
            } catch (e) {
                this.log('Failed to handle remote candidate', e.message);
            }
        };

        // CRITICAL: Add receiving transceiver before creating offer
        pc.addTransceiver('audio', { direction: 'recvonly' });
        this.log('Added recvonly audio transceiver');
        
        pc.ontrack = (event) => {
            this.log('WebRTC track received', {
                streams: event.streams.length,
                tracks: event.streams[0]?.getTracks().length
            });

            try {
                const stream = event.streams[0] || new MediaStream([event.track]);
                const source = this.audioContext.createMediaStreamSource(stream);
                source.connect(this.gainNode);
                this.log('WebRTC audio source connected to gain node');
            } catch (e) {
                this.log('Failed to connect WebRTC stream', e.message);
            }
        };
        
        pc.onconnectionstatechange = () => {
            this.log('WebRTC connection state changed', pc.connectionState);
        };
        
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        this.log('WebRTC offer created');
        
        // Try multiple offer endpoints
        const offerPort = this.webrtcPort ? `:${this.webrtcPort}` : '';
        const offerUrls = [
            `http://${this.audioHost}${offerPort}/offer`,
            `/offer` // Same-origin fallback if proxied
        ];
        
        let response = null;
        for (const url of offerUrls) {
            try {
                this.log(`Trying WebRTC offer endpoint: ${url}`);
                response = await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(offer)
                });
                
                if (response.ok) {
                    this.log(`WebRTC offer successful via: ${url}`);
                    break;
                }
            } catch (e) {
                this.log(`WebRTC offer failed for ${url}:`, e.message);
            }
        }
        
        if (!response || !response.ok) {
            throw new Error('All WebRTC offer endpoints failed');
        }
        
        const answer = await response.json();
        await pc.setRemoteDescription(answer);
        this.log('WebRTC answer processed');

        // Wait for connection with timeout and monitor signaling socket
        await new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                cleanup();
                reject(new Error('WebRTC connection timeout'));
            }, 10000);

            const cleanup = () => {
                clearTimeout(timeout);
                pc.onconnectionstatechange = null;
                signalSocket.onerror = null;
                signalSocket.onclose = null;
            };

            const fail = (msg) => {
                if (pc.connectionState !== 'connected') {
                    cleanup();
                    reject(new Error(msg));
                }
            };

            signalSocket.onerror = () => fail('Signaling socket error');
            signalSocket.onclose = () => fail('Signaling socket closed');

            pc.onconnectionstatechange = () => {
                this.log('WebRTC connection state changed', pc.connectionState);
                if (pc.connectionState === 'connected') {
                    cleanup();
                    this.log('WebRTC connection established');
                    resolve();
                } else if (['failed', 'disconnected', 'closed'].includes(pc.connectionState)) {
                    cleanup();
                    reject(new Error(`WebRTC connection ${pc.connectionState}`));
                }
            };
        });
    }
    
    async connectWebSocket() {
        this.log('Attempting WebSocket connection...');
        
        // Try multiple WebSocket URLs
        const wsPort = this.audioPort ? `:${this.audioPort}` : '';
        const wsUrls = [
            `${this.wsScheme}://${this.audioHost}${wsPort}/audio-stream`,
            `${this.wsScheme}://${window.location.host}/audio-stream` // Same-origin fallback
        ];
        
        for (const wsUrl of wsUrls) {
            try {
                this.log(`Trying WebSocket URL: ${wsUrl}`);
                await this.connectWebSocketUrl(wsUrl);
                this.log(`WebSocket connected via: ${wsUrl}`);
                return;
            } catch (e) {
                this.log(`WebSocket failed for ${wsUrl}:`, e.message);
            }
        }
        
        throw new Error('All WebSocket connection attempts failed');
    }
    
    async connectWebSocketUrl(wsUrl) {
        return new Promise((resolve, reject) => {
            const ws = new WebSocket(wsUrl);
            ws.binaryType = 'arraybuffer';

            const timeout = setTimeout(() => {
                ws.close();
                reject(new Error('WebSocket timeout'));
            }, 5000);

            let handshakeDone = false;

            ws.onopen = () => {
                this.log('WebSocket opened, awaiting handshake');
            };

            ws.onmessage = (event) => {
                if (!handshakeDone) {
                    try {
                        const msg = JSON.parse(event.data);
                        if (msg.type === 'connected') {
                            handshakeDone = true;
                            clearTimeout(timeout);
                            this.websocket = ws;
                            resolve();
                            return;
                        }
                    } catch (_) { /* not JSON */ }
                    clearTimeout(timeout);
                    ws.close();
                    reject(new Error('WebSocket handshake failed'));
                    return;
                }

                if (typeof event.data === 'string') {
                    // Control message
                    this.log('WebSocket control message:', event.data);
                    return;
                }
                this.processAudioData(event.data);
            };

            ws.onclose = () => {
                clearTimeout(timeout);
                if (this.isConnected) {
                    this.isConnected = false;
                    this.updateStatus('Connection lost', 'disconnected');
                    this.scheduleRetry();
                }
                this.log('WebSocket closed');
            };

            ws.onerror = (error) => {
                clearTimeout(timeout);
                this.log('WebSocket error:', error);
                reject(new Error('WebSocket connection error'));
            };
        });
    }
    
    processAudioData(data) {
        if (!this.audioContext || !this.gainNode || this.audioContext.state === 'closed') {
            return;
        }
        
        try {
            // Resume context if suspended (Chrome autoplay policy)
            if (this.audioContext.state === 'suspended') {
                this.audioContext.resume().catch(e => 
                    this.log('Could not resume audio context:', e.message)
                );
                return; // Skip this frame
            }
            
            const samples = new Int16Array(data);
            if (samples.length === 0 || samples.length % 2 !== 0) {
                this.log('Invalid audio data length:', samples.length);
                return;
            }
            
            const frameLength = samples.length / 2;
            const audioBuffer = this.audioContext.createBuffer(2, frameLength, 48000);
            
            const leftChannel = audioBuffer.getChannelData(0);
            const rightChannel = audioBuffer.getChannelData(1);
            
            // Convert 16-bit PCM to float with proper range checking
            for (let i = 0; i < frameLength; i++) {
                const leftSample = samples[i * 2];
                const rightSample = samples[i * 2 + 1];
                
                leftChannel[i] = Math.max(-1, Math.min(1, leftSample / 32768.0));
                rightChannel[i] = Math.max(-1, Math.min(1, rightSample / 32768.0));
            }
            
            const source = this.audioContext.createBufferSource();
            source.buffer = audioBuffer;
            source.connect(this.gainNode);
            
            // Schedule playback with small buffer to prevent gaps
            const playTime = Math.max(this.audioContext.currentTime, this.lastPlayTime || 0);
            source.start(playTime);
            this.lastPlayTime = playTime + (frameLength / 48000);
            
            // Clean up source after playback
            setTimeout(() => {
                try {
                    source.disconnect();
                } catch (e) {
                    // Source already disconnected
                }
            }, (frameLength / 48000) * 1000 + 100);
            
        } catch (error) {
            this.log('Audio processing error:', error.message);
            
            // Attempt recovery if context is in error state
            if (this.audioContext && this.audioContext.state === 'closed') {
                this.log('AudioContext closed, attempting reconnection...');
                this.disconnect();
                setTimeout(() => this.connect(), 1000);
            }
        }
    }
    
    disconnect() {
        this.log('Disconnecting audio...');
        
        if (this.websocket) {
            this.websocket.close();
            this.websocket = null;
        }

        if (this.signalSocket) {
            this.signalSocket.close();
            this.signalSocket = null;
        }

        if (this.peerConnection) {
            this.peerConnection.close();
            this.peerConnection = null;
        }
        
        if (this.audioContext && this.audioContext.state !== 'closed') {
            this.audioContext.close().then(() => {
                this.audioContext = null;
                this.gainNode = null;
                this.log('AudioContext closed');
            }).catch(e => {
                this.log('Error closing AudioContext:', e.message);
            });
        }
        
        this.isConnected = false;
        this.currentMethod = null;
        this.lastPlayTime = null;
        this.updateStatus('Audio disconnected', 'disconnected');
    }
    
    setVolume(value) {
        if (this.gainNode) {
            this.gainNode.gain.value = value / 100;
        }
        localStorage.setItem('audio-volume', value);
        this.log(`Volume set to ${value}%`);
    }
    
    scheduleRetry() {
        if (this.retryCount < this.maxRetries) {
            this.retryCount++;
            const delay = Math.min(1000 * Math.pow(2, this.retryCount), 10000);
            this.log(`Scheduling retry ${this.retryCount}/${this.maxRetries} in ${delay}ms`);
            
            setTimeout(() => {
                if (!this.isConnected) {
                    this.connect();
                }
            }, delay);
        } else {
            this.log('Max retries reached, giving up');
            this.updateStatus('Connection failed (max retries)', 'error');
        }
    }
    
    getStatus() {
        return {
            isConnected: this.isConnected,
            method: this.currentMethod,
            audioContextState: this.audioContext?.state || 'none',
            retryCount: this.retryCount
        };
    }
}

// Export for use in different environments
if (typeof module !== 'undefined' && module.exports) {
    module.exports = SharedAudioClient;
} else {
    window.SharedAudioClient = SharedAudioClient;
}
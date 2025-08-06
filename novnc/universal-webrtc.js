
// universal-webrtc.js
// This script handles WebRTC audio streaming for noVNC.

(function() {
    console.log('Universal WebRTC Audio Manager initializing...');

    // Configuration from audio-env.js
    const AUDIO_HOST = window.AUDIO_HOST || window.location.hostname;
    const AUDIO_PORT = window.AUDIO_PORT || 8080; // Default to 8080 if not set
    const AUDIO_WS_SCHEME = window.AUDIO_WS_SCHEME || (window.location.protocol === 'https:' ? 'wss:' : 'ws:');

    const WEBRTC_SIGNALING_SERVER = `${AUDIO_WS_SCHEME}//${AUDIO_HOST}:${AUDIO_PORT}/webrtc`;

    let peerConnection = null;
    let audioStream = null;
    let audioContext = null;
    let gainNode = null;

    const webrtcAudioContainer = document.getElementById('webrtc-audio-container');
    const connectionStatusElem = document.getElementById('connection-status');
    const audioQualityElem = document.getElementById('audio-quality');
    const latencyElem = document.getElementById('latency');
    const bitrateElem = document.getElementById('bitrate');

    function updateStatus(status, quality = '-', latency = '-', bitrate = '-') {
        if (connectionStatusElem) connectionStatusElem.textContent = status;
        if (audioQualityElem) audioQualityElem.textContent = quality;
        if (latencyElem) latencyElem.textContent = latency;
        if (bitrateElem) bitrateElem.textContent = bitrate;

        if (connectionStatusElem) {
            connectionStatusElem.style.color = (status === 'Connected') ? '#10b981' : '#ef4444';
        }
    }

    function createAudioControls() {
        if (!webrtcAudioContainer) return;

        webrtcAudioContainer.innerHTML = `
            <div style="margin-top: 1.5rem;">
                <button id="connectAudioBtn" class="test-button">Connect Audio</button>
                <button id="disconnectAudioBtn" class="test-button" disabled>Disconnect Audio</button>
                <div style="margin-top: 1rem;">
                    <label for="volumeControl">Volume:</label>
                    <input type="range" id="volumeControl" min="0" max="1" step="0.01" value="0.75" style="width: 80%;">
                </div>
            </div>
        `;

        document.getElementById('connectAudioBtn').onclick = connectAudio;
        document.getElementById('disconnectAudioBtn').onclick = disconnectAudio;
        document.getElementById('volumeControl').oninput = (e) => {
            if (gainNode) {
                gainNode.gain.value = parseFloat(e.target.value);
            }
        };
    }

    async function connectAudio() {
        updateStatus('Connecting...');
        document.getElementById('connectAudioBtn').disabled = true;
        document.getElementById('disconnectAudioBtn').disabled = false;

        try {
            // Create Peer Connection
            peerConnection = new RTCPeerConnection({
                iceServers: [
                    { urls: 'stun:stun.l.google.com:19302' },
                    { urls: 'stun:stun1.l.google.com:19302' }
                ]
            });

            peerConnection.onicecandidate = (event) => {
                if (event.candidate) {
                    // Send ICE candidate to signaling server
                    sendSignalingMessage({ 'ice-candidate': event.candidate });
                }
            };

            peerConnection.ontrack = (event) => {
                if (event.streams && event.streams[0]) {
                    audioStream = event.streams[0];
                    const audioEl = new Audio();
                    audioEl.srcObject = audioStream;
                    audioEl.autoplay = true;
                    audioEl.controls = false; // Hide default controls

                    // Connect to AudioContext for volume control
                    audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    const source = audioContext.createMediaStreamSource(audioStream);
                    gainNode = audioContext.createGain();
                    source.connect(gainNode);
                    gainNode.connect(audioContext.destination);
                    gainNode.gain.value = parseFloat(document.getElementById('volumeControl').value);

                    console.log('Audio stream received and playing.');
                    updateStatus('Connected', 'Good');
                }
            };

            peerConnection.onconnectionstatechange = () => {
                console.log('WebRTC connection state:', peerConnection.connectionState);
                if (peerConnection.connectionState === 'disconnected' || peerConnection.connectionState === 'failed' || peerConnection.connectionState === 'closed') {
                    disconnectAudio();
                    updateStatus('Disconnected');
                } else if (peerConnection.connectionState === 'connected') {
                    updateStatus('Connected', 'Good');
                }
            };

            // Create offer
            const offer = await peerConnection.createOffer();
            await peerConnection.setLocalDescription(offer);

            // Send offer to signaling server
            sendSignalingMessage({ 'sdp-offer': offer });

        } catch (error) {
            console.error('Error connecting audio:', error);
            updateStatus('Failed');
            document.getElementById('connectAudioBtn').disabled = false;
            document.getElementById('disconnectAudioBtn').disabled = true;
        }
    }

    function disconnectAudio() {
        if (peerConnection) {
            peerConnection.close();
            peerConnection = null;
        }
        if (audioStream) {
            audioStream.getTracks().forEach(track => track.stop());
            audioStream = null;
        }
        if (audioContext) {
            audioContext.close();
            audioContext = null;
            gainNode = null;
        }
        updateStatus('Disconnected');
        document.getElementById('connectAudioBtn').disabled = false;
        document.getElementById('disconnectAudioBtn').disabled = true;
        console.log('Audio disconnected.');
    }

    // Basic WebSocket signaling (replace with a robust solution)
    let ws = null;

    function connectSignaling() {
        if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
            return;
        }
        ws = new WebSocket(WEBRTC_SIGNALING_SERVER);

        ws.onopen = () => {
            console.log('Signaling WebSocket connected.');
        };

        ws.onmessage = async (event) => {
            const message = JSON.parse(event.data);
            if (message['sdp-answer']) {
                await peerConnection.setRemoteDescription(new RTCSessionDescription(message['sdp-answer']));
            } else if (message['ice-candidate']) {
                await peerConnection.addIceCandidate(new RTCIceCandidate(message['ice-candidate']));
            }
        };

        ws.onclose = () => {
            console.log('Signaling WebSocket disconnected. Attempting to reconnect...');
            setTimeout(connectSignaling, 3000); // Reconnect after 3 seconds
        };

        ws.onerror = (error) => {
            console.error('Signaling WebSocket error:', error);
            ws.close();
        };
    }

    function sendSignalingMessage(message) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(message));
        } else {
            console.warn('Signaling WebSocket not open. Message not sent:', message);
        }
    }

    // Expose functions globally for button clicks in vnc-audio.html
    window.connectAudio = connectAudio;
    window.disconnectAudio = disconnectAudio;
    window.testAudioPipeline = () => console.log('Test Audio Pipeline clicked (implementation needed)');
    window.testWebRTCConnection = () => console.log('Test WebRTC Connection clicked (implementation needed)');
    window.showDiagnostics = () => console.log('Show Diagnostics clicked (implementation needed)');

    // Initialize on DOMContentLoaded
    document.addEventListener('DOMContentLoaded', () => {
        createAudioControls();
        connectSignaling(); // Start signaling connection
        updateStatus('Disconnected'); // Initial status
    });

    // Simple connection test for the main page (index.html)
    if (window.location.pathname === '/' || window.location.pathname.includes('index.html')) {
        function testMainConnection() {
            fetch('/package.json')
                .then(response => {
                    const dot = document.querySelector('.status-dot');
                    const indicator = document.querySelector('.status-indicator');
                    if (dot && indicator) {
                        if (response.ok) {
                            dot.style.background = '#4ade80';
                            indicator.innerHTML = '<span class="status-dot"></span>System Online';
                        } else {
                            dot.style.background = '#ef4444';
                            indicator.innerHTML = '<span class="status-dot"></span>Connection Issues';
                        }
                    }
                })
                .catch(() => {
                    const dot = document.querySelector('.status-dot');
                    const indicator = document.querySelector('.status-indicator');
                    if (dot && indicator) {
                        dot.style.background = '#ef4444';
                        indicator.innerHTML = '<span class="status-dot"></span>Connection Issues';
                    }
                });
        }
        testMainConnection();
        setInterval(testMainConnection, 30000);
    }

})();

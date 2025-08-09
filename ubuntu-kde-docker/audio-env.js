// Audio environment configuration
// Generated for development
console.log('Loading audio environment configuration...');

window.AUDIO_HOST = '';
window.AUDIO_PORT = window.location.port;
window.AUDIO_WS_SCHEME = '';
window.ENABLE_WEBSOCKET_FALLBACK = true;

// WebRTC configuration
window.WEBRTC_PORT = window.location.port;
window.WEBRTC_STUN_SERVER = '';
window.WEBRTC_TURN_SERVER = '';
window.WEBRTC_TURN_USERNAME = '';
window.WEBRTC_TURN_PASSWORD = '';

// Debug information
console.log('Audio configuration:', {
    host: window.AUDIO_HOST,
    port: window.AUDIO_PORT,
    scheme: window.AUDIO_WS_SCHEME,
    enableWebSocketFallback: window.ENABLE_WEBSOCKET_FALLBACK,
    webrtcPort: window.WEBRTC_PORT,
    stunServer: window.WEBRTC_STUN_SERVER,
    turnServer: window.WEBRTC_TURN_SERVER
});

// Validate configuration
if (!window.AUDIO_PORT || window.AUDIO_PORT < 1 || window.AUDIO_PORT > 65535) {
    console.warn('Invalid audio port configuration:', window.AUDIO_PORT);
}


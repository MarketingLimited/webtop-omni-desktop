window.AUDIO_HOST = window.AUDIO_HOST || window.location.hostname;
window.AUDIO_PORT = window.AUDIO_PORT || 8080;
window.AUDIO_WS_SCHEME = window.AUDIO_WS_SCHEME || (window.location.protocol === 'https:' ? 'wss' : 'ws');

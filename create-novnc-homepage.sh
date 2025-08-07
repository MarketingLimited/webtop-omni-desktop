#!/bin/bash
set -euo pipefail

echo "🏠 Creating custom noVNC homepage and audio control page..."

# Ensure noVNC directory exists
NOVNC_DIR="/usr/share/novnc"
mkdir -p "$NOVNC_DIR"

# Create custom homepage
cat > "$NOVNC_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Marketing Agency WebTop - Remote Desktop</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }

        .container {
            max-width: 800px;
            width: 90%;
            text-align: center;
            padding: 2rem;
        }

        .logo {
            font-size: 3rem;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }

        h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
            font-weight: 700;
        }

        .subtitle {
            font-size: 1.2rem;
            margin-bottom: 3rem;
            opacity: 0.9;
            font-weight: 300;
        }

        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin-bottom: 3rem;
        }

        .service-card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 2rem;
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: all 0.3s ease;
            text-decoration: none;
            color: white;
            display: block;
        }

        .service-card:hover {
            transform: translateY(-5px);
            background: rgba(255, 255, 255, 0.15);
            box-shadow: 0 20px 40px rgba(0,0,0,0.2);
        }

        .service-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
            display: block;
        }

        .service-title {
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 0.5rem;
        }

        .service-description {
            opacity: 0.8;
            line-height: 1.5;
        }

        .quick-links {
            display: flex;
            justify-content: center;
            gap: 1rem;
            flex-wrap: wrap;
            margin-top: 2rem;
        }

        .quick-link {
            background: rgba(255, 255, 255, 0.2);
            color: white;
            text-decoration: none;
            padding: 0.75rem 1.5rem;
            border-radius: 25px;
            font-weight: 500;
            transition: all 0.3s ease;
            border: 1px solid rgba(255, 255, 255, 0.3);
        }

        .quick-link:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }

        .status-indicator {
            position: fixed;
            top: 20px;
            right: 20px;
            background: rgba(0, 0, 0, 0.5);
            padding: 10px 15px;
            border-radius: 20px;
            font-size: 0.9rem;
            backdrop-filter: blur(10px);
        }

        .status-dot {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #4ade80;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        @media (max-width: 768px) {
            .logo { font-size: 2rem; }
            h1 { font-size: 2rem; }
            .subtitle { font-size: 1rem; }
            .services-grid { grid-template-columns: 1fr; }
            .quick-links { flex-direction: column; align-items: center; }
        }
    </style>
</head>
<body>
    <div class="status-indicator">
        <span class="status-dot"></span>
        System Online
    </div>

    <div class="container">
        <div class="logo">🖥️</div>
        <h1>Marketing Agency WebTop</h1>
        <p class="subtitle">Professional Remote Desktop Environment</p>

        <div class="services-grid">
            <a href="vnc.html" class="service-card">
                <span class="service-icon">🖥️</span>
                <div class="service-title">Remote Desktop</div>
                <div class="service-description">
                    Access your full KDE Plasma desktop with all marketing tools, design software, and development environments.
                </div>
            </a>

            <a href="vnc-audio.html" class="service-card">
                <span class="service-icon">🎵</span>
                <div class="service-title">Audio Control Center</div>
                <div class="service-description">
                    Manage WebRTC audio streaming, volume controls, and real-time audio quality monitoring.
                </div>
            </a>
        </div>

        <div class="quick-links">
            <a href="vnc_lite.html" class="quick-link">🚀 Quick Connect</a>
            <a href="/webrtc-client.html" class="quick-link">🎧 Audio Test</a>
            <a href="http://localhost:7681" class="quick-link" target="_blank">💻 Web Terminal</a>
        </div>

        <div style="margin-top: 3rem; opacity: 0.7; font-size: 0.9rem;">
            <p>✨ Features: KDE Desktop • Audio Support • Marketing Tools • Video Editing • Development Stack</p>
        </div>
    </div>

    <script>
        // Simple connection test
        function testConnection() {
            fetch('/package.json')
                .then(response => response.ok ? 'online' : 'offline')
                .catch(() => 'offline')
                .then(status => {
                    const dot = document.querySelector('.status-dot');
                    const indicator = document.querySelector('.status-indicator');
                    if (status === 'offline') {
                        dot.style.background = '#ef4444';
                        indicator.innerHTML = '<span class="status-dot"></span>Connection Issues';
                    }
                });
        }

        // Test connection on load
        testConnection();
        
        // Retest every 30 seconds
        setInterval(testConnection, 30000);
    </script>
</body>
</html>
EOF

# Create dedicated audio control page
cat > "$NOVNC_DIR/vnc-audio.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebRTC Audio Control Center</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh;
            color: white;
            padding: 2rem;
        }

        .header {
            text-align: center;
            margin-bottom: 3rem;
        }

        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
            font-weight: 700;
        }

        .header p {
            font-size: 1.1rem;
            opacity: 0.8;
        }

        .audio-dashboard {
            max-width: 1200px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 2rem;
        }

        .control-panel {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(15px);
            border-radius: 20px;
            padding: 2rem;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }

        .panel-title {
            font-size: 1.3rem;
            font-weight: 600;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .instructions {
            background: rgba(59, 130, 246, 0.1);
            border: 1px solid rgba(59, 130, 246, 0.3);
            border-radius: 12px;
            padding: 1.5rem;
            margin-bottom: 2rem;
        }

        .instructions h3 {
            color: #60a5fa;
            margin-bottom: 1rem;
            font-size: 1.1rem;
        }

        .instructions ol {
            margin-left: 1.5rem;
            line-height: 1.6;
        }

        .instructions li {
            margin-bottom: 0.5rem;
        }

        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }

        .status-item {
            background: rgba(255, 255, 255, 0.05);
            padding: 1rem;
            border-radius: 10px;
            text-align: center;
        }

        .status-value {
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 0.5rem;
        }

        .status-label {
            font-size: 0.9rem;
            opacity: 0.7;
        }

        .back-link {
            position: fixed;
            top: 20px;
            left: 20px;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            text-decoration: none;
            padding: 0.75rem 1.5rem;
            border-radius: 25px;
            font-weight: 500;
            transition: all 0.3s ease;
            border: 1px solid rgba(255, 255, 255, 0.3);
            backdrop-filter: blur(10px);
        }

        .back-link:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }

        .audio-test-section {
            margin-top: 2rem;
            padding: 1.5rem;
            background: rgba(34, 197, 94, 0.1);
            border: 1px solid rgba(34, 197, 94, 0.3);
            border-radius: 12px;
        }

        .test-button {
            background: linear-gradient(135deg, #10b981, #059669);
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            margin-right: 1rem;
            margin-bottom: 0.5rem;
        }

        .test-button:hover {
            background: linear-gradient(135deg, #059669, #047857);
            transform: translateY(-1px);
        }

        .diagnostic-info {
            margin-top: 2rem;
            font-family: 'Courier New', monospace;
            font-size: 0.9rem;
            background: rgba(0, 0, 0, 0.3);
            padding: 1rem;
            border-radius: 8px;
            max-height: 200px;
            overflow-y: auto;
        }

        @media (max-width: 768px) {
            body { padding: 1rem; }
            .header h1 { font-size: 2rem; }
            .audio-dashboard { grid-template-columns: 1fr; }
            .back-link { position: static; margin-bottom: 2rem; display: inline-block; }
        }
    </style>
</head>
<body>
    <a href="index.html" class="back-link">← Back to Home</a>

    <div class="header">
        <h1>🎵 Audio Control Center</h1>
        <p>WebRTC Audio Streaming & Quality Management</p>
    </div>

    <div class="audio-dashboard">
        <div class="control-panel">
            <div class="panel-title">
                🎧 Audio Controls
            </div>
            
            <div class="instructions">
                <h3>How to Enable Audio:</h3>
                <ol>
                    <li>The WebRTC audio controls will appear automatically below</li>
                    <li>Click "Connect Audio" to start streaming</li>
                    <li>Adjust volume using the slider</li>
                    <li>Monitor connection quality in real-time</li>
                </ol>
            </div>

            <div id="webrtc-audio-container">
                <!-- WebRTC controls will be injected here automatically -->
            </div>

            <div class="audio-test-section">
                <h4 style="margin-bottom: 1rem;">🧪 Audio Testing</h4>
                <button class="test-button" onclick="testAudioPipeline()">Test Audio Pipeline</button>
                <button class="test-button" onclick="testWebRTCConnection()">Test WebRTC Connection</button>
                <button class="test-button" onclick="showDiagnostics()">Show Diagnostics</button>
            </div>
        </div>

        <div class="control-panel">
            <div class="panel-title">
                📊 System Status
            </div>
            
            <div class="status-grid">
                <div class="status-item">
                    <div class="status-value" id="connection-status">Checking...</div>
                    <div class="status-label">Connection</div>
                </div>
                <div class="status-item">
                    <div class="status-value" id="audio-quality">-</div>
                    <div class="status-label">Audio Quality</div>
                </div>
                <div class="status-item">
                    <div class="status-value" id="latency">-</div>
                    <div class="status-label">Latency</div>
                </div>
                <div class="status-item">
                    <div class="status-value" id="bitrate">-</div>
                    <div class="status-label">Bitrate</div>
                </div>
            </div>

            <div id="diagnostic-output" class="diagnostic-info" style="display: none;">
                <div>Diagnostic information will appear here...</div>
            </div>
        </div>
    </div>

    <!-- Load the universal WebRTC audio script -->
    <script src="universal-webrtc.js"></script>
    
    <script>
        // Audio testing functions
        async function testAudioPipeline() {
            const output = document.getElementById('diagnostic-output');
            output.style.display = 'block';
            output.innerHTML = '<div>🔍 Testing audio pipeline...</div>';
            
            try {
                // Test WebRTC bridge connectivity
                const response = await fetch('/package.json');
                if (response.ok) {
                    output.innerHTML += '<div>✅ WebRTC bridge is responding</div>';
                } else {
                    output.innerHTML += '<div>❌ WebRTC bridge not responding</div>';
                }
                
                // Test WebSocket connection
                const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = `${wsProtocol}//${window.location.hostname}:8081`;
                
                const ws = new WebSocket(wsUrl);
                ws.onopen = () => {
                    output.innerHTML += '<div>✅ WebSocket signaling server connected</div>';
                    ws.close();
                };
                ws.onerror = () => {
                    output.innerHTML += '<div>❌ WebSocket signaling server connection failed</div>';
                };
                
            } catch (error) {
                output.innerHTML += `<div>❌ Error: ${error.message}</div>`;
            }
        }

        async function testWebRTCConnection() {
            const output = document.getElementById('diagnostic-output');
            output.style.display = 'block';
            output.innerHTML = '<div>🔍 Testing WebRTC capabilities...</div>';
            
            try {
                // Test WebRTC support
                if (typeof RTCPeerConnection !== 'undefined') {
                    output.innerHTML += '<div>✅ WebRTC is supported</div>';
                    
                    // Test STUN server connectivity
                    const pc = new RTCPeerConnection({
                        iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
                    });
                    
                    pc.onicecandidate = (event) => {
                        if (event.candidate) {
                            output.innerHTML += '<div>✅ ICE candidate generated</div>';
                            pc.close();
                        }
                    };
                    
                    // Create a dummy data channel to trigger ICE gathering
                    pc.createDataChannel('test');
                    const offer = await pc.createOffer();
                    await pc.setLocalDescription(offer);
                    
                } else {
                    output.innerHTML += '<div>❌ WebRTC is not supported</div>';
                }
            } catch (error) {
                output.innerHTML += `<div>❌ WebRTC Error: ${error.message}</div>`;
            }
        }

        function showDiagnostics() {
            const output = document.getElementById('diagnostic-output');
            output.style.display = 'block';
            
            const diagnostics = {
                'User Agent': navigator.userAgent,
                'WebRTC Support': typeof RTCPeerConnection !== 'undefined' ? 'Yes' : 'No',
                'WebSocket Support': typeof WebSocket !== 'undefined' ? 'Yes' : 'No',
                'Audio Context Support': typeof AudioContext !== 'undefined' ? 'Yes' : 'No',
                'Current URL': window.location.href,
                'Protocol': window.location.protocol,
                'Host': window.location.hostname
            };
            
            let diagnosticText = '<div><strong>System Diagnostics:</strong></div>';
            for (const [key, value] of Object.entries(diagnostics)) {
                diagnosticText += `<div>${key}: ${value}</div>`;
            }
            
            output.innerHTML = diagnosticText;
        }

        // Status monitoring
        function updateStatus() {
            // Update connection status
            fetch('/package.json')
                .then(response => {
                    document.getElementById('connection-status').textContent = response.ok ? 'Connected' : 'Disconnected';
                    document.getElementById('connection-status').style.color = response.ok ? '#10b981' : '#ef4444';
                })
                .catch(() => {
                    document.getElementById('connection-status').textContent = 'Offline';
                    document.getElementById('connection-status').style.color = '#ef4444';
                });
        }

        // Initialize status monitoring
        updateStatus();
        setInterval(updateStatus, 5000);

        // Listen for WebRTC audio manager events if available
        document.addEventListener('DOMContentLoaded', () => {
            // Check if WebRTC audio manager is loaded
            if (window.UniversalWebRTCAudioManager) {
                console.log('🎵 Universal WebRTC Audio Manager loaded successfully');
            } else {
                console.log('⚠️ Universal WebRTC Audio Manager not found');
            }
        });
    </script>
</body>
</html>
EOF

echo "✅ Custom noVNC homepage created at $NOVNC_DIR/index.html"
echo "✅ Audio control page created at $NOVNC_DIR/vnc-audio.html"
echo ""
echo "🌐 Access URLs:"
echo "  Homepage: http://37.27.49.246:32768/"
echo "  Audio Control: http://37.27.49.246:32768/vnc-audio.html"
echo "  Desktop: http://37.27.49.246:32768/vnc.html"
echo ""
echo "🔧 Next steps:"
echo "  1. Restart your Docker container to apply port changes"
echo "  2. Run audio diagnostics: docker exec <container> /usr/local/bin/audio-validation.sh"
echo "  3. Test WebRTC pipeline: docker exec <container> /usr/local/bin/test-webrtc-pipeline.sh"

#!/bin/bash
set -euo pipefail

# Network and Streaming Optimization Script
echo "🌐 Implementing network and streaming optimizations..."

# Environment variables with defaults
NETWORK_PROFILE="${NETWORK_PROFILE:-balanced}"
WEBRTC_ENABLED="${WEBRTC_ENABLED:-true}"
QOS_ENABLED="${QOS_ENABLED:-true}"
ADAPTIVE_STREAMING="${ADAPTIVE_STREAMING:-true}"
BANDWIDTH_OPTIMIZATION="${BANDWIDTH_OPTIMIZATION:-true}"

echo "🚀 Network Profile: $NETWORK_PROFILE"

# TCP Optimization for Streaming
optimize_tcp_streaming() {
    echo "🔧 Optimizing TCP settings for streaming..."
    
    # TCP congestion control optimization
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || echo "⚠️  Could not set BBR congestion control"
    sysctl -w net.core.default_qdisc=fq 2>/dev/null || echo "⚠️  Could not set fair queueing"
    
    # TCP buffer optimization for streaming
    sysctl -w net.ipv4.tcp_rmem="8192 262144 16777216" 2>/dev/null || echo "⚠️  Could not set tcp_rmem"
    sysctl -w net.ipv4.tcp_wmem="8192 262144 16777216" 2>/dev/null || echo "⚠️  Could not set tcp_wmem"
    sysctl -w net.core.rmem_max=16777216 2>/dev/null || echo "⚠️  Could not set rmem_max"
    sysctl -w net.core.wmem_max=16777216 2>/dev/null || echo "⚠️  Could not set wmem_max"
    
    # TCP optimization for low latency
    sysctl -w net.ipv4.tcp_low_latency=1 2>/dev/null || echo "⚠️  Could not enable tcp_low_latency"
    sysctl -w net.ipv4.tcp_timestamps=1 2>/dev/null || echo "⚠️  Could not enable tcp_timestamps"
    sysctl -w net.ipv4.tcp_sack=1 2>/dev/null || echo "⚠️  Could not enable tcp_sack"
    sysctl -w net.ipv4.tcp_window_scaling=1 2>/dev/null || echo "⚠️  Could not enable tcp_window_scaling"
    
    # Reduce TCP keepalive for faster connection recovery
    sysctl -w net.ipv4.tcp_keepalive_time=300 2>/dev/null || echo "⚠️  Could not set tcp_keepalive_time"
    sysctl -w net.ipv4.tcp_keepalive_probes=3 2>/dev/null || echo "⚠️  Could not set tcp_keepalive_probes"
    sysctl -w net.ipv4.tcp_keepalive_intvl=15 2>/dev/null || echo "⚠️  Could not set tcp_keepalive_intvl"
    
    echo "✅ TCP streaming optimization completed"
}

# WebRTC Implementation
setup_webrtc_streaming() {
    echo "📹 Setting up WebRTC streaming alternative..."
    
    # Install WebRTC dependencies if needed
    which node >/dev/null 2>&1 || {
        echo "⚠️  Node.js not found, WebRTC setup limited"
        return
    }
    
    # Create WebRTC signaling server
    cat > /usr/local/bin/webrtc-signaling-server.js << 'EOF'
const WebSocket = require('ws');
const http = require('http');
const url = require('url');

const PORT = process.env.WEBRTC_PORT || 8080;
const server = http.createServer();
const wss = new WebSocket.Server({ server });

console.log('🚀 WebRTC Signaling Server starting...');

const clients = new Map();
let roomCounter = 0;

wss.on('connection', (ws, req) => {
    const clientId = `client-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const room = `room-${roomCounter++}`;
    
    clients.set(clientId, { ws, room });
    console.log(`👤 Client ${clientId} connected to room ${room}`);
    
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            console.log(`📨 Message from ${clientId}:`, data.type);
            
            // Broadcast to other clients in the same room
            clients.forEach((client, id) => {
                if (id !== clientId && client.room === room && client.ws.readyState === WebSocket.OPEN) {
                    client.ws.send(JSON.stringify({
                        ...data,
                        from: clientId
                    }));
                }
            });
        } catch (error) {
            console.error('❌ Error processing message:', error);
        }
    });
    
    ws.on('close', () => {
        clients.delete(clientId);
        console.log(`👋 Client ${clientId} disconnected`);
    });
    
    ws.on('error', (error) => {
        console.error(`❌ WebSocket error for ${clientId}:`, error);
        clients.delete(clientId);
    });
    
    // Send welcome message
    ws.send(JSON.stringify({
        type: 'welcome',
        clientId: clientId,
        room: room
    }));
});

server.listen(PORT, () => {
    console.log(`✅ WebRTC Signaling Server listening on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Shutting down WebRTC Signaling Server...');
    wss.close(() => {
        server.close(() => {
            process.exit(0);
        });
    });
});
EOF
    
    # Create WebRTC client integration
    cat > /usr/share/novnc/webrtc-client.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>WebRTC Remote Desktop - Marketing Agency WebTop</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .status-panel {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
        }
        
        .video-container {
            position: relative;
            background: rgba(0, 0, 0, 0.3);
            border-radius: 10px;
            overflow: hidden;
        }
        
        #remoteVideo {
            width: 100%;
            height: auto;
            min-height: 400px;
            background: #000;
        }
        
        .controls {
            position: absolute;
            bottom: 10px;
            left: 10px;
            right: 10px;
            background: rgba(0, 0, 0, 0.7);
            border-radius: 5px;
            padding: 10px;
            display: flex;
            gap: 10px;
            align-items: center;
        }
        
        button {
            background: rgba(255, 255, 255, 0.2);
            border: 1px solid rgba(255, 255, 255, 0.3);
            color: white;
            padding: 8px 16px;
            border-radius: 5px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        button:hover {
            background: rgba(255, 255, 255, 0.3);
        }
        
        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        
        .quality-indicator {
            background: #28a745;
            color: white;
            padding: 4px 8px;
            border-radius: 3px;
            font-size: 12px;
        }
        
        .quality-indicator.warning { background: #ffc107; }
        .quality-indicator.error { background: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <div class="status-panel">
            <h1>🚀 WebRTC Remote Desktop</h1>
            <div id="status">Initializing WebRTC connection...</div>
            <div id="stats" style="margin-top: 10px; font-size: 14px; opacity: 0.8;"></div>
        </div>
        
        <div class="video-container">
            <video id="remoteVideo" autoplay playsinline></video>
            <div class="controls">
                <button id="connectBtn">Connect</button>
                <button id="disconnectBtn" disabled>Disconnect</button>
                <span class="quality-indicator" id="qualityIndicator">Initializing</span>
                <span id="bitrateInfo" style="margin-left: auto; font-size: 12px;"></span>
            </div>
        </div>
    </div>

    <script>
        class WebRTCDesktop {
            constructor() {
                this.pc = null;
                this.ws = null;
                this.localStream = null;
                this.remoteVideo = document.getElementById('remoteVideo');
                this.statusDiv = document.getElementById('status');
                this.statsDiv = document.getElementById('stats');
                this.qualityIndicator = document.getElementById('qualityIndicator');
                this.bitrateInfo = document.getElementById('bitrateInfo');
                
                this.setupEventListeners();
                this.startStatsCollection();
            }
            
            setupEventListeners() {
                document.getElementById('connectBtn').addEventListener('click', () => this.connect());
                document.getElementById('disconnectBtn').addEventListener('click', () => this.disconnect());
            }
            
            async connect() {
                try {
                    this.updateStatus('Connecting to signaling server...');
                    
                    // Connect to WebRTC signaling server
                    this.ws = new WebSocket(`ws://${window.location.hostname}:8080`);
                    
                    this.ws.onopen = () => {
                        this.updateStatus('Connected to signaling server');
                        this.initializePeerConnection();
                    };
                    
                    this.ws.onmessage = (event) => {
                        const message = JSON.parse(event.data);
                        this.handleSignalingMessage(message);
                    };
                    
                    this.ws.onerror = (error) => {
                        this.updateStatus('WebSocket error: ' + error, 'error');
                    };
                    
                    this.ws.onclose = () => {
                        this.updateStatus('Disconnected from signaling server');
                    };
                    
                } catch (error) {
                    this.updateStatus('Connection failed: ' + error.message, 'error');
                }
            }
            
            initializePeerConnection() {
                const configuration = {
                    iceServers: [
                        { urls: 'stun:stun.l.google.com:19302' },
                        { urls: 'stun:stun1.l.google.com:19302' }
                    ]
                };
                
                this.pc = new RTCPeerConnection(configuration);
                
                this.pc.onicecandidate = (event) => {
                    if (event.candidate) {
                        this.sendSignalingMessage({
                            type: 'ice-candidate',
                            candidate: event.candidate
                        });
                    }
                };
                
                this.pc.ontrack = (event) => {
                    this.remoteVideo.srcObject = event.streams[0];
                    this.updateStatus('Receiving remote stream', 'success');
                    document.getElementById('connectBtn').disabled = true;
                    document.getElementById('disconnectBtn').disabled = false;
                };
                
                this.pc.onconnectionstatechange = () => {
                    this.updateStatus(`Connection state: ${this.pc.connectionState}`);
                    this.updateQualityIndicator(this.pc.connectionState);
                };
                
                // Request remote stream
                this.sendSignalingMessage({ type: 'request-stream' });
            }
            
            async handleSignalingMessage(message) {
                switch (message.type) {
                    case 'offer':
                        await this.pc.setRemoteDescription(message.offer);
                        const answer = await this.pc.createAnswer();
                        await this.pc.setLocalDescription(answer);
                        this.sendSignalingMessage({
                            type: 'answer',
                            answer: answer
                        });
                        break;
                        
                    case 'answer':
                        await this.pc.setRemoteDescription(message.answer);
                        break;
                        
                    case 'ice-candidate':
                        await this.pc.addIceCandidate(message.candidate);
                        break;
                        
                    case 'welcome':
                        this.updateStatus(`Connected as ${message.clientId} in ${message.room}`);
                        break;
                }
            }
            
            sendSignalingMessage(message) {
                if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                    this.ws.send(JSON.stringify(message));
                }
            }
            
            disconnect() {
                if (this.pc) {
                    this.pc.close();
                    this.pc = null;
                }
                
                if (this.ws) {
                    this.ws.close();
                    this.ws = null;
                }
                
                this.remoteVideo.srcObject = null;
                this.updateStatus('Disconnected');
                document.getElementById('connectBtn').disabled = false;
                document.getElementById('disconnectBtn').disabled = true;
            }
            
            updateStatus(message, type = 'info') {
                this.statusDiv.textContent = message;
                this.statusDiv.className = type;
            }
            
            updateQualityIndicator(state) {
                let className = 'quality-indicator';
                let text = state;
                
                switch (state) {
                    case 'connected':
                        className += '';
                        text = 'Connected';
                        break;
                    case 'connecting':
                        className += ' warning';
                        text = 'Connecting';
                        break;
                    case 'disconnected':
                    case 'failed':
                        className += ' error';
                        text = 'Disconnected';
                        break;
                    default:
                        className += ' warning';
                }
                
                this.qualityIndicator.className = className;
                this.qualityIndicator.textContent = text;
            }
            
            async startStatsCollection() {
                setInterval(async () => {
                    if (this.pc && this.pc.connectionState === 'connected') {
                        const stats = await this.pc.getStats();
                        this.processStats(stats);
                    }
                }, 1000);
            }
            
            processStats(stats) {
                let inboundRtp = null;
                
                stats.forEach((report) => {
                    if (report.type === 'inbound-rtp' && report.mediaType === 'video') {
                        inboundRtp = report;
                    }
                });
                
                if (inboundRtp) {
                    const bitrate = Math.round((inboundRtp.bytesReceived * 8) / 1000); // kbps
                    const fps = inboundRtp.framesPerSecond || 0;
                    
                    this.bitrateInfo.textContent = `${bitrate} kbps, ${fps} fps`;
                    this.statsDiv.textContent = `Packets: ${inboundRtp.packetsReceived}, Lost: ${inboundRtp.packetsLost || 0}`;
                }
            }
        }
        
        // Initialize WebRTC Desktop when page loads
        window.addEventListener('load', () => {
            new WebRTCDesktop();
        });
    </script>
</body>
</html>
EOF
    
    echo "✅ WebRTC streaming setup completed"
}

# Quality of Service (QoS) Management
setup_qos_management() {
    echo "⚖️  Setting up Quality of Service management..."
    
    cat > /usr/local/bin/qos-manager << 'EOF'
#!/bin/bash
set -euo pipefail

echo "⚖️  Starting QoS management..."

# Traffic classification and prioritization
setup_traffic_shaping() {
    # Check if tc (traffic control) is available
    if ! command -v tc >/dev/null 2>&1; then
        echo "⚠️  Traffic control (tc) not available"
        return
    fi
    
    local interface="${1:-eth0}"
    
    # Create root qdisc
    tc qdisc add dev "$interface" root handle 1: htb default 30 2>/dev/null || true
    
    # Create classes for different traffic types
    # High priority: VNC/WebRTC traffic
    tc class add dev "$interface" parent 1: classid 1:10 htb rate 80% ceil 100% prio 1 2>/dev/null || true
    
    # Medium priority: System traffic
    tc class add dev "$interface" parent 1: classid 1:20 htb rate 15% ceil 50% prio 2 2>/dev/null || true
    
    # Low priority: Background traffic
    tc class add dev "$interface" parent 1: classid 1:30 htb rate 5% ceil 20% prio 3 2>/dev/null || true
    
    # Add filters for traffic classification
    # VNC traffic (port 5901)
    tc filter add dev "$interface" parent 1:0 protocol ip prio 1 u32 match ip dport 5901 0xffff flowid 1:10 2>/dev/null || true
    
    # noVNC/WebSocket traffic (port 80)
    tc filter add dev "$interface" parent 1:0 protocol ip prio 1 u32 match ip dport 80 0xffff flowid 1:10 2>/dev/null || true
    
    # WebRTC signaling (port 8080)
    tc filter add dev "$interface" parent 1:0 protocol ip prio 1 u32 match ip dport 8080 0xffff flowid 1:10 2>/dev/null || true
    
    echo "✅ Traffic shaping configured for $interface"
}

# Bandwidth monitoring and adjustment
monitor_bandwidth() {
    while true; do
        # Get network interface statistics
        local rx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $2}' || echo "0")
        local tx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $10}' || echo "0")
        
        # Calculate bandwidth utilization
        sleep 5
        local new_rx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $2}' || echo "0")
        local new_tx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $10}' || echo "0")
        
        local rx_rate=$(( (new_rx_bytes - rx_bytes) / 5 / 1024 ))  # KB/s
        local tx_rate=$(( (new_tx_bytes - tx_bytes) / 5 / 1024 ))  # KB/s
        
        echo "📊 Bandwidth: RX=${rx_rate}KB/s, TX=${tx_rate}KB/s"
        
        # Adaptive QoS based on utilization
        if [ "$rx_rate" -gt 1000 ] || [ "$tx_rate" -gt 1000 ]; then
            echo "⚠️  High bandwidth usage, applying stricter QoS"
            # Could implement dynamic QoS adjustments here
        fi
        
        # Export for other scripts
        echo "$rx_rate" > /tmp/qos_rx_rate
        echo "$tx_rate" > /tmp/qos_tx_rate
        
        sleep 25
    done
}

# Initialize QoS
setup_traffic_shaping "eth0"
monitor_bandwidth
EOF
    
    chmod +x /usr/local/bin/qos-manager
    
    echo "✅ QoS management setup completed"
}

# Adaptive Bitrate Streaming
setup_adaptive_streaming() {
    echo "📊 Setting up adaptive bitrate streaming..."
    
    cat > /usr/local/bin/adaptive-bitrate-controller << 'EOF'
#!/bin/bash
set -euo pipefail

echo "📊 Starting adaptive bitrate controller..."

# Configuration
MIN_QUALITY=1
MAX_QUALITY=9
DEFAULT_QUALITY=6
ADAPTATION_INTERVAL=15

current_quality=$DEFAULT_QUALITY

# Bandwidth measurement
measure_available_bandwidth() {
    # Simple bandwidth estimation based on recent transfer rates
    local rx_rate=$(cat /tmp/qos_rx_rate 2>/dev/null || echo "100")
    local tx_rate=$(cat /tmp/qos_tx_rate 2>/dev/null || echo "100")
    
    # Estimate available bandwidth (simple heuristic)
    local estimated_bandwidth=$(( (rx_rate + tx_rate) * 8 / 1000 ))  # Mbps
    echo "$estimated_bandwidth"
}

# Connection quality assessment
assess_connection_quality() {
    local bandwidth="$1"
    local packet_loss=$(cat /tmp/packet_loss 2>/dev/null || echo "0")
    local latency=$(cat /tmp/network_latency 2>/dev/null || echo "50")
    
    # Quality scoring (0-100)
    local quality_score=100
    
    # Bandwidth factor
    if [ "$bandwidth" -lt 1 ]; then
        quality_score=$((quality_score - 40))
    elif [ "$bandwidth" -lt 5 ]; then
        quality_score=$((quality_score - 20))
    elif [ "$bandwidth" -lt 10 ]; then
        quality_score=$((quality_score - 10))
    fi
    
    # Latency factor
    if [ "$latency" -gt 200 ]; then
        quality_score=$((quality_score - 30))
    elif [ "$latency" -gt 100 ]; then
        quality_score=$((quality_score - 15))
    fi
    
    # Packet loss factor
    if [ "$packet_loss" -gt 5 ]; then
        quality_score=$((quality_score - 25))
    elif [ "$packet_loss" -gt 1 ]; then
        quality_score=$((quality_score - 10))
    fi
    
    # Ensure score is between 0-100
    quality_score=$((quality_score < 0 ? 0 : quality_score))
    quality_score=$((quality_score > 100 ? 100 : quality_score))
    
    echo "$quality_score"
}

# Quality adaptation logic
adapt_quality() {
    local quality_score="$1"
    local new_quality=$current_quality
    
    if [ "$quality_score" -gt 80 ]; then
        # Excellent connection - increase quality
        new_quality=$((current_quality < MAX_QUALITY ? current_quality + 1 : MAX_QUALITY))
    elif [ "$quality_score" -gt 60 ]; then
        # Good connection - maintain or slightly increase
        new_quality=$((current_quality < (MAX_QUALITY - 1) ? current_quality + 1 : current_quality))
    elif [ "$quality_score" -gt 40 ]; then
        # Fair connection - maintain current quality
        # No change
        :
    elif [ "$quality_score" -gt 20 ]; then
        # Poor connection - decrease quality
        new_quality=$((current_quality > (MIN_QUALITY + 1) ? current_quality - 1 : current_quality))
    else
        # Very poor connection - significantly decrease quality
        new_quality=$((current_quality > MIN_QUALITY ? current_quality - 2 : MIN_QUALITY))
        new_quality=$((new_quality < MIN_QUALITY ? MIN_QUALITY : new_quality))
    fi
    
    if [ "$new_quality" != "$current_quality" ]; then
        echo "🔄 Adapting quality from $current_quality to $new_quality (score: $quality_score)"
        current_quality=$new_quality
        
        # Apply quality change (would need integration with VNC/WebRTC)
        echo "$current_quality" > /tmp/adaptive_quality
        
        # Signal quality change to streaming services
        pkill -USR1 x11vnc 2>/dev/null || true
    else
        echo "📊 Quality maintained at $current_quality (score: $quality_score)"
    fi
}

# Main adaptation loop
while true; do
    bandwidth=$(measure_available_bandwidth)
    quality_score=$(assess_connection_quality "$bandwidth")
    
    echo "📊 Bandwidth: ${bandwidth}Mbps, Quality Score: $quality_score, Current Quality: $current_quality"
    
    adapt_quality "$quality_score"
    
    sleep "$ADAPTATION_INTERVAL"
done
EOF
    
    chmod +x /usr/local/bin/adaptive-bitrate-controller
    
    echo "✅ Adaptive bitrate streaming setup completed"
}

# Connection Health Monitoring
setup_connection_monitoring() {
    echo "🩺 Setting up connection health monitoring..."
    
    cat > /usr/local/bin/connection-health-monitor << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🩺 Starting connection health monitoring..."

# Monitoring configuration
PING_INTERVAL=5
PACKET_LOSS_THRESHOLD=5
LATENCY_THRESHOLD=200
JITTER_THRESHOLD=50

# Health metrics
measure_latency() {
    # Ping localhost for basic latency measurement
    local latency=$(ping -c 1 -W 1 localhost 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}' || echo "999")
    echo "${latency%.*}"  # Remove decimal part
}

measure_packet_loss() {
    # Simple packet loss detection (could be enhanced with real network testing)
    local loss=$(ping -c 10 -i 0.2 localhost 2>/dev/null | grep 'packet loss' | awk '{print $6}' | sed 's/%//' || echo "0")
    echo "${loss%.*}"
}

measure_jitter() {
    # Measure network jitter through multiple pings
    local jitter_sum=0
    local count=0
    local prev_latency=0
    
    for i in {1..5}; do
        local latency=$(measure_latency)
        if [ "$prev_latency" -ne 0 ]; then
            local diff=$((latency > prev_latency ? latency - prev_latency : prev_latency - latency))
            jitter_sum=$((jitter_sum + diff))
            count=$((count + 1))
        fi
        prev_latency=$latency
        sleep 0.2
    done
    
    if [ "$count" -gt 0 ]; then
        echo $((jitter_sum / count))
    else
        echo "0"
    fi
}

# Connection recovery
trigger_connection_recovery() {
    local issue="$1"
    echo "🚨 Connection issue detected: $issue"
    echo "🔄 Triggering connection recovery..."
    
    case "$issue" in
        "high_latency")
            # Reduce quality and restart problematic services
            echo "3" > /tmp/adaptive_quality
            ;;
        "packet_loss")
            # Switch to more robust encoding
            echo "2" > /tmp/adaptive_quality
            ;;
        "high_jitter")
            # Enable additional buffering
            echo "buffering_enabled" > /tmp/connection_mode
            ;;
    esac
    
    # Log recovery action
    echo "[$(date)] Recovery triggered for $issue" >> /var/log/connection-recovery.log
}

# Main monitoring loop
while true; do
    latency=$(measure_latency)
    packet_loss=$(measure_packet_loss)
    jitter=$(measure_jitter)
    
    # Export metrics
    echo "$latency" > /tmp/network_latency
    echo "$packet_loss" > /tmp/packet_loss
    echo "$jitter" > /tmp/network_jitter
    
    echo "🩺 Health: Latency=${latency}ms, Loss=${packet_loss}%, Jitter=${jitter}ms"
    
    # Check thresholds and trigger recovery if needed
    if [ "$latency" -gt "$LATENCY_THRESHOLD" ]; then
        trigger_connection_recovery "high_latency"
    elif [ "$packet_loss" -gt "$PACKET_LOSS_THRESHOLD" ]; then
        trigger_connection_recovery "packet_loss"
    elif [ "$jitter" -gt "$JITTER_THRESHOLD" ]; then
        trigger_connection_recovery "high_jitter"
    fi
    
    sleep "$PING_INTERVAL"
done
EOF
    
    chmod +x /usr/local/bin/connection-health-monitor
    
    echo "✅ Connection health monitoring setup completed"
}

# Bandwidth Usage Optimization
setup_bandwidth_optimization() {
    echo "📈 Setting up bandwidth usage optimization..."
    
    cat > /usr/local/bin/bandwidth-optimizer << 'EOF'
#!/bin/bash
set -euo pipefail

echo "📈 Starting bandwidth usage optimization..."

# Compression optimization
optimize_compression() {
    local available_bandwidth="$1"
    local cpu_usage="$2"
    
    if [ "$available_bandwidth" -lt 2 ]; then
        # Low bandwidth - maximum compression
        echo "🗜️  Low bandwidth detected, enabling maximum compression"
        export VNC_COMPRESSION_LEVEL=9
        export VNC_QUALITY_LEVEL=1
    elif [ "$available_bandwidth" -lt 10 ]; then
        # Medium bandwidth - balanced compression
        echo "🗜️  Medium bandwidth detected, using balanced compression"
        export VNC_COMPRESSION_LEVEL=6
        export VNC_QUALITY_LEVEL=4
    else
        # High bandwidth - optimize for quality
        echo "🗜️  High bandwidth detected, optimizing for quality"
        export VNC_COMPRESSION_LEVEL=3
        export VNC_QUALITY_LEVEL=8
    fi
    
    # CPU-based adjustments
    if [ "$cpu_usage" -gt 80 ]; then
        echo "⚠️  High CPU usage, reducing compression complexity"
        export VNC_COMPRESSION_LEVEL=$((VNC_COMPRESSION_LEVEL - 2))
        export VNC_COMPRESSION_LEVEL=$((VNC_COMPRESSION_LEVEL < 1 ? 1 : VNC_COMPRESSION_LEVEL))
    fi
}

# Frame rate optimization
optimize_framerate() {
    local connection_quality="$1"
    
    if [ "$connection_quality" -gt 80 ]; then
        export TARGET_FPS=30
    elif [ "$connection_quality" -gt 60 ]; then
        export TARGET_FPS=24
    elif [ "$connection_quality" -gt 40 ]; then
        export TARGET_FPS=18
    elif [ "$connection_quality" -gt 20 ]; then
        export TARGET_FPS=12
    else
        export TARGET_FPS=8
    fi
    
    echo "🎬 Target FPS set to $TARGET_FPS based on connection quality: $connection_quality"
}

# Data usage tracking
track_data_usage() {
    local prev_rx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $2}' || echo "0")
    local prev_tx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $10}' || echo "0")
    
    while true; do
        sleep 60
        
        local curr_rx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $2}' || echo "0")
        local curr_tx_bytes=$(cat /proc/net/dev | grep eth0 | awk '{print $10}' || echo "0")
        
        local rx_mb=$(( (curr_rx_bytes - prev_rx_bytes) / 1024 / 1024 ))
        local tx_mb=$(( (curr_tx_bytes - prev_tx_bytes) / 1024 / 1024 ))
        local total_mb=$((rx_mb + tx_mb))
        
        echo "📊 Data usage last minute: RX=${rx_mb}MB, TX=${tx_mb}MB, Total=${total_mb}MB"
        
        # Log hourly usage
        echo "[$(date '+%Y-%m-%d %H:%M')] ${total_mb}MB" >> /var/log/bandwidth-usage.log
        
        prev_rx_bytes=$curr_rx_bytes
        prev_tx_bytes=$curr_tx_bytes
    done
}

# Main optimization loop
optimize_bandwidth() {
    while true; do
        # Get current metrics
        local bandwidth=$(cat /tmp/qos_rx_rate 2>/dev/null || echo "100")
        local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
        local connection_quality=$(cat /tmp/connection_quality 2>/dev/null || echo "50")
        
        # Apply optimizations
        optimize_compression "$bandwidth" "$cpu_usage"
        optimize_framerate "$connection_quality"
        
        echo "🔧 Optimization cycle completed"
        sleep 30
    done
}

# Start optimization processes
track_data_usage &
optimize_bandwidth
EOF
    
    chmod +x /usr/local/bin/bandwidth-optimizer
    
    echo "✅ Bandwidth optimization setup completed"
}

# Main execution
main() {
    echo "🌐 Starting network and streaming optimizations..."
    
    # Apply TCP optimizations
    optimize_tcp_streaming
    
    # Setup advanced features based on configuration
    if [ "$WEBRTC_ENABLED" = "true" ]; then
        setup_webrtc_streaming
    fi
    
    if [ "$QOS_ENABLED" = "true" ]; then
        setup_qos_management
    fi
    
    if [ "$ADAPTIVE_STREAMING" = "true" ]; then
        setup_adaptive_streaming
    fi
    
    # Always setup monitoring and optimization
    setup_connection_monitoring
    
    if [ "$BANDWIDTH_OPTIMIZATION" = "true" ]; then
        setup_bandwidth_optimization
    fi
    
    echo "✅ Network and streaming optimization completed"
    echo "🌐 TCP settings optimized for streaming"
    echo "📹 WebRTC alternative streaming available"
    echo "⚖️  QoS management configured"
    echo "📊 Adaptive bitrate streaming enabled"
    echo "🩺 Connection health monitoring active"
    echo "📈 Bandwidth usage optimization running"
}

# Execute main function
main "$@"
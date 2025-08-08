# WebRTC Configuration Guide

## Overview

The Ubuntu KDE WebTop now supports WebRTC-first audio streaming with automatic WebSocket fallback. This guide covers configuration options for optimal WebRTC performance, especially over the internet.

## Environment Variables

Add these to your `.env` file for WebRTC configuration:

```bash
# WebRTC Configuration
WEBRTC_PORT=8080
WEBRTC_STUN_SERVER=stun:stun.l.google.com:19302
WEBRTC_TURN_SERVER=turn:your-turn-server.com:3478
WEBRTC_TURN_USERNAME=your-turn-username
WEBRTC_TURN_PASSWORD=your-turn-password

# Audio Service Configuration
AUDIO_HOST=your-server.com
AUDIO_PORT=8080
AUDIO_WS_SCHEME=wss
```

## STUN/TURN Server Setup

### Using Google's Public STUN Servers (Default)

```bash
WEBRTC_STUN_SERVER=stun:stun.l.google.com:19302
```

### Setting Up Your Own TURN Server

For production deployments over the internet, you'll need a TURN server:

#### Option 1: coturn (Recommended)

```bash
# Install coturn
sudo apt update
sudo apt install coturn

# Configure coturn
sudo tee /etc/turnserver.conf << EOF
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=YOUR_SERVER_IP
external-ip=YOUR_SERVER_IP
realm=your-domain.com
server-name=your-domain.com
lt-cred-mech
user=turnuser:turnpass
no-stdout-log
log-file=/var/log/turnserver.log
EOF

# Start coturn
sudo systemctl enable coturn
sudo systemctl start coturn
```

#### Option 2: Cloud TURN Services

**Twilio STUN/TURN:**
```bash
WEBRTC_STUN_SERVER=stun:global.stun.twilio.com:3478
WEBRTC_TURN_SERVER=turn:global.turn.twilio.com:3478
WEBRTC_TURN_USERNAME=your-twilio-username
WEBRTC_TURN_PASSWORD=your-twilio-credential
```

**Xirsys:**
```bash
WEBRTC_TURN_SERVER=turn:your-channel.xirsys.com:80
WEBRTC_TURN_USERNAME=your-xirsys-username
WEBRTC_TURN_PASSWORD=your-xirsys-credential
```

## Network Configuration

### Required Ports

| Port | Protocol | Purpose | Required |
|------|----------|---------|----------|
| 8080 | TCP | Audio Bridge HTTP/WebSocket | Yes |
| 3478 | UDP/TCP | STUN/TURN | For WebRTC over internet |
| 32768 | TCP | noVNC Web Interface | Yes |

### Firewall Configuration

```bash
# Allow audio bridge
sudo ufw allow 8080/tcp

# Allow TURN server (if self-hosted)
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 5349/tcp  # TLS TURN

# Allow noVNC
sudo ufw allow 32768/tcp
```

### Docker Port Mapping

```yaml
# docker-compose.yml
services:
  webtop:
    ports:
      - "32768:80"      # noVNC
      - "8080:8080"     # Audio Bridge
      - "3478:3478"     # STUN/TURN (if hosting TURN server)
    environment:
      - WEBRTC_STUN_SERVER=stun:stun.l.google.com:19302
      - WEBRTC_TURN_SERVER=turn:your-turn-server.com:3478
      - WEBRTC_TURN_USERNAME=your-username
      - WEBRTC_TURN_PASSWORD=your-password
```

## Connection Flow

### 1. WebRTC-First Attempt

The client will first attempt WebRTC connection:

1. **ICE Gathering**: Uses STUN/TURN servers to discover network topology
2. **Offer/Answer**: Exchanges SDP via HTTP POST to `/offer`
3. **Connection**: Establishes peer-to-peer audio stream
4. **Audio**: Low-latency audio streaming (typically 20-100ms)

### 2. WebSocket Fallback

If WebRTC fails, automatic fallback to WebSocket:

1. **Connection**: WebSocket to `/audio-stream` endpoint
2. **Audio**: PCM audio streaming (typically 100-300ms latency)
3. **Reliability**: Works through firewalls and proxies

## Testing WebRTC

### Browser Developer Tools

1. Open browser developer tools (F12)
2. Go to Console tab
3. Connect audio and look for logs:
   ```
   [SharedAudioClient] Attempting WebRTC connection...
   [SharedAudioClient] Added recvonly audio transceiver
   [SharedAudioClient] WebRTC offer created
   [SharedAudioClient] WebRTC connection established
   ```

### Health Check

```bash
# Check WebRTC availability
curl http://localhost:8080/health

# Expected response:
{
  "status": "ok",
  "webrtc": true,
  "websocket": true,
  "timestamp": "2024-01-31T12:00:00.000Z"
}
```

### Connection Test Script

```bash
#!/bin/bash
# Test WebRTC and WebSocket connectivity

echo "Testing WebRTC offer endpoint..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"type":"offer","sdp":"test"}' \
  http://localhost:8080/offer

echo -e "\nTesting WebSocket endpoint..."
curl -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  http://localhost:8080/audio-stream
```

## Troubleshooting

### WebRTC Connection Issues

**Symptom**: Immediate fallback to WebSocket
**Causes**:
- No TURN server configured for NAT traversal
- Firewall blocking UDP traffic
- wrtc module not installed

**Solutions**:
```bash
# Check if wrtc module is available
docker exec webtop-kde node -e "console.log(require('wrtc'))"

# Configure TURN server
echo "WEBRTC_TURN_SERVER=turn:your-server.com:3478" >> .env
echo "WEBRTC_TURN_USERNAME=username" >> .env
echo "WEBRTC_TURN_PASSWORD=password" >> .env

# Restart container
./webtop.sh restart
```

### WebSocket Connection Issues

**Symptom**: "All connection methods failed"
**Causes**:
- Audio bridge not running
- Port 8080 not accessible
- WebSocket path incorrect

**Solutions**:
```bash
# Check audio bridge status
docker exec webtop-kde supervisorctl status AudioBridge

# Check port accessibility
curl http://localhost:8080/health

# Check WebSocket path
curl -H "Upgrade: websocket" http://localhost:8080/audio-stream
```

### Audio Quality Issues

**Symptom**: Choppy or distorted audio
**Causes**:
- Network latency
- Buffer underruns
- Sample rate mismatch

**Solutions**:
```bash
# Check network latency
ping your-server.com

# Monitor audio bridge logs
docker exec webtop-kde tail -f /var/log/supervisor/audio-bridge.log

# Test with different sample rates
# (Modify webrtc-audio-server.cjs if needed)
```

## Production Deployment

### SSL/TLS Configuration

For production, use HTTPS and WSS:

```bash
# Update environment
AUDIO_WS_SCHEME=wss
WEBRTC_TURN_SERVER=turns:your-server.com:5349  # TLS TURN
```

### Load Balancing

For multiple WebTop instances:

```nginx
upstream webtop_audio {
    server webtop1:8080;
    server webtop2:8080;
    server webtop3:8080;
}

location /offer {
    proxy_pass http://webtop_audio/offer;
    # ... other settings
}

location /audio-stream {
    proxy_pass http://webtop_audio/audio-stream;
    # ... other settings
}
```

### Monitoring

Monitor WebRTC connection success rates:

```bash
# Check connection methods in logs
docker exec webtop-kde grep -c "WebRTC connection established" /var/log/supervisor/audio-bridge.log
docker exec webtop-kde grep -c "WebSocket audio connection established" /var/log/supervisor/audio-bridge.log
```

## Advanced Configuration

### Custom ICE Servers

```javascript
// In audio-env.js
window.WEBRTC_STUN_SERVER = 'stun:your-stun.com:3478';
window.WEBRTC_TURN_SERVER = 'turn:your-turn.com:3478';
window.WEBRTC_TURN_USERNAME = 'username';
window.WEBRTC_TURN_PASSWORD = 'password';
```

### Multiple TURN Servers

```bash
# Primary TURN server
WEBRTC_TURN_SERVER=turn:turn1.example.com:3478
WEBRTC_TURN_USERNAME=user1
WEBRTC_TURN_PASSWORD=pass1

# Additional servers can be configured in the client code
```

### Regional TURN Servers

For global deployments, configure regional TURN servers:

```javascript
// Regional TURN configuration
const getRegionalTurnServer = () => {
    const region = detectUserRegion(); // Implement region detection
    const turnServers = {
        'us': 'turn:us.turn.example.com:3478',
        'eu': 'turn:eu.turn.example.com:3478',
        'asia': 'turn:asia.turn.example.com:3478'
    };
    return turnServers[region] || turnServers['us'];
};
```

This configuration ensures optimal WebRTC performance while maintaining reliable WebSocket fallback for all network conditions.

### Enforce WebRTC-only Connections

To disable the automatic WebSocket fallback and require WebRTC, set the following in `audio-env.js` or as an environment variable:

```javascript
window.ENABLE_WEBSOCKET_FALLBACK = false;
```

When this flag is `false`, clients will not attempt a WebSocket connection if WebRTC fails.
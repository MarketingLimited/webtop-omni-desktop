# Desktop Audio Integration

This Docker environment now includes complete audio support through a web-based audio bridge.

## How It Works

1. **PulseAudio Virtual Devices**: The container creates virtual audio devices that capture all desktop audio
2. **Audio Bridge Server**: A Node.js WebSocket server streams PulseAudio output in real-time
3. **Web Audio Integration**: The noVNC interface includes audio controls that receive and play the stream

## Accessing Audio

### Web Interface (Recommended)
- Open `http://localhost:32768` in your browser
- The noVNC interface will include audio controls at the bottom
- Click "🔊 Connect Audio" to start receiving desktop audio
- Adjust volume with the slider
- Minimize controls if needed

### Direct Audio Bridge
- Audio bridge is available at `http://localhost:8080/audio-player.html`
- Standalone audio player for testing and debugging

## Audio Controls

- **Connect/Disconnect**: Start/stop audio streaming
- **Volume Control**: Adjust playback volume (0-100%)
- **Status Indicator**: Shows connection status (red = disconnected, green = connected)
- **Minimize**: Hide audio controls to save screen space

## Technical Details

### Ports
- `32768`: Main noVNC interface with audio
- `8080`: Audio bridge WebSocket server
- `4713`: PulseAudio TCP server (for SSH audio forwarding)

### Audio Flow
```
Desktop Apps → PulseAudio → Virtual Sink → Audio Bridge → WebSocket → Browser
```

### Supported Audio
- All desktop application audio (Firefox, VLC, system sounds, etc.)
- 44.1kHz 16-bit stereo PCM
- Real-time streaming with minimal latency

## Troubleshooting

### No Audio in Browser
1. Check that audio bridge is running: `docker logs webtop-kde | grep "Audio bridge"`
2. Verify WebSocket connection in browser console
3. Try disconnecting and reconnecting audio

### Audio Bridge Not Starting
1. Check container logs: `docker logs webtop-kde`
2. Verify Node.js installation in container
3. Check if port 8080 is available

### High Latency
1. Reduce browser audio buffer size (advanced browser settings)
2. Check network connection quality
3. Consider using SSH with audio forwarding for local network

## SSH Audio Forwarding (Alternative)

For users who prefer SSH with audio forwarding:

```bash
# Connect with X11 and PulseAudio forwarding
ssh -X -R 24713:localhost:4713 devuser@localhost -p 2222
```

Then in the SSH session:
```bash
export PULSE_RUNTIME_PATH=/tmp/pulse-socket
```

## Browser Compatibility

- **Chrome/Chromium**: Full support
- **Firefox**: Full support  
- **Safari**: Limited support (may require user interaction)
- **Edge**: Full support

## Security Notes

- Audio bridge only accepts connections from the same host
- No authentication required (intended for local development)
- WebSocket connections are not encrypted (use HTTPS for production)
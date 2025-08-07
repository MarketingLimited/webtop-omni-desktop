# Audio System for Ubuntu KDE WebTop

This WebTop includes a comprehensive PipeWire-based audio system with WebRTC streaming capabilities, optimized for container environments. PulseAudio has been fully removed in favor of a pure PipeWire pipeline.

## Features

- **Container-Optimized**: Pure software audio pipeline that works without hardware dependencies
- **Virtual Audio Devices**: Software-based audio devices for reliable operation
- **WebRTC Audio Bridge**: Stream audio directly to your browser alongside VNC
- **KDE Integration**: Full audio support within KDE Plasma desktop
- **Automatic Recovery**: Self-healing audio system with validation and monitoring

## Host Setup

The container relies on host sound modules and device mappings.

### Required kernel modules

Load the ALSA loopback module before starting the WebTop container:

```bash
sudo modprobe snd-aloop
echo snd-aloop | sudo tee -a /etc/modules
```

### Device mapping

Expose the host sound devices by mapping `/dev/snd` into the container. This
is handled in `docker-compose.yml` under the `devices` section.

These steps ensure the audio system has the necessary devices when the container starts.

## How It Works

### Audio Architecture

1. **PipeWire Core**: Container-optimized audio server with virtual devices
2. **Runtime Environment**: Proper user session and permission management
3. **WebRTC Bridge**: GStreamer-based audio streaming server
4. **Browser Integration**: Seamless audio playback in web browsers
5. **Monitoring**: Continuous health checks and automatic recovery

### Accessing Audio

#### Via noVNC Web Interface
- Open browser to `http://localhost:32768`
- Audio controls automatically appear in the interface
- Click "Connect Audio" to start streaming
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
- `8080`: WebRTC audio bridge

### Audio Flow
```
Desktop Apps → PipeWire → WebRTC Bridge → Browser
```

### Supported Audio
- All desktop application audio (Firefox, VLC, system sounds, etc.)
- 44.1kHz 16-bit stereo PCM
- Real-time streaming with minimal latency

## Troubleshooting

### No Audio in Browser
1. Check that audio bridge is running: `docker logs webtop-kde | grep "WebRTC bridge"`
2. Verify WebRTC connection in browser console
3. Try disconnecting and reconnecting audio
4. Confirm PipeWire's default sink is set to `virtual_speaker`. The system now automatically resets it, or run `/usr/local/bin/fix-pipewire-routing.sh` manually

### Audio Bridge Not Starting
1. Check container logs: `docker logs webtop-kde`
2. Verify Node.js installation in container
3. Check if port 8080 is available

### High Latency
1. Reduce browser audio buffer size (advanced browser settings)
2. Check network connection quality
3. Consider using SSH with audio forwarding for local network

## Browser Compatibility

- **Chrome/Chromium**: Full support
- **Firefox**: Full support  
- **Safari**: Limited support (may require user interaction)
- **Edge**: Full support

## Security Notes

- Audio bridge only accepts connections from the same host
- No authentication required (intended for local development)

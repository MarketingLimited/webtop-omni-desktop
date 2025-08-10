# Audio System for Ubuntu KDE WebTop

This WebTop includes a comprehensive audio system with web-based streaming capabilities, optimized for container environments.

## Features

- **Container-Optimized**: Pure software audio pipeline that works without hardware dependencies
- **Virtual Audio Devices**: Software-based audio devices for reliable operation
- **Web Audio Bridge**: Stream audio directly to your browser alongside VNC
- **KDE Integration**: Full audio support within KDE Plasma desktop
- **Automatic Recovery**: Self-healing audio system with validation and monitoring

## Host Setup

The container relies on an ALSA loopback device provided by the host. Before
starting the WebTop container, make sure the module is loaded:

```bash
sudo modprobe snd-aloop
echo snd-aloop | sudo tee -a /etc/modules
```

For PulseAudio to function, mount a user runtime directory from the host and
expose it to the container. Replace `<uid>` with the ID used for the container
user:

```bash
-v /run/user/<uid>:/run/user/<uid> \
-e XDG_RUNTIME_DIR=/run/user/<uid>
```

These steps ensure the audio system has the necessary devices and runtime
environment when the container starts.

## How It Works

### Audio Architecture

1. **PulseAudio Core**: Container-optimized audio server with virtual devices
2. **Runtime Environment**: Proper user session and permission management
3. **Web Bridge**: Node.js WebSocket audio streaming server
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

For interactive debug tools and self-tests, see [docs/AUDIO_DIAGNOSTICS.md](docs/AUDIO_DIAGNOSTICS.md).

### No Audio in Browser
1. Check that audio bridge is running: `docker logs webtop-kde | grep "Audio bridge"`
2. Enable debug mode by opening `vnc_audio.html?debug=1` to view HUD metrics and WebSocket diagnostics
3. Run the built-in self-test and export the debug report for support
4. Try disconnecting and reconnecting audio
5. Confirm PulseAudio's default sink is set to `virtual_speaker`. The system now automatically resets it, or run `/usr/local/bin/fix-audio-routing.sh` manually

### Audio Bridge Not Starting
1. Check container logs: `docker logs webtop-kde`
2. Verify Node.js installation in container
3. Check if port 8080 is available
4. Use `vnc_audio.html?debug=1` to view WebSocket diagnostics for connection errors

### High Latency
1. Reduce browser audio buffer size (advanced browser settings)
2. Enable debug mode (`vnc_audio.html?debug=1`) to monitor latency and buffer metrics
3. Check network connection quality
4. Consider using SSH with audio forwarding for local network

### Client-side Diagnostics

- **Enable Debug Mode**: Append `?debug=1` to the audio player's URL (e.g., `vnc_audio.html?debug=1`) to display the diagnostic HUD.
- **HUD Metrics**: Review real-time buffer, latency, and connection statistics to identify issues.
- **Self-Tests**: Run the built-in self-tests to validate audio playback and WebSocket connectivity.
- **Debug Report**: Use the export feature to download a debug report for deeper analysis or sharing with support.
- **WebSocket Diagnostics**: Inspect detailed WebSocket connection logs and timing data to troubleshoot network problems.

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

## See Also

- [Audio Diagnostics Guide](docs/AUDIO_DIAGNOSTICS.md)

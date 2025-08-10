# Audio Diagnostics

This guide explains how to debug and validate the WebTop audio pipeline.

## Enable Debug Mode

Append `?debug=1` to the audio player's URL to activate diagnostic tools:

```bash
http://localhost:8080/audio-player.html?debug=1
```

Debug mode displays a heads-up display (HUD) and enables self-test controls.

**Troubleshooting:** If the HUD does not appear, verify the query string and reload the page. Some browsers cache aggressively; use a hard refresh.

## Real-Time HUD Metrics

With debug mode enabled, a floating HUD shows:

- Stream latency and buffer usage
- Sample rate and channel layout
- RMS level meters for speakers and microphone

Use the HUD to monitor audio levels while playing media or speaking.

**Troubleshooting:** If RMS meters stay at zero, confirm that audio is playing and that the correct devices are selected inside the container.

## Built-In Self-Tests

### Beep Test
Produces a short tone to confirm speaker output.

**Usage:** Click **Beep** in the debug panel.

**Troubleshooting:** If no sound is heard, ensure the volume is up and the audio bridge is connected.

### Unlock Audio
Initializes the audio context for browsers that block autoplay.

**Usage:** Click **Unlock Audio** before starting tests.

**Troubleshooting:** If the button has no effect, interact with the page (e.g., click anywhere) and try again. Some browsers require user interaction before sound can play.

### Format Validation
Confirms that the browser accepts the 44.1kHz 16-bit stereo PCM format used by the bridge.

**Usage:** Click **Validate Format**.

**Troubleshooting:** If validation fails, check browser console logs and ensure the browser supports standard PCM streams.

### Loopback Test
Routes microphone input back to the speakers to test end-to-end audio flow.

**Usage:** Click **Loopback** and speak into the microphone.

**Troubleshooting:** If nothing is heard, allow microphone access and verify that a valid input device is selected.

## WebSocket Diagnostics

The debug HUD tracks WebSocket details:

- Connection state (connecting, open, closed)
- Round-trip latency in milliseconds
- Bytes sent and received

**Usage:** Watch the **WebSocket** section of the HUD while audio is streaming.

**Troubleshooting:** High latency or frozen byte counters may indicate network issues or blocked ports. Check browser developer tools and server logs.

## Export Debug Report

Click **Export Report** to download a ZIP containing logs, metrics, and configuration information.

**Usage:**
1. Enable debug mode.
2. Click **Export Report** in the debug panel.

**Troubleshooting:** If no file downloads, allow pop-ups or try a different browser. Ensure the page has permission to trigger downloads.

## See Also

- [Authentication & Security Guide](AUTHENTICATION.md)
- [Multi-Container Deployment Guide](MULTI_CONTAINER.md)
- [Audio System Overview](../README_AUDIO.md)

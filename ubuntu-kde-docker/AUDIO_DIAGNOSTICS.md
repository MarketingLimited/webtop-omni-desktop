# Audio Diagnostics

**📍 This document has been consolidated.**

For comprehensive audio diagnostics and troubleshooting, please see:

**→ [docs/AUDIO_DIAGNOSTICS.md](docs/AUDIO_DIAGNOSTICS.md)**

The detailed guide includes:
- Debug mode activation and HUD metrics
- Built-in self-tests (beep, loopback, format validation)
- WebSocket diagnostics
- Debug report export
- Complete troubleshooting procedures

---

## Quick Reference

For quick container-side audio checks:

```bash
# Run audio validation inside container
./audio-validation.sh

# Test desktop audio playback
./test-desktop-audio.sh

# Reset audio routing if misconfigured
./fix-audio-routing.sh

# Monitor PulseAudio status in real-time
./audio-monitor.sh

# View detailed pipeline information
./debug-audio-pipeline.sh
```

## Related Documentation

- **[Detailed Audio Diagnostics](docs/AUDIO_DIAGNOSTICS.md)** - Client-side browser diagnostics
- **[Audio System Overview](README_AUDIO.md)** - General audio setup and architecture
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Complete troubleshooting procedures

---

**Note:** This stub file replaced a brief 20-line version. The comprehensive 86-line version in `docs/` provides complete diagnostic coverage for both server and client-side audio debugging.

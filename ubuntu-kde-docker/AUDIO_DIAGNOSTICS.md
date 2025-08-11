# Audio Diagnostics Guide

This guide provides commands to verify and troubleshoot the audio pipeline inside the Ubuntu KDE container.

## Quick Checks

- Run `./audio-validation.sh` inside the container to verify virtual audio devices.
- Use `./test-desktop-audio.sh` to play a sample sound.
- Reset routing with `./fix-audio-routing.sh` if devices are misconfigured.

## Monitoring

- `./audio-monitor.sh` shows real-time PulseAudio status.
- `./debug-audio-pipeline.sh` prints detailed pipeline information.

## Related Documentation

- [General Audio Setup](README_AUDIO.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

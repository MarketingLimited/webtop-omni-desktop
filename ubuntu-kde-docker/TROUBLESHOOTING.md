# Advanced Troubleshooting Guide

## Common Issues and Solutions

### 🎵 Audio Issues

#### "No output or input devices found" in KDE
**Cause**: Virtual audio devices not created or PulseAudio misconfigured

**Solution**:
```bash
# Run audio validation
docker exec webtop-kde /usr/local/bin/audio-validation.sh

# If validation fails, restart audio system
docker exec webtop-kde supervisorctl restart pulseaudio
docker exec webtop-kde supervisorctl restart AudioValidation

# Check PulseAudio status
docker exec webtop-kde pactl info
docker exec webtop-kde pactl list short sinks
```

#### Audio not working in applications
**Cause**: Applications not using virtual audio devices

**Solution**:
```bash
# Set default audio device
docker exec webtop-kde pactl set-default-sink virtual_speaker
docker exec webtop-kde pactl set-default-source virtual_microphone

# Test audio in desktop
docker exec webtop-kde /usr/local/bin/test-desktop-audio.sh
```

### 🖥️ Remote Desktop Issues


#### VNC shows black screen
**Cause**: X11VNC not capturing desktop or resolution issues

**Solution**:
```bash
# Check VNC status
docker exec webtop-kde supervisorctl status X11VNC

# Check display resolution
docker exec webtop-kde xrandr

# Restart VNC services
docker exec webtop-kde supervisorctl restart X11VNC noVNC
```

### 💻 Terminal and SSH Issues

#### TTYD web terminal not working
**Cause**: TTYD service failed or authentication issues

**Solution**:
```bash
# Check TTYD status
docker exec webtop-kde supervisorctl status ttyd

# Check TTYD logs
docker exec webtop-kde supervisorctl tail ttyd

# Verify wrapper script exists
docker exec webtop-kde ls -la /usr/local/bin/ttyd-wrapper.sh

# Test port 7681
docker exec webtop-kde netstat -tlnp | grep 7681
```

#### SSH connection refused
**Cause**: SSH service not running or port issues

**Solution**:
```bash
# Check SSH status
docker exec webtop-kde supervisorctl status sshd

# Test SSH port
docker exec webtop-kde netstat -tlnp | grep 22

# Restart SSH
docker exec webtop-kde supervisorctl restart sshd
```

### 🔧 Service Management Issues

#### Services in FATAL state
**Cause**: Service startup failures or missing dependencies

**Solution**:
```bash
# Check all service status
docker exec webtop-kde supervisorctl status

# Check specific service logs
docker exec webtop-kde supervisorctl tail <service-name>

# Clear log and restart
docker exec webtop-kde supervisorctl clear <service-name>
docker exec webtop-kde supervisorctl restart <service-name>
```

#### Services constantly restarting
**Cause**: Configuration issues or resource constraints

**Solution**:
```bash
# Check resource usage
docker exec webtop-kde free -h
docker exec webtop-kde df -h

# Check for memory/disk issues
docker stats webtop-kde

# Review service configuration
docker exec webtop-kde cat /etc/supervisor/conf.d/supervisord.conf
```

### 🏗️ Background Build Issues

#### Background build not starting
**Cause**: Docker daemon issues or resource constraints

**Solution**:
```bash
# Check Docker status
docker info
docker system df

# Check for running builds
docker ps | grep webtop-build

# Clean up and retry
./webtop.sh build-cleanup
./webtop.sh build-bg --dev
```

#### Background build stuck or hanging
**Cause**: Resource limitations or network issues

**Solution**:
```bash
# Check build status
./webtop.sh build-status

# View build logs for errors
./webtop.sh build-logs | tail -50

# Stop stuck build
./webtop.sh build-stop

# Check system resources
docker system df
free -h
```

#### Build fails with resource errors
**Cause**: Insufficient disk space or memory

**Solution**:
```bash
# Check available resources
df -h
free -h

# Clean Docker system
docker system prune -f

# Monitor resource usage during build
watch "docker stats --no-stream"
```

### 🔍 Container Issues

#### Container fails to start
**Cause**: Port conflicts, resource limits, or configuration errors

**Solution**:
```bash
# Check container logs
docker logs webtop-kde

# Check port conflicts
docker ps -a
netstat -tlnp | grep -E "(80|5901|7681|22)"

# Check Docker resources
docker system df
docker system prune

# If build was in background, check build status
./webtop.sh build-status
./webtop.sh build-logs | grep -i error
```

#### Container running but services not accessible
**Cause**: Network issues or firewall blocking

**Solution**:
```bash
# Check container networking
docker exec webtop-kde ip addr
docker exec webtop-kde route -n

# Test internal connectivity
docker exec webtop-kde curl -s http://localhost:80


# Check host networking
curl -s http://localhost:80

```

## Diagnostic Commands

### Full System Diagnosis
```bash
# Complete system validation
docker exec webtop-kde /usr/local/bin/system-validation.sh

# Service health report
docker exec webtop-kde /usr/local/bin/service-health.sh status

# Resource usage report
docker exec webtop-kde /usr/local/bin/monitor-services.sh

# Build system diagnosis
./webtop.sh build-status
./webtop.sh build-logs | grep -i error
docker ps | grep webtop-build
```

### Service-Specific Diagnostics

#### Audio Diagnostics
```bash
# Audio system check
docker exec webtop-kde /usr/local/bin/audio-validation.sh
docker exec webtop-kde /usr/local/bin/audio-monitor.sh check

# PulseAudio details
docker exec webtop-kde pactl info
docker exec webtop-kde pactl list short sinks sources
```

#### Desktop Diagnostics
```bash
# Desktop environment check
docker exec webtop-kde ps aux | grep plasma
docker exec webtop-kde echo $DISPLAY
docker exec webtop-kde xwininfo -root
```

#### Network Diagnostics
```bash
# Port availability
docker exec webtop-kde netstat -tlnp

# Service connectivity
docker exec webtop-kde curl -I http://localhost:80

docker exec webtop-kde curl -I http://localhost:7681
```

## Recovery Procedures

### Complete Service Reset
```bash
# Stop all services
docker exec webtop-kde supervisorctl stop all

# Clear logs
docker exec webtop-kde supervisorctl clear all

# Start services in order
docker exec webtop-kde supervisorctl start Xvfb dbus
sleep 5
docker exec webtop-kde supervisorctl start pulseaudio
sleep 5
docker exec webtop-kde supervisorctl start KDE
sleep 10
docker exec webtop-kde supervisorctl start X11VNC noVNC sshd ttyd
sleep 5
docker exec webtop-kde supervisorctl start SystemValidation
```

### Audio System Reset
```bash
# Reset PulseAudio
docker exec webtop-kde supervisorctl stop pulseaudio AudioValidation AudioMonitor
docker exec webtop-kde killall pulseaudio 2>/dev/null || true
docker exec webtop-kde supervisorctl start pulseaudio
sleep 3
docker exec webtop-kde supervisorctl start AudioValidation AudioMonitor

# Validate audio
docker exec webtop-kde /usr/local/bin/audio-validation.sh
```

### Container Recovery
```bash
# Restart container services
./webtop.sh restart

# Or rebuild if needed
./webtop.sh down
./webtop.sh build
./webtop.sh up

# Background rebuild for minimal downtime
./webtop.sh build-bg --dev
# Monitor until complete
./webtop.sh build-status
# Then restart services
./webtop.sh down && ./webtop.sh up --dev
```

### Build Recovery Procedures
```bash
# Stop any running builds
./webtop.sh build-stop

# Clean up build artifacts
./webtop.sh build-cleanup

# Check and clean Docker system
docker system prune -f

# Start fresh background build
./webtop.sh build-bg --dev

# Monitor progress
watch ./webtop.sh build-status
```

## Performance Optimization

### Resource Monitoring
```bash
# Monitor container resources
docker stats webtop-kde --no-stream

# Check service resource usage
docker exec webtop-kde top -b -n1 | head -20
```

### Service Optimization
```bash
# Reduce audio buffer for better performance
docker exec webtop-kde pactl list short modules | grep module-null-sink

# Optimize display settings
docker exec webtop-kde xrandr --output VNC-0 --mode 1024x768
```

## Emergency Access

### Direct Container Access
```bash
# Shell access (if SSH fails)
docker exec -it webtop-kde /bin/bash

# Root access
docker exec -it --user root webtop-kde /bin/bash
```

### Service Recovery
```bash
# Manual service start
docker exec webtop-kde /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

# Manual desktop start
docker exec webtop-kde su - devuser -c "DISPLAY=:1 /usr/bin/startplasma-x11"
```

---

For validation procedures, see [VALIDATION.md](VALIDATION.md)
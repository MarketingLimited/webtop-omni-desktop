# System Validation Guide

## Overview

The Ubuntu KDE Docker container includes a comprehensive validation system that automatically tests all components after startup and provides detailed health reporting.

## Automatic Validation

### System Validation Service
The container runs automatic validation through the `SystemValidation` service in supervisord:
- **Runs after all services start** (priority 60)
- **Comprehensive component testing**
- **Detailed pass/fail reporting**
- **Automatic health monitoring**

### Validation Components

#### 🎵 Audio System
- **Virtual device creation**: Tests `virtual_speaker` and `virtual_microphone` 
- **PulseAudio integration**: Validates container-compatible audio setup
- **KDE visibility**: Confirms devices appear in System Settings
- **Audio forwarding**: Tests remote access audio routing

#### 🖥️ Remote Desktop Access
- **Xpra stability**: Validates no crash loops, proper desktop attachment
- **VNC accessibility**: Tests noVNC web interface functionality  
- **Port availability**: Confirms 14500 (Xpra) and 80 (VNC) are accessible
- **Desktop integration**: Validates both access methods show KDE desktop

#### 💻 Terminal Services
- **TTYD web terminal**: Tests port 7681 accessibility and authentication
- **SSH access**: Validates port 22 connectivity
- **Authentication**: Tests credential-based access

#### 🔧 Service Health
- **Supervisord services**: Validates all services in RUNNING state
- **Service dependencies**: Tests proper startup order
- **Port listeners**: Confirms all expected ports are active
- **Log health**: Checks for error loops and stability

## Manual Validation Commands

### Full System Validation
```bash
# Complete system validation with detailed report
docker exec webtop-kde /usr/local/bin/system-validation.sh

# Quick health check
docker exec webtop-kde /usr/local/bin/health-check.sh

# Service-specific status
docker exec webtop-kde /usr/local/bin/service-health.sh status
```

### Component-Specific Validation

#### Audio System
```bash
# Audio validation and setup
docker exec webtop-kde /usr/local/bin/audio-validation.sh

# Desktop audio integration test  
docker exec webtop-kde /usr/local/bin/test-desktop-audio.sh

# Continuous audio monitoring
docker exec webtop-kde /usr/local/bin/audio-monitor.sh monitor
```

#### Service Monitoring
```bash
# Real-time service status
docker exec webtop-kde supervisorctl status

# Service logs
docker exec webtop-kde supervisorctl tail -f SystemValidation
docker exec webtop-kde supervisorctl tail -f AudioValidation
```

## Validation Report Interpretation

### ✅ Success Indicators
- **Audio devices visible** in KDE Audio Volume panel
- **All services RUNNING** in supervisord status
- **All ports listening** (80, 5901, 14500, 7681, 22)
- **No FATAL/BACKOFF services**
- **Validation report shows PASS** for all components

### ❌ Failure Indicators
- **"No devices found"** in KDE Audio Volume
- **Service restart loops** in logs
- **Ports not accessible** from host
- **TTYD login failures**
- **Xpra connection refused**

### 🔧 Troubleshooting Failed Validation

#### Audio Issues
```bash
# Reset audio system
docker exec webtop-kde supervisorctl restart pulseaudio
docker exec webtop-kde /usr/local/bin/audio-validation.sh

# Check PulseAudio status
docker exec webtop-kde pactl info
```

#### Service Issues  
```bash
# Restart specific service
docker exec webtop-kde supervisorctl restart <service-name>

# Check service logs
docker exec webtop-kde supervisorctl tail <service-name>
```

#### Network Issues
```bash
# Check port availability
docker exec webtop-kde netstat -tlnp

# Test internal connectivity
docker exec webtop-kde curl -s http://localhost:14500
docker exec webtop-kde curl -s http://localhost:7681
```

## Validation Workflow

### Container Startup Sequence
1. **Core Services** → Xvfb, D-Bus (Priority 10-20)
2. **Audio Setup** → PulseAudio, Virtual devices (Priority 25-30)  
3. **Desktop Environment** → KDE Plasma (Priority 35)
4. **Remote Access** → VNC, noVNC, Xpra, SSH, TTYD (Priority 40-50)
5. **Validation** → System validation and health monitoring (Priority 60)

### Expected Timeline
- **Services start**: 30-60 seconds
- **Desktop ready**: 60-90 seconds  
- **Validation complete**: 90-120 seconds
- **Full system ready**: 2-3 minutes

## Advanced Validation

### Custom Validation Scripts
Create custom validation for specific use cases:

```bash
#!/bin/bash
# Custom marketing agency validation

# Test specific applications
docker exec webtop-kde which gimp && echo "✅ GIMP installed"
docker exec webtop-kde which kdenlive && echo "✅ Kdenlive installed"

# Test web app shortcuts
docker exec webtop-kde ls /home/devuser/Desktop/*.desktop | wc -l
```

### Integration Testing
```bash
# Test complete workflow
docker exec webtop-kde /usr/local/bin/system-validation.sh full

# Test specific use case
docker exec webtop-kde /usr/local/bin/system-validation.sh audio
docker exec webtop-kde /usr/local/bin/system-validation.sh desktop
```

## Performance Monitoring

### Resource Validation
```bash
# Check resource usage
docker exec webtop-kde free -h
docker exec webtop-kde df -h

# Monitor service performance
docker exec webtop-kde top -b -n1 | head -20
```

### Continuous Monitoring
```bash
# Set up monitoring (if prometheus enabled)
docker exec webtop-kde /usr/local/bin/monitor-services.sh

# Check metrics
curl http://localhost:9090/metrics
```

---

For additional troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
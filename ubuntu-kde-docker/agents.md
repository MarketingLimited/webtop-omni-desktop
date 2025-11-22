# Container Desktop Module - Ubuntu KDE Environment

## 1. Purpose (الغرض)

هذا الـ module يحتوي على **بيئة desktop كاملة** (Ubuntu 24.04 + KDE Plasma) تعمل داخل Docker container، مع 50+ أداة مثبتة مسبقاً، ويمكن الوصول إليها عبر المتصفح باستخدام noVNC.

**الميزات الرئيسية**:
- ✅ Full KDE Plasma desktop environment
- ✅ Real-time audio streaming (PulseAudio → WebSocket → Browser)
- ✅ Remote access عبر noVNC, SSH, TTYD web terminal
- ✅ 50+ pre-installed development tools
- ✅ Multi-container orchestration للـ isolated client environments
- ✅ Backup/restore functionality
- ✅ Automated health monitoring
- ✅ Windows app support (Wine + PlayOnLinux)
- ✅ Android app support (Waydroid)
- ✅ Creative suite (GIMP, Inkscape, Blender, OBS Studio, etc.)

**الاستخدام المستهدف**: Marketing agencies تحتاج isolated desktop environments لعدة clients.

---

## 2. Owned Scope (النطاق المملوك)

### A) Container Definition:

**Core Files**:
- `Dockerfile` - Multi-stage container build (Ubuntu 24.04 base)
- `docker-compose.yml` - Default deployment config (desktop only)
- `docker-compose.dev.yml` - Development environment (+ Redis + PostgreSQL)
- `docker-compose.prod.yml` - Production deployment config
- `.env.example` - Environment variables template (passwords, ports, users)
- `entrypoint.sh` - Container startup script
- `supervisord.conf` - Service orchestration (15+ services)

**Container Registry**:
- `.container-registry.json` - Multi-container tracking database

---

### B) Setup & Installation Scripts (30+):

**Audio System**:
- `setup-audio-bridge.sh` - WebSocket audio bridge setup
- `setup-audio.sh` - PulseAudio configuration
- `integrate-audio-ui.sh` - Audio UI integration
- `universal-audio.js` - Client-side audio manager (browser)
- `pulse-ensure.sh` - PulseAudio virtual device creation
- `pulse-daemon.sh` - PulseAudio daemon startup
- `setup-pulse-tcp.sh` - PulseAudio TCP module setup

**Development Tools**:
- `setup-development.sh` - Dev tools installation (Node, Python, PHP, Ruby, Go, Java)
- `setup-vscode.sh` - VS Code installation
- `setup-databases.sh` - Database clients (PostgreSQL, MySQL, Redis, DBeaver)
- `setup-docker.sh` - Docker & Docker Compose installation

**Creative Tools**:
- `setup-graphics.sh` - GIMP, Inkscape, Krita
- `setup-video-editing.sh` - Kdenlive, OBS Studio
- `setup-3d.sh` - Blender, FreeCAD
- `setup-cad.sh` - LibreCAD, FreeCAD

**Cross-Platform Apps**:
- `setup-wine.sh` - Windows app support (Wine + PlayOnLinux)
- `setup-waydroid.sh` - Android app support
- `setup-flatpak.sh` - Flatpak package manager

**Browsers**:
- `setup-browsers.sh` - Multiple browsers (Chrome, Brave, Opera)

**Utilities**:
- `setup-utilities.sh` - General utilities
- `setup-terminal.sh` - Terminal customization
- `setup-fonts.sh` - Font installation
- `setup-themes.sh` - KDE themes
- `setup-networking.sh` - Network tools

---

### C) Management & Orchestration:

**Main CLI**:
- `webtop.sh` - Container management CLI (19,421 bytes):
  - Container lifecycle (create, start, stop, restart, remove)
  - Multi-container orchestration
  - Backup/restore functionality
  - Port management
  - Status monitoring
  - Log access

---

### D) Monitoring & Health Checks:

**Health Scripts**:
- `health-check.sh` - System health check
- `service-health.sh` - Service health monitoring (smart-monitor mode)
- `audio-validation.sh` - Audio system validation
- `audio-monitor.sh` - Continuous audio monitoring
- `system-validation.sh` - System validation

**Diagnostic Scripts**:
- `diagnostic-script.sh` - Comprehensive diagnostics (runs on startup)

---

### E) Helper Scripts:

**Wrappers & Utilities**:
- `ttyd-wrapper.sh` - TTYD web terminal wrapper
- Various helper scripts للـ specific services

---

### F) Data Persistence:

**Docker Volumes** (mapped to `/data/<container-name>/`):
```
config/              # User home directory, settings, application data
var/log/supervisor/  # Service logs
tmp/.X11-unix/       # X11 display sockets
```

---

## 3. Key Files & Entry Points

### Container Startup Flow:

```
docker-compose up
  ↓
Dockerfile (image build if needed)
  ↓
entrypoint.sh (container startup)
  ↓
/opt/diagnostic-script.sh (health check)
  ↓
supervisord (process manager)
  ↓
Managed Services (15+ services in priority order):

Priority 10: Display Layer
  └── Xvfb (virtual display :1, 1920x1080x24)

Priority 15: System Services
  ├── D-Bus (inter-process communication)
  └── accounts-daemon (user account management)

Priority 20-26: Audio System
  ├── SetupPulseTCP (PulseAudio TCP module - priority 20)
  ├── SetupPulseAudio (one-time setup - priority 22)
  ├── PulseAudioDaemon (audio server - priority 23)
  ├── CreateVirtualAudioDevices (priority 26)
  └── AudioValidation (validation - priority 26)
  └── AudioMonitor (continuous monitoring - priority 27)

Priority 30: Desktop Environment
  └── KDE (Plasma desktop - startplasma-x11)

Priority 35-45: Remote Access
  ├── X11VNC (VNC server on port 5901 - priority 35)
  ├── noVNC (web interface on port 80 - priority 37)
  ├── sshd (SSH server - priority 42)
  └── ttyd (web terminal - priority 45)

Priority 50-60: Additional Services & Monitoring
  ├── SetupDesktop (one-time desktop customization)
  └── ServiceHealth (smart health monitor - priority 55)
```

### Supervisord Configuration:

**File**: `supervisord.conf`

**Service Definition Example**:
```ini
[program:KDE]
command=/bin/sh -c "sleep 15; export DISPLAY=:1; ... exec startplasma-x11"
priority=30                              # Start order
autostart=true                           # Auto-start on boot
autorestart=true                         # Restart on crash
user=%(ENV_DEV_USERNAME)s                # Run as dev user
environment=DISPLAY=:1,HOME=/home/...    # Environment variables
startsecs=15                             # Wait 15s before considering started
startretries=2                           # Retry 2 times on failure
stdout_logfile=/var/log/supervisor/kde.log
```

**Key Environment Variables** (from `docker-compose.yml`):
```yaml
DEV_USERNAME: devuser
DEV_PASSWORD: DevPassw0rd!
DEV_UID: 1000
DEV_GID: 1000
DISPLAY: :1
VNC_PORT: 80
SSH_PORT: 2222
TTYD_PORT: 7681
```

---

### Access Points:

#### 1. noVNC (Browser VNC Client):
```
URL: http://localhost:32768
Service: websockify proxying to X11VNC
Display: Full KDE Plasma desktop
Controls: Mouse, keyboard via browser
```

#### 2. SSH:
```bash
ssh devuser@localhost -p 2222
Password: DevPassw0rd! (من .env)
Shell: /bin/bash
```

#### 3. TTYD (Web Terminal):
```
URL: http://localhost:7681
Auth: Basic (terminal:terminal by default)
Shell: Interactive bash terminal
```

#### 4. Audio WebSocket:
```
URL: ws://localhost:8080
Protocol: WebSocket (binary audio stream)
Client: universal-audio.js (browser)
Format: PCM audio from PulseAudio
```

#### 5. PulseAudio TCP:
```
URL: tcp://localhost:4713
Protocol: PulseAudio native protocol
Usage: For advanced audio clients
```

---

## 4. Dependencies & Interfaces

### System Dependencies (في Container):

**Base System**:
- Ubuntu 24.04 LTS
- KDE Plasma desktop environment
- X11 display server (via Xvfb)

**Runtime Services**:
- Supervisord - process management
- D-Bus - inter-process communication
- PolicyKit - privilege escalation
- systemd components (minimal)

**Display & Remote Access**:
- Xvfb - virtual framebuffer (X11 display :1)
- X11VNC - VNC server
- noVNC - HTML5 VNC client
- websockify - WebSocket proxy

**Audio System**:
- PulseAudio - audio server
- Node.js 22 - للـ Audio Bridge WebSocket server
- Express 4.18.2 - web framework
- ws 8.14.2 - WebSocket library

**Terminal Access**:
- OpenSSH server
- TTYD - web terminal

---

### Pre-installed Development Tools:

**Languages & Runtimes**:
```
Node.js 22         # JavaScript/TypeScript runtime
Python 3.12        # Python interpreter + pip
PHP 8.3            # PHP interpreter + composer
Ruby 3.2           # Ruby interpreter + gem
Go 1.21            # Go compiler
Java 21 (OpenJDK)  # Java runtime + maven
```

**Databases & Clients**:
```
PostgreSQL client  # psql
MySQL client       # mysql
Redis CLI          # redis-cli
DBeaver CE         # Universal database GUI
```

**IDEs & Editors**:
```
VS Code            # Full IDE
vim                # Terminal editor
nano               # Simple editor
```

**Version Control**:
```
Git                # Version control
GitHub CLI (gh)    # GitHub integration
```

**Containerization**:
```
Docker Engine      # Container runtime
Docker Compose     # Multi-container orchestration
```

**Browsers**:
```
Google Chrome      # Chromium-based
Brave Browser      # Privacy-focused
Opera Browser      # Feature-rich
Firefox            # Pre-installed with KDE
```

**Creative Suite**:
```
GIMP               # Image editing
Inkscape           # Vector graphics
Krita              # Digital painting
Blender            # 3D modeling & animation
FreeCAD            # CAD design
LibreCAD           # 2D CAD
Kdenlive           # Video editing
OBS Studio         # Screen recording & streaming
Audacity           # Audio editing
```

**Cross-Platform Support**:
```
Wine               # Windows app layer
PlayOnLinux        # Wine GUI manager
Waydroid           # Android app support
Flatpak            # Universal app packages
```

**Network Tools**:
```
curl, wget         # HTTP clients
netcat, telnet     # Network utilities
traceroute, ping   # Diagnostics
```

---

### External Interfaces:

#### Host System:
```yaml
# Port mappings (docker-compose.yml)
Ports:
  - "32768:80"     # noVNC web interface
  - "2222:22"      # SSH server
  - "7681:7681"    # TTYD web terminal
  - "8080:8080"    # Audio WebSocket bridge
  - "4713:4713"    # PulseAudio TCP (optional)

Volumes:
  - /data/ubuntu-kde-docker_webtop/config:/home/${DEV_USERNAME}
  - /data/ubuntu-kde-docker_webtop/var/log/supervisor:/var/log/supervisor
  - /data/ubuntu-kde-docker_webtop/tmp/.X11-unix:/tmp/.X11-unix

Capabilities:
  - SYS_ADMIN      # For containerization features
  - NET_ADMIN      # For network management

Security:
  - seccomp:unconfined
```

#### Development Environment (`docker-compose.dev.yml`):
```yaml
Additional Services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes: [redis_data]

  postgres:
    image: postgres:15-alpine
    ports: ["5432:5432"]
    environment:
      POSTGRES_DB: marketing_agency
      POSTGRES_USER: marketing_user
      POSTGRES_PASSWORD: secure_password
    volumes: [postgres_data]
```

---

## 5. Local Rules / Patterns

### Development Patterns:

#### 1. Adding New Tools:

**Pattern**:
```bash
# 1. Create setup script
cat > setup-newtool.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing NewTool..."
apt-get update
apt-get install -y newtool

# Configure
# ...

echo "NewTool installed successfully"
EOF

chmod +x setup-newtool.sh

# 2. Add to Dockerfile
# Add RUN statement:
RUN /path/to/setup-newtool.sh

# 3. Rebuild
docker-compose build
```

#### 2. Adding Supervisord Service:

**Pattern**:
```ini
# Add to supervisord.conf

[program:NewService]
command=/usr/bin/newservice --args
priority=XX                    # Choose appropriate priority
autostart=true
autorestart=true
stopsignal=TERM
user=root                      # or %(ENV_DEV_USERNAME)s
startsecs=5
startretries=3
stdout_logfile=/var/log/supervisor/newservice.log
stderr_logfile=/var/log/supervisor/newservice.log
```

**Priority Guidelines**:
- 10-19: Display & core system (Xvfb, etc.)
- 20-29: Audio system
- 30-34: Desktop environment
- 35-49: Remote access & utilities
- 50-59: Monitoring & health checks
- 60+: User services

#### 3. Environment Variables:

**Pattern**:
```bash
# 1. Add to .env.example with documentation
NEW_VAR=default_value  # Description of what it does

# 2. Add to docker-compose.yml
environment:
  - NEW_VAR=${NEW_VAR}

# 3. Use في scripts
echo "Value: ${NEW_VAR}"

# 4. Use في supervisord.conf
environment=NEW_VAR=%(ENV_NEW_VAR)s
```

#### 4. Audio System Extension:

**Pattern** (إضافة audio source جديد):
```bash
# في setup-audio-bridge.sh أو script منفصل

# 1. Create PulseAudio virtual device
pactl load-module module-null-sink \
  sink_name=my_sink \
  sink_properties=device.description="My_Audio_Sink"

# 2. Create monitor source
pactl load-module module-remap-source \
  source_name=my_sink.monitor \
  master=my_sink.monitor

# 3. Update audio bridge server to handle new source
# Edit /opt/audio-bridge/server.js
```

---

### Coding Standards:

#### Bash Scripts:
```bash
#!/bin/bash
set -e                          # Exit on error
set -u                          # Exit on undefined variable
# set -x                        # Debug mode (uncomment when needed)

# Variables في UPPERCASE
INSTALL_DIR="/opt/myapp"
CONFIG_FILE="/etc/myapp/config"

# Functions في lowercase
function install_package() {
    local package_name=$1
    echo "Installing ${package_name}..."
    apt-get install -y "${package_name}"
}

# Error handling
if [ ! -d "${INSTALL_DIR}" ]; then
    echo "Error: Directory not found"
    exit 1
fi

# Logging
echo "$(date '+%Y-%m-%d %H:%M:%S') - Operation completed"
```

#### Supervisord Programs:
```ini
# Naming: [program:ServiceName] (CamelCase)
# Priority: Logical grouping
# Logs: Always to /var/log/supervisor/
# User: root للـ system services, DEV_USERNAME للـ user apps
# Autorestart: true للـ daemons, false للـ one-time setup
# Startsecs: Realistic grace period
# Startretries: 2-3 للـ critical services
```

---

### File Organization:

```
ubuntu-kde-docker/
├── Dockerfile                   # Main container definition
├── docker-compose*.yml          # Deployment configs
├── .env.example                 # Template (NEVER commit .env)
├── entrypoint.sh                # Container startup
├── supervisord.conf             # Service orchestration
├── webtop.sh                    # Management CLI
│
├── setup-*.sh                   # Installation scripts (30+)
│   ├── setup-audio*.sh          # Audio system
│   ├── setup-development.sh     # Dev tools
│   ├── setup-*.sh               # Feature-specific
│   └── ...
│
├── *-health*.sh                 # Health & monitoring
├── *-validation*.sh             # Validation scripts
├── *-monitor*.sh                # Monitoring scripts
│
├── universal-audio.js           # Client-side audio
├── .container-registry.json     # Container tracking
│
└── docs/                        # Technical documentation
    ├── README.md
    ├── AUTHENTICATION.md
    ├── AUDIO_DIAGNOSTICS.md
    ├── MULTI_CONTAINER.md
    └── ...
```

---

## 6. How to Run / Test

### Initial Setup:

```bash
cd ubuntu-kde-docker

# 1. Copy environment template
cp .env.example .env

# 2. Edit .env - IMPORTANT: Change passwords!
nano .env
# Set:
# - DEV_USERNAME, DEV_PASSWORD
# - ADMIN_USERNAME, ADMIN_PASSWORD
# - ROOT_PASSWORD
# - TTYD_USER, TTYD_PASSWORD

# 3. Build container image (first time - takes 20-30 min)
docker-compose build

# 4. Start container
docker-compose up -d

# 5. Check status
docker-compose ps
./webtop.sh status

# 6. View logs
docker-compose logs -f

# 7. Access desktop
# Open browser: http://localhost:32768
# Login with DEV_USERNAME/DEV_PASSWORD
```

---

### Development Environment (with Redis + PostgreSQL):

```bash
cd ubuntu-kde-docker

# Start dev environment
docker-compose -f docker-compose.dev.yml up -d

# Services available:
# - Desktop: http://localhost:32768
# - Redis: localhost:6379
# - PostgreSQL: localhost:5432
#   - Database: marketing_agency
#   - User: marketing_user
#   - Password: (check docker-compose.dev.yml)

# Stop dev environment
docker-compose -f docker-compose.dev.yml down
```

---

### Testing & Validation:

#### 1. System Health Check:
```bash
# Run diagnostic script
docker-compose exec webtop /opt/diagnostic-script.sh

# Check service health
docker-compose exec webtop /usr/local/bin/service-health.sh check-all

# View service status
docker-compose exec webtop supervisorctl status
```

#### 2. Audio System Validation:
```bash
# Run audio validation
docker-compose exec webtop /usr/local/bin/audio-validation.sh

# Check PulseAudio
docker-compose exec webtop pactl info

# List audio sinks/sources
docker-compose exec webtop pactl list sinks short
docker-compose exec webtop pactl list sources short

# Test audio in browser
# 1. Open: http://localhost:32768
# 2. Open browser DevTools console (F12)
# 3. Check for WebSocket connection to ws://localhost:8080
# 4. Play audio in desktop (e.g., YouTube)
# 5. Verify audio plays in browser
```

#### 3. Service Logs:
```bash
# Container logs
docker-compose logs -f

# Specific service logs
docker-compose exec webtop tail -f /var/log/supervisor/kde.log
docker-compose exec webtop tail -f /var/log/supervisor/pulseaudio.log
docker-compose exec webtop tail -f /var/log/supervisor/x11vnc.log

# All supervisor logs
docker-compose exec webtop ls /var/log/supervisor/
```

#### 4. Interactive Debugging:
```bash
# SSH into container
ssh devuser@localhost -p 2222
# Password: (from .env)

# Or use docker exec as root
docker-compose exec webtop bash

# Or use TTYD web terminal
# Open: http://localhost:7681
```

#### 5. Network Connectivity:
```bash
# Check exposed ports
docker-compose ps
netstat -tuln | grep -E "(32768|2222|7681|8080|4713)"

# Test VNC connection
curl -I http://localhost:32768

# Test SSH
ssh -p 2222 devuser@localhost echo "SSH OK"

# Test WebSocket (requires wscat)
npm install -g wscat
wscat -c ws://localhost:8080
```

---

### Multi-Container Testing:

```bash
cd ubuntu-kde-docker

# Create second container for different client
./webtop.sh create-container client2

# List all containers
./webtop.sh list

# Start specific container
./webtop.sh start client2

# Check status of all
./webtop.sh status

# Access client2 (ports auto-incremented)
# noVNC: http://localhost:32769
# SSH: ssh devuser@localhost -p 2223

# Stop specific container
./webtop.sh stop client2

# Remove container
./webtop.sh remove client2
```

---

### Backup & Restore:

```bash
cd ubuntu-kde-docker

# Backup container data
./webtop.sh backup webtop /backups/webtop-$(date +%Y%m%d).tar.gz

# Restore from backup
./webtop.sh restore webtop /backups/webtop-20250122.tar.gz

# Backup includes:
# - User home directory (/home/devuser)
# - Application data
# - Settings and preferences
# - Logs
```

---

## 7. Common Tasks for Agents

### Task 1: إضافة أداة تطوير جديدة

```bash
cd ubuntu-kde-docker

# 1. Create setup script
cat > setup-rust.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing Rust toolchain..."

# Install rustup
su - ${DEV_USERNAME} -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"

# Add to PATH
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/${DEV_USERNAME}/.bashrc

echo "Rust installed successfully"
rustc --version || true
EOF

chmod +x setup-rust.sh

# 2. Add to Dockerfile (before final layers)
# Add line:
# RUN /path/to/setup-rust.sh

# Edit Dockerfile
nano Dockerfile
# Add after other setup-*.sh calls:
# RUN bash /usr/local/bin/setup-rust.sh

# 3. Copy script في Dockerfile
# Add before RUN:
# COPY setup-rust.sh /usr/local/bin/

# 4. Rebuild container
docker-compose build

# 5. Test
docker-compose up -d
docker-compose exec webtop bash
$ rustc --version
```

---

### Task 2: تعديل Audio Configuration

```bash
cd ubuntu-kde-docker

# 1. Edit audio bridge setup
nano setup-audio-bridge.sh

# 2. Modify PulseAudio config
nano setup-audio.sh

# 3. Update client-side audio
nano universal-audio.js

# 4. Rebuild
docker-compose build

# 5. Restart container
docker-compose down
docker-compose up -d

# 6. Validate audio
docker-compose exec webtop /usr/local/bin/audio-validation.sh

# 7. Test in browser
# Open: http://localhost:32768
# Check browser console for WebSocket connection
# Play audio and verify streaming
```

---

### Task 3: تخصيص KDE Desktop

```bash
cd ubuntu-kde-docker

# 1. Create desktop customization script
cat > setup-kde-custom.sh << 'EOF'
#!/bin/bash
set -e

USERNAME=${1:-devuser}

# Install additional KDE themes
apt-get update
apt-get install -y kde-config-gtk-style breeze-gtk-theme

# Configure default settings
mkdir -p /home/${USERNAME}/.config

# Set dark theme
cat > /home/${USERNAME}/.config/kdeglobals << 'KDECFG'
[General]
ColorScheme=BreezeDark
KDECFG

chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config

echo "KDE customization complete"
EOF

chmod +x setup-kde-custom.sh

# 2. Add to Dockerfile
# Add supervisord program for one-time setup

# 3. Or run manually in running container
docker-compose exec webtop /path/to/setup-kde-custom.sh devuser

# 4. Restart KDE
docker-compose exec webtop supervisorctl restart KDE
```

---

### Task 4: إضافة Monitoring Metric جديد

```bash
cd ubuntu-kde-docker

# 1. Edit service-health.sh
nano service-health.sh

# Add new check function:
check_new_service() {
    local service_name="newservice"

    if supervisorctl status ${service_name} | grep -q RUNNING; then
        echo "✓ ${service_name} is running"
        return 0
    else
        echo "✗ ${service_name} is not running"
        return 1
    fi
}

# Add to main check loop
check_new_service

# 2. Test health check
docker-compose exec webtop /usr/local/bin/service-health.sh check-all
```

---

### Task 5: Port Configuration للـ Multi-Container

```bash
cd ubuntu-kde-docker

# Edit webtop.sh
nano webtop.sh

# Locate port assignment logic
# Modify base ports or increment logic

# Or use environment variables
# Edit .env for specific container
VNC_PORT=32770
SSH_PORT=2224
TTYD_PORT=7683
AUDIO_PORT=8082

# Restart container with new ports
docker-compose down
docker-compose up -d
```

---

### Task 6: Database Integration

```bash
cd ubuntu-kde-docker

# 1. Start dev environment (includes PostgreSQL)
docker-compose -f docker-compose.dev.yml up -d

# 2. Connect from container
docker-compose exec webtop bash

# Install application database dependencies
npm install pg  # Node.js PostgreSQL client
# or
pip install psycopg2  # Python PostgreSQL client

# 3. Connection string
DATABASE_URL="postgresql://marketing_user:secure_password@postgres:5432/marketing_agency"

# 4. Test connection
docker-compose exec postgres psql -U marketing_user -d marketing_agency
```

---

### Task 7: Security Hardening

```bash
cd ubuntu-kde-docker

# 1. Change default passwords في .env
nano .env

# Generate strong passwords
openssl rand -base64 32

# Update:
DEV_PASSWORD=<strong-password>
ADMIN_PASSWORD=<strong-password>
ROOT_PASSWORD=<strong-password>
TTYD_PASSWORD=<strong-password>

# 2. Enable HTTP authentication for VNC
VNC_AUTH_ENABLED=true
VNC_USERS="client1:$(openssl rand -base64 16),admin:$(openssl rand -base64 16)"

# 3. Restrict network access
# Edit docker-compose.yml
# Change:
ports:
  - "127.0.0.1:32768:80"  # Bind to localhost only
  - "127.0.0.1:2222:22"

# 4. Use reverse proxy (nginx) with SSL
# Create nginx config for HTTPS termination

# 5. Rebuild and restart
docker-compose build
docker-compose down
docker-compose up -d
```

---

### Task 8: Troubleshooting Services

```bash
cd ubuntu-kde-docker

# 1. Check overall status
./webtop.sh status
docker-compose ps

# 2. Check specific service
docker-compose exec webtop supervisorctl status KDE
docker-compose exec webtop supervisorctl status PulseAudioDaemon

# 3. Restart failed service
docker-compose exec webtop supervisorctl restart KDE

# 4. View logs
docker-compose exec webtop tail -100 /var/log/supervisor/kde.log

# 5. Check X display
docker-compose exec webtop echo $DISPLAY
docker-compose exec webtop xdpyinfo -display :1

# 6. Audio troubleshooting
docker-compose exec webtop /usr/local/bin/audio-validation.sh
docker-compose exec webtop pactl info
docker-compose exec webtop pactl list sinks

# 7. Interactive debugging
docker-compose exec webtop bash
# Run commands manually to diagnose issue
```

---

### Task 9: Performance Optimization

```bash
cd ubuntu-kde-docker

# 1. Adjust Xvfb resolution
# Edit supervisord.conf
# Change Xvfb command:
command=/usr/bin/Xvfb :1 -screen 0 1280x720x16 -dpi 96 ...
# Lower resolution & color depth = better performance

# 2. Disable visual effects في KDE
# Run in container:
docker-compose exec -u devuser webtop bash
$ kwriteconfig5 --file kwinrc --group Compositing --key Enabled false

# 3. Adjust resource limits
# Edit docker-compose.yml
services:
  webtop:
    cpus: 2.0              # Limit CPU cores
    mem_limit: 4g          # Limit RAM
    memswap_limit: 4g      # Disable swap

# 4. Optimize audio latency
# Edit setup-audio-bridge.sh
# Adjust buffer sizes

# 5. Restart
docker-compose down
docker-compose up -d
```

---

## 8. Notes / Gotchas

### ⚠️ Critical Notes:

#### 1. **Security - Change Default Passwords!**
```bash
# .env.example contains development passwords
# NEVER use في production!
# Generate strong passwords:
openssl rand -base64 32
```

#### 2. **Container Build Time**:
- First build: **20-30 minutes** (installs 50+ apps)
- Subsequent builds: faster (Docker layer caching)
- Tip: Don't modify early Dockerfile layers unnecessarily

#### 3. **Port Conflicts**:
```bash
# Default ports may be in use
# Check before starting:
netstat -tuln | grep -E "(32768|2222|7681|8080|4713)"

# Change ports في docker-compose.yml:
ports:
  - "33000:80"  # Use different host port
```

#### 4. **Audio System**:
- **Startup Order Critical**: PulseAudio (priority 23) → Audio Bridge (if added) → KDE (priority 30)
- PulseAudio يجب أن يعمل **قبل** KDE يبدأ
- Audio Bridge يحتاج PulseAudio virtual devices
- Check logs: `/var/log/supervisor/pulseaudio.log`

#### 5. **Supervisord Priorities**:
```
10-19: Core system (Xvfb, D-Bus)
20-29: Audio
30-34: Desktop
35-49: Remote access
50+:   Monitoring
```
- **Don't violate order**: Desktop قبل audio = مشاكل
- **Grace periods**: use `sleep` في commands للخدمات التي تحتاج dependencies

#### 6. **User Permissions**:
```bash
# DEV_UID/DEV_GID يجب أن تتطابق مع host
# للـ volume permissions
# Default: 1000:1000

# Check host user:
id
# uid=1000(youruser) gid=1000(youruser)

# Update في .env:
DEV_UID=1000
DEV_GID=1000
```

#### 7. **Container Capabilities**:
```yaml
cap_add:
  - SYS_ADMIN  # Required for: mount, cgroups, namespaces
  - NET_ADMIN  # Required for: network config, VPN
security_opt:
  - seccomp:unconfined  # Required for: syscalls
```
- **Security tradeoff**: These are permissive
- **Mitigation**: Use network isolation, don't expose ports publicly

#### 8. **Volume Persistence**:
```bash
# Data persists في /data/ on host
# Even if container is removed, data remains
# To completely clean:
docker-compose down -v  # WARNING: Deletes volumes!
```

#### 9. **X11 Display Issues**:
```bash
# If KDE doesn't start:
# 1. Check Xvfb is running
docker-compose exec webtop supervisorctl status Xvfb

# 2. Check DISPLAY variable
docker-compose exec webtop echo $DISPLAY
# Should be: :1

# 3. Test X connection
docker-compose exec webtop xdpyinfo -display :1

# 4. Check KDE logs
docker-compose exec webtop tail -100 /var/log/supervisor/kde.log
```

#### 10. **noVNC Connection Issues**:
```bash
# If browser can't connect:
# 1. Check VNC server
docker-compose exec webtop supervisorctl status X11VNC

# 2. Check noVNC
docker-compose exec webtop supervisorctl status noVNC

# 3. Check port mapping
docker-compose ps
# Should show: 0.0.0.0:32768->80/tcp

# 4. Test from host
curl http://localhost:32768
# Should return HTML

# 5. Check firewall
sudo iptables -L -n | grep 32768
```

#### 11. **Multi-Container Port Management**:
```bash
# webtop.sh auto-increments ports
# Base ports:
# - noVNC: 32768, 32769, 32770...
# - SSH: 2222, 2223, 2224...
# - TTYD: 7681, 7682, 7683...
# - Audio: 8080, 8081, 8082...

# Track containers:
cat .container-registry.json
```

#### 12. **Memory Usage**:
```bash
# Full desktop environment = memory intensive
# Minimum: 2GB RAM
# Recommended: 4GB+ RAM per container
# Multiple containers: Plan accordingly

# Check usage:
docker stats webtop
```

#### 13. **Wine & Windows Apps**:
```bash
# Wine setup:
docker-compose exec -u devuser webtop bash
$ wine --version
$ winecfg  # Configure Wine

# Install Windows app:
$ wine setup.exe

# Not all Windows apps work
# Test compatibility first
```

#### 14. **Waydroid & Android Apps**:
```bash
# Waydroid requires kernel modules
# May not work on all hosts
# Check compatibility:
docker-compose exec webtop waydroid status

# Initialize (first time):
docker-compose exec webtop waydroid init

# Start:
docker-compose exec webtop waydroid session start
```

#### 15. **Development vs Production**:
```bash
# Development (docker-compose.dev.yml):
# + Redis, PostgreSQL
# + Development tools
# + Debug logs
# - Less secure defaults

# Production (docker-compose.yml or .prod.yml):
# - Minimal services
# - Optimized settings
# + Secure defaults
# + Resource limits
```

#### 16. **Backup Strategy**:
```bash
# Regular backups recommended:
./webtop.sh backup webtop /backups/daily-$(date +%Y%m%d).tar.gz

# Backup includes:
# ✓ User home directory
# ✓ Application data
# ✓ Settings
# ✓ Logs

# Does NOT include:
# ✗ Docker image (rebuild from Dockerfile)
# ✗ System packages (reinstall)
```

#### 17. **Logging Best Practices**:
```bash
# Logs في /var/log/supervisor/
# Can grow large over time

# Rotate logs:
docker-compose exec webtop bash
$ logrotate /etc/logrotate.conf

# Or clean old logs:
$ find /var/log/supervisor/ -name "*.log" -mtime +7 -delete
```

#### 18. **Network Performance**:
```bash
# noVNC bandwidth intensive
# Especially with high resolution / color depth
# Optimize:
# 1. Lower Xvfb resolution
# 2. Use compression (noVNC settings)
# 3. Local network preferred over internet
```

#### 19. **Debugging Supervisord**:
```bash
# Interactive supervisorctl
docker-compose exec webtop supervisorctl

> status              # Show all services
> tail KDE            # View recent logs
> restart KDE         # Restart service
> stop KDE            # Stop service
> start KDE           # Start service
> reread              # Reload config
> update              # Apply config changes
> exit
```

#### 20. **Update Strategy**:
```bash
# Update system packages:
docker-compose exec webtop bash
$ apt-get update
$ apt-get upgrade -y

# Or rebuild with updates:
docker-compose build --no-cache
docker-compose down
docker-compose up -d

# Backup before major updates!
```

---

## Quick Reference Card

### Essential Commands:

```bash
# Start/Stop
docker-compose up -d              # Start container
docker-compose down               # Stop container
docker-compose restart            # Restart container

# Status & Logs
docker-compose ps                 # Container status
docker-compose logs -f            # Follow logs
./webtop.sh status                # Detailed status

# Access
# Browser: http://localhost:32768   (noVNC)
ssh devuser@localhost -p 2222      # SSH
# Browser: http://localhost:7681    (TTYD)

# Management
./webtop.sh create-container <name>  # Create new container
./webtop.sh list                     # List all containers
./webtop.sh backup <name> <path>     # Backup container
./webtop.sh restore <name> <path>    # Restore backup

# Debugging
docker-compose exec webtop bash                      # Interactive shell
docker-compose exec webtop supervisorctl status      # Service status
docker-compose exec webtop /opt/diagnostic-script.sh # Health check

# Audio
docker-compose exec webtop /usr/local/bin/audio-validation.sh  # Validate audio
docker-compose exec webtop pactl list sinks short              # List audio devices
```

---

### File Locations:

```
Container Paths:
/opt/diagnostic-script.sh              # Startup diagnostics
/usr/local/bin/                        # Custom scripts (health, audio, etc.)
/opt/audio-bridge/server.js            # Audio WebSocket server
/var/log/supervisor/                   # Service logs
/home/${DEV_USERNAME}/                 # User home (persisted)
/etc/supervisor/conf.d/supervisord.conf # Supervisord config

Host Paths:
/data/ubuntu-kde-docker_webtop/config/               # User data
/data/ubuntu-kde-docker_webtop/var/log/supervisor/   # Logs
```

---

### Service Priorities (Supervisord):

```
10  - Xvfb (display)
15  - D-Bus, accounts-daemon
20  - SetupPulseTCP
22  - SetupPulseAudio (one-time)
23  - PulseAudioDaemon
26  - CreateVirtualAudioDevices, AudioValidation
27  - AudioMonitor
30  - KDE (desktop)
35  - X11VNC
37  - noVNC
42  - sshd
45  - ttyd
55  - ServiceHealth
```

---

### Environment Variables (.env):

```bash
# User accounts
DEV_USERNAME=devuser
DEV_PASSWORD=DevPassw0rd!
DEV_UID=1000
DEV_GID=1000
ADMIN_USERNAME=adminuser
ADMIN_PASSWORD=AdminPassw0rd!
ROOT_PASSWORD=ComplexP@ssw0rd!

# Services
TTYD_USER=terminal
TTYD_PASSWORD=terminal
DISPLAY=:1

# Ports (host-side)
VNC_PORT=32768
SSH_PORT=2222
TTYD_PORT=7681
AUDIO_BRIDGE_PORT=8080
PULSE_TCP_PORT=4713

# Optional: HTTP auth for VNC
VNC_AUTH_ENABLED=false
VNC_USERS="client1:pass1,client2:pass2"
```

---

**Module Type**: Backend - Containerized Desktop Environment
**Base OS**: Ubuntu 24.04 LTS
**Desktop**: KDE Plasma
**Process Manager**: Supervisord
**Remote Access**: noVNC, SSH, TTYD
**Audio**: PulseAudio + WebSocket Bridge
**Last Updated**: 2025-11-22

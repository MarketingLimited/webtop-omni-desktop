# Ubuntu KDE Docker for Marketing Agency
## Enhanced Development, Video Editing & Multi-Platform Suite

A comprehensive Docker environment featuring Ubuntu with KDE Plasma desktop, specifically configured for marketing agencies with professional tools, full audio support, web development capabilities, video editing suite, Windows app compatibility (Wine), and Android app support (Waydroid).

## 🚀 Features

### 🎨 Marketing & Creative Suite
- **Complete KDE Plasma Desktop** - Full desktop environment accessible via web browser
- **Marketing-Focused Applications** - Design, social media, analytics, and productivity tools
- **Professional Video Editing** - Kdenlive, OpenShot, Blender, OBS Studio, Audacity
- **Graphics & Design** - GIMP, Inkscape, Krita with marketing templates

### 💻 Development Environment
- **Full Stack Development** - Node.js, Python, PHP, Ruby, Go
- **Modern IDEs** - VS Code, development tools, and frameworks
- **Database Tools** - PostgreSQL, MySQL, MongoDB, Redis clients
- **Container Support** - Docker-in-Docker, Kubernetes tools

### 🎵 Audio & Multimedia
- **Virtual Audio Devices** - Full audio support for content creation
- **Professional Audio** - Ardour, Reaper, Jack Audio, advanced audio tools
- **Screen Recording** - OBS Studio, Kazam, SimpleScreenRecorder
- **Streaming Support** - Complete streaming and broadcasting setup

### 🖥️ Multi-Platform Support
- **Windows Apps** - Wine integration with automated setup
- **Android Apps** - Waydroid for native Android app support
- **Cross-Platform** - ARM64 and AMD64 architecture support

### 🌐 Remote Access & Infrastructure
- **Multiple Access Methods** - noVNC, SSH, web terminal
- **Performance Monitoring** - Resource usage, health checks
- **CI/CD Ready** - GitHub Actions, automated builds, multi-environment support

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- 4GB+ RAM recommended
- Modern web browser

### 1. Clone & Configure
```bash
git clone <repository>
cd ubuntu-kde-docker
cp .env.example .env
# Edit .env with your credentials
```

### 2. Choose Your Environment

**Multi-Container with Enhanced Volume Management (Recommended):**
```bash
# Initialize enhanced volume management
./setup-volumes.sh

# Create named containers with auto port assignment
./webtop.sh up --name client1 --auth
./webtop.sh up --name team-alpha
./webtop.sh up --name client2 --template marketing

# List all containers
./webtop.sh list
```

**Traditional Single Container:**
```bash
# Development (Full Features)
./webtop.sh build
docker compose -f docker-compose.dev.yml up -d

# Production (Optimized)  
docker compose -f docker-compose.prod.yml up -d

# Basic (Original)
./webtop.sh up
```

### 3. Access Services

| Service | URL | Description | Status Check |
|---------|-----|-------------|--------------|

| 🖥️ **VNC Desktop** | `http://localhost:80` | Desktop via noVNC | Auto-validated |
| 💻 **Terminal** | `http://localhost:7681` | Web terminal (TTYD) | Auto-validated |
| 🔐 **SSH** | `ssh user@localhost -p 2222` | Direct SSH access | Auto-validated |
| 🎵 **Audio** | KDE System Settings | Virtual audio devices | Auto-validated |

## 🛠️ Management Scripts

### **Multi-Container Management**
```bash
# Create and manage named containers  
./webtop.sh up --name client1                    # Create isolated container
./webtop.sh up --name team-alpha --auth          # With authentication
./webtop.sh list                                 # List all containers
./webtop.sh info client1                         # Show container details
./webtop.sh stop client1                         # Stop specific container
./webtop.sh remove client1                       # Remove container & volumes
```

### **Enhanced Volume & Backup Management**
```bash
# One-click backup and restore
./webtop.sh backup client1                       # Backup container volumes
./webtop.sh restore client1 backup-20240131      # Restore from backup
./webtop.sh clone client1 client2                # Clone container setup

# Template system for rapid deployment
./webtop.sh template save client1 marketing-template    # Save as template
./webtop.sh template create client3 marketing-template  # Create from template
./webtop.sh template list                               # List available templates

# Volume management utilities
./webtop.sh volumes list                         # List all volumes
./webtop.sh volumes backup-all                   # Backup all containers
./webtop.sh volumes cleanup                      # Clean unused volumes
```

### **Traditional WebTop Control**
```bash
./webtop.sh build [--background]  # Build container (optionally in background)
./webtop.sh up        # Start services
./webtop.sh down      # Stop services
./webtop.sh restart   # Rebuild and restart
./webtop.sh status    # Check status
./webtop.sh logs      # View logs
./webtop.sh shell     # Open shell
```

### **Background Building**
```bash
./webtop.sh build-bg [--dev|--prod] # Start background build
./webtop.sh build-status           # Check build progress
./webtop.sh build-logs             # View build logs
./webtop.sh build-stop             # Stop background build
./webtop.sh build-cleanup          # Clean up build files
```

### **System Validation**
```bash
# Comprehensive system validation for named containers
docker exec client1 /usr/local/bin/system-validation.sh
docker exec team-alpha /usr/local/bin/health-check.sh

# Traditional single container validation
docker exec webtop-kde /usr/local/bin/system-validation.sh
docker exec webtop-kde /usr/local/bin/health-check.sh
docker exec webtop-kde /usr/local/bin/service-health.sh status
```

## 🎵 Audio Configuration

The system includes a container-compatible audio setup:

1. **Virtual Audio Devices**: Software-based virtual speakers and microphones
2. **PulseAudio Server**: Runs with container-compatible dummy/null sinks
3. **Audio Forwarding**: Routes audio through VNC remote access
4. **KDE Integration**: Virtual devices appear in KDE System Settings

### Audio Management Commands
```bash
# Comprehensive audio validation
docker exec webtop-kde /usr/local/bin/audio-validation.sh

# Desktop audio integration test
docker exec webtop-kde /usr/local/bin/test-desktop-audio.sh

# Continuous audio monitoring
docker exec webtop-kde /usr/local/bin/audio-monitor.sh monitor

# Check PulseAudio status
docker exec webtop-kde pactl list short sinks

# Manual audio restart (if needed)
docker exec webtop-kde supervisorctl restart pulseaudio
```

## 📦 Application Categories

### 🎨 Design & Creative
- GIMP, Inkscape, Krita, Blender
- Figma (web app), Canva (web app)
- Font management with marketing fonts

### 🎬 Video Production
- Kdenlive, OpenShot, Shotcut
- OBS Studio for streaming/recording
- Audacity for audio editing

### 📱 Social Media
- Buffer, Hootsuite, Later (web apps)
- Social media platform shortcuts
- Content scheduling tools

### 📊 Analytics & SEO
- Google Analytics, Google Ads
- SEMrush, Ahrefs (web apps)
- Performance monitoring tools

### 💼 Project Management
- Trello, Asana, Notion
- Time tracking tools
- Client management systems

## 🏗️ Background Building Guide

### Overview
Background building allows you to start Docker builds without blocking your terminal, perfect for large container builds that take time.

### Starting Background Builds
```bash
# Development environment background build
./webtop.sh build-bg --dev

# Production environment background build  
./webtop.sh build-bg --prod

# Basic background build
./webtop.sh build-bg
```

### Monitoring Build Progress
```bash
# Check current build status
./webtop.sh build-status

# View real-time build logs
./webtop.sh build-logs

# Follow build progress continuously
./webtop.sh build-logs -f
```

### Managing Background Builds
```bash
# Stop current background build
./webtop.sh build-stop

# Clean up build artifacts and logs
./webtop.sh build-cleanup

# Check for any running builds
docker ps | grep webtop-build
```

### Build Management Workflows

#### Development Workflow
```bash
# Start development build in background
./webtop.sh build-bg --dev

# Continue working while monitoring progress
./webtop.sh build-status

# When ready, start services
./webtop.sh up --dev
```

#### Production Deployment
```bash
# Background production build with monitoring
./webtop.sh build-bg --prod
watch ./webtop.sh build-status

# Deploy when build completes
./webtop.sh up --prod
```

#### CI/CD Integration
```bash
# Automated background build with status check
./webtop.sh build-bg --prod
while [ "$(./webtop.sh build-status)" != "completed" ]; do
  sleep 30
  echo "Build in progress..."
done
echo "Build completed successfully!"
```

### Best Practices
- **Monitor Progress**: Always check build status during long builds
- **Resource Management**: Use `build-cleanup` to free disk space
- **Log Analysis**: Use `build-logs` to troubleshoot build failures
- **Background vs Foreground**: Use background builds for large projects, foreground for quick testing

## 🔧 Customization

### Adding Applications
Edit `setup-flatpak-apps.sh` or `setup-marketing-shortcuts.sh`:
```bash
# Add Flatpak app
flatpak install -y flathub com.example.App

# Add web app shortcut
cat <<EOF > app.desktop
[Desktop Entry]
Name=App Name
Exec=google-chrome --app=https://example.com --no-sandbox
EOF
```

### Custom Desktop Environment
Modify `setup-desktop.sh` to customize:
- Desktop shortcuts
- Autostart applications
- Desktop wallpaper
- Application categories

### Audio Customization
Edit `setup-audio.sh` to modify:
- Audio device configuration
- PulseAudio modules
- Audio quality settings
- Virtual device names

## 🐳 Docker Architecture

### Multi-Stage Builds
- **Development**: Full feature set for development
- **Production**: Optimized size for deployment
- **Multi-Architecture**: AMD64 and ARM64 support

### Container Profiles
- **Development**: Enhanced debugging, full tools
- **Production**: Optimized, monitoring, reverse proxy
- **Basic**: Simple single-container setup

## 🔐 Security Features

### Access Control
- Multi-user support with role-based access
- Configurable user credentials
- PolicyKit integration for desktop privileges

### Data Protection
- Encrypted volumes for sensitive data
- Secure client data handling
- Session management and timeouts

### Monitoring
- Health checks and status monitoring
- Audit logging for client work
- Resource usage tracking

## 🔄 CI/CD Pipeline

Automated GitHub Actions workflow:
- **Testing**: Configuration validation
- **Building**: Multi-architecture images
- **Security**: Vulnerability scanning
- **Deployment**: Automated production deployment

### Build Status
[![Docker CI/CD](../../actions/workflows/docker-ci.yml/badge.svg)](../../actions/workflows/docker-ci.yml)

## 📈 Monitoring & Analytics

### Production Monitoring
- Prometheus metrics collection
- Grafana dashboards
- Container health checks
- Resource usage alerts

### Performance Optimization
- Resource limits and reservations
- Caching strategies
- Image size optimization
- Service startup optimization

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/marketing-tool`
3. Make changes and test thoroughly
4. Submit pull request with detailed description

### Development Setup
```bash
# Development environment
docker compose -f docker-compose.dev.yml up -d

# Run tests
./scripts/test-audio.sh
./scripts/test-apps.sh
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📚 Documentation

- **[Validation Guide](VALIDATION.md)**: Comprehensive system validation and testing
- **[Troubleshooting Guide](TROUBLESHOOTING.md)**: Advanced troubleshooting and recovery
- **[Service Architecture](SERVICES.md)**: Detailed service documentation and management
- **[Audio Configuration](#-audio-configuration)**: Container-compatible audio setup

## 🆘 Support

- **System Validation**: Run `/usr/local/bin/system-validation.sh` for complete diagnostics
- **Health Check**: Run `/usr/local/bin/health-check.sh` for quick status
- **Issues**: Create GitHub issues for bugs/features
- **Discussions**: Use GitHub Discussions for questions

## 🎯 Marketing Agency Optimizations

This WebTop is specifically optimized for marketing agencies with:

- **Multi-Client Support**: Isolated containers for each client with complete data separation
- **Template-Based Deployment**: Rapid setup with pre-configured marketing environments
- **Enterprise Backup**: Automated daily backups with one-click restore capabilities
- **Client-Ready Environment**: Professional desktop for client presentations
- **Collaborative Tools**: Team containers for collaborative project work
- **Creative Workflow**: Optimized for design-to-delivery workflows with persistent project storage
- **Performance**: Tuned for marketing application performance with smart resource management
- **Security**: Client data protection, access controls, and complete environment isolation
- **Disaster Recovery**: Complete backup/restore system for business continuity
- **Scalability**: Easy scaling from single user to multi-client agency operations

---

**Ready to transform your marketing agency's digital workspace? Start with `./webtop.sh up` and access your new environment at `http://localhost:32768`!** 🚀
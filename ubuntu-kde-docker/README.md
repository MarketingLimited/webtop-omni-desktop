# 🎯 Ubuntu KDE Marketing Agency WebTop

A comprehensive, Dockerized Ubuntu KDE desktop environment specifically designed for marketing agencies. Features full Linux, Android (Waydroid), and Windows (Wine) application support with working audio streaming to browsers.

## 🌟 Features

### 🖥️ Desktop Environment
- **Ubuntu 24.04 + KDE Plasma**: Modern, professional desktop environment
- **Multi-Platform Support**: Linux, Android (Waydroid), Windows (Wine)
- **Web-Based Access**: Access everything from any modern browser
- **Working Audio**: Full audio support with virtual devices and streaming

### 🎨 Marketing Agency Tools
- **Design Suite**: GIMP, Inkscape, Krita, Figma, Canva
- **Video Production**: Kdenlive, OpenShot, OBS Studio, Shotcut
- **Social Media Management**: Buffer, Hootsuite, Later (web apps)
- **Analytics**: Google Analytics, Google Ads, SEMrush (web apps)
- **Project Management**: Trello, Asana, Notion (web apps)
- **Communication**: Slack, Discord, Teams, Zoom

### 🔊 Audio System
- **Virtual Audio Devices**: ALSA loopback with PulseAudio
- **Browser Audio Streaming**: Audio routed through Xpra to browser
- **Professional Audio**: Support for marketing video/audio production

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

**Development (Full Features):**
```bash
./webtop.sh build
docker compose -f docker-compose.dev.yml up -d
```

**Production (Optimized):**
```bash
docker compose -f docker-compose.prod.yml up -d
```

**Basic (Original):**
```bash
./webtop.sh up
```

### 3. Access Services

| Service | URL | Description |
|---------|-----|-------------|
| 🖥️ **KDE Desktop** | `http://localhost:14500` | Full desktop via Xpra |
| 🖥️ **VNC Desktop** | `http://localhost:80` | Desktop via noVNC |
| 💻 **Terminal** | `http://localhost:7681` | Web terminal |
| 🔐 **SSH** | `ssh user@localhost -p 2222` | Direct SSH access |

## 🛠️ Management Scripts

### WebTop Control
```bash
./webtop.sh build     # Build container
./webtop.sh up        # Start services
./webtop.sh down      # Stop services
./webtop.sh restart   # Rebuild and restart
./webtop.sh status    # Check status
./webtop.sh logs      # View logs
./webtop.sh shell     # Open shell
```

### Health Check
```bash
docker exec webtop-kde /usr/local/bin/health-check.sh
```

### Audio Test
```bash
docker exec webtop-kde /usr/local/bin/test-audio.sh
```

## 🎵 Audio Configuration

The system includes a sophisticated audio setup:

1. **Virtual Audio Devices**: ALSA loopback creates virtual speakers/microphones
2. **PulseAudio Server**: Runs in user mode with TCP access
3. **Xpra Audio Bridge**: Routes audio from apps to browser
4. **Browser Playback**: Audio streams directly to your browser

### Troubleshooting Audio
```bash
# Check audio status
docker exec webtop-kde pactl list short sinks

# Test audio generation
docker exec webtop-kde speaker-test -t sine -f 1000 -l 1

# Restart audio services
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

## 🆘 Support

- **Documentation**: Check this README and inline documentation
- **Issues**: Create GitHub issues for bugs/features
- **Discussions**: Use GitHub Discussions for questions
- **Health Check**: Run `health-check.sh` for diagnostics

## 🎯 Marketing Agency Optimizations

This WebTop is specifically optimized for marketing agencies with:

- **Client-Ready Environment**: Professional desktop for client presentations
- **Collaborative Tools**: Built-in communication and project management
- **Creative Workflow**: Optimized for design-to-delivery workflows
- **Performance**: Tuned for marketing application performance
- **Security**: Client data protection and access controls

---

**Ready to transform your marketing agency's digital workspace? Start with `./webtop.sh up` and access your new environment at `http://localhost:14500`!** 🚀
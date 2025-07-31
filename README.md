# Ubuntu KDE Marketing Agency Docker Environment

> A comprehensive Docker-based development and creative workspace designed specifically for marketing agencies, featuring professional tools for web development, video editing, and multi-platform app support.

## 🚀 Features

### **Professional Development Suite**
- **Web & App Development**: Node.js, PHP, Python, Ruby, TypeScript, React, Vue, Angular
- **IDEs & Editors**: VS Code, JetBrains Suite (WebStorm, PyCharm), Sublime Text
- **Database Tools**: PostgreSQL, MongoDB, Redis clients with GUI management
- **API Development**: Postman, Insomnia, Thunder Client for API testing
- **Version Control**: Git, GitKraken, GitHub Desktop with advanced features
- **Container Tools**: Docker Desktop UI, Portainer, Kubernetes management

### **Creative & Video Production**
- **Video Editing**: Kdenlive, DaVinci Resolve, Lightworks, OpenShot
- **Motion Graphics**: Blender, Natron, OpenToonz for 2D/3D animation
- **Audio Production**: Ardour, Reaper, OBS Studio with professional plugins
- **Design Tools**: GIMP, Inkscape, Krita, Scribus for creative workflows
- **Screen Recording**: Advanced OBS setup, SimpleScreenRecorder

### **Multi-Platform Support**
- **Windows Apps (Wine)**: Adobe Creative Suite alternatives, MS Office, marketing tools
- **Android Apps (Waydroid)**: Instagram Creator Studio, TikTok Business, mobile analytics
- **Cross-Platform**: Seamless file sharing and workflow integration

### **Remote Access & Collaboration**
- **Browser-Based Access**: noVNC and Xpra web interfaces
- **Audio Support**: Full audio streaming with virtual devices
- **SSH Access**: Secure terminal access for advanced users
- **Resource Monitoring**: Real-time performance dashboards

## 🛠 Quick Start

### Prerequisites
- **Docker & Docker Compose**: Version 20.10+ with Compose v2
- **System Requirements**: 8GB+ RAM (16GB recommended), 50GB+ disk space
- **Operating System**: Linux, macOS, or Windows with WSL2
- **Browser**: Modern web browser (Chrome, Firefox, Safari)

### Automated Installation (Recommended)

1. **Clone the repository**
   ```bash
   git clone <YOUR_GIT_URL>
   cd <YOUR_PROJECT_NAME>/ubuntu-kde-docker
   ```

2. **Run automated installer**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   The installer will:
   - Check system requirements and Docker installation
   - Set up proper file permissions
   - Create environment configuration
   - Validate Docker Compose files

3. **Build and start the environment**
   ```bash
   ./webtop.sh build
   ./webtop.sh up
   ```

4. **Background Building (Optional)**
   ```bash
   # For large builds, use background building
   ./webtop.sh build-bg --dev    # Development build in background
   ./webtop.sh build-status      # Monitor build progress
   ./webtop.sh build-logs        # View build logs
   ```

### Manual Installation

1. **System checks**
   ```bash
   # Verify Docker installation
   docker --version
   docker compose version
   
   # Check available resources
   free -h  # RAM
   df -h    # Disk space
   ```

2. **Setup environment**
   ```bash
   cd ubuntu-kde-docker
   
   # Set permissions
   chmod +x *.sh
   find . -name "*.sh" -exec chmod +x {} \;
   
   # Configure environment
   cp .env.example .env
   # Edit .env with your preferences
   ```

3. **Build and start**
   ```bash
   # Default environment
   ./webtop.sh build
   ./webtop.sh up
   
   # Development environment (recommended for development work)
   ./webtop.sh build --dev
   ./webtop.sh up --dev
   
   # Production environment
   ./webtop.sh build --prod
   ./webtop.sh up --prod
   ```

### Access Your Workspace

- **VNC Desktop**: http://localhost:32768 ✨ **Recommended**
- **Web Terminal**: http://localhost:7681
- **SSH Access**: `ssh devuser@localhost -p 2222`

**Default Credentials**: 
- Username: `devuser`
- Password: `DevPassw0rd!`

> **Note**: First build may take 20-30 minutes depending on internet speed.

## 📱 Management Commands

```bash
# Container management
./webtop.sh up [--dev|--prod]     # Start containers
./webtop.sh down                  # Stop containers
./webtop.sh restart               # Restart containers
./webtop.sh logs                  # View logs

# Building & deployment
./webtop.sh build [--background]  # Build container (optionally in background)
./webtop.sh build-bg [--dev|--prod] # Start background build
./webtop.sh build-status          # Check background build progress
./webtop.sh build-logs            # View build logs
./webtop.sh build-stop            # Stop background build
./webtop.sh build-cleanup         # Clean up build files

# System setup
./webtop.sh dev-setup            # Configure development tools
./webtop.sh wine-setup           # Setup Windows applications
./webtop.sh android-setup        # Configure Android environment
./webtop.sh video-setup          # Install video editing tools

# Monitoring & maintenance
./webtop.sh status               # Check container status
./webtop.sh health               # Run health checks
./webtop.sh monitor              # View resource usage
./webtop.sh clean                # Clean unused resources
./webtop.sh update               # Update and rebuild
```

## 🎯 Marketing Agency Workflows

### **Content Creation Pipeline**
1. **Design**: GIMP, Inkscape, Krita for graphics
2. **Video Production**: Kdenlive, Blender for content creation
3. **Social Media**: Native mobile apps via Waydroid
4. **Analytics**: Integrated analytics tools and dashboards

### **Development Workflow**
1. **Web Development**: Full-stack development environment
2. **Testing**: Cross-platform testing with Windows/Android apps
3. **Deployment**: CI/CD tools and cloud integration
4. **Monitoring**: Performance monitoring and optimization

### **Client Collaboration**
1. **Remote Access**: Secure browser-based collaboration
2. **File Sharing**: Seamless file management and sharing
3. **Review Tools**: Video review and feedback systems
4. **Project Management**: Integrated project management tools

## 🛡 Security & Performance

- **Container Security**: Isolated environment with controlled access
- **Data Protection**: Encrypted volumes and secure networking
- **Performance Optimization**: GPU acceleration and resource management
- **Backup Systems**: Automated workspace backups

## 🔧 Troubleshooting

### Common Issues

#### Permission Denied Error
```bash
# Fix: Set executable permissions
chmod +x webtop.sh install.sh
find . -name "*.sh" -exec chmod +x {} \;
```

#### Docker Build Fails
```bash
# Check Docker installation
docker --version
docker compose version

# Verify Docker daemon is running
docker info

# Clean Docker system if needed
docker system prune -f

# For background builds, check build status
./webtop.sh build-status
./webtop.sh build-logs
```

#### Background Build Issues
```bash
# Check if build is running
./webtop.sh build-status

# View build logs for errors
./webtop.sh build-logs

# Stop stuck builds
./webtop.sh build-stop

# Clean up and restart
./webtop.sh build-cleanup
./webtop.sh build-bg --dev
```

#### Container Won't Start
```bash
# Check logs for errors
./webtop.sh logs

# Verify Docker Compose configuration
docker compose -f docker-compose.yml config

# Monitor resource usage
./webtop.sh monitor
```

#### Performance Issues
- **Increase shared memory**: Edit `shm_size: "4gb"` to `"8gb"` in docker-compose.yml
- **Add more RAM**: Adjust Docker Desktop memory limits to 8GB+
- **Check disk space**: Ensure 50GB+ available space
- **Monitor resources**: Use `./webtop.sh monitor` command

#### Audio Not Working
```bash
# Verify audio device mapping
ls -la /dev/snd/

# Check PulseAudio in container
./webtop.sh shell
pulseaudio --check -v
pactl list short sinks
```

#### Network Access Problems
```bash
# Check if ports are available
netstat -tlnp | grep -E ':(32768|14500|2222|7681)'

# Verify firewall settings
sudo ufw status
```

### Development Environment Issues

```bash
# If development setup fails
./webtop.sh dev-setup

# Verify Node.js installation
./webtop.sh shell
node --version
npm --version
```

### Wine/Windows Applications

```bash
# Configure Wine environment
./webtop.sh wine-setup

# Check Wine status
./webtop.sh shell
wine --version
```

### Android/Waydroid Issues

```bash
# Setup Android environment
./webtop.sh android-setup

# Check Waydroid status
./webtop.sh shell
waydroid status
```

### Getting Help

1. **Run health check**: `./webtop.sh health`
2. **Check system status**: `./webtop.sh status`
3. **View logs**: `./webtop.sh logs`
4. **Access container shell**: `./webtop.sh shell`

**For persistent issues**, create a GitHub issue with:
- Operating system and Docker version
- Complete error messages
- Output from `./webtop.sh health`
- Docker system info: `docker system info`

## 📚 Documentation

- **Application List**: 50+ pre-installed marketing applications
- **Health Monitoring**: Built-in health checks and monitoring
- **Backup & Restore**: Container data management
- **Customization**: Adding applications and configurations

## 🔧 Technology Stack

**Frontend Development**
- Vite, TypeScript, React, shadcn-ui, Tailwind CSS

**Backend & Infrastructure**
- Docker, Docker Compose, Ubuntu 22.04 LTS, KDE Plasma
- Supabase integration for database and authentication

**Creative Tools**
- Professional video editing and graphic design suite
- Audio production and streaming capabilities

## 🚀 Deployment

### Local Development
```bash
npm install
npm run dev
```

### Production Deployment
- **Lovable Platform**: Click Share → Publish in [Lovable](https://lovable.dev/projects/c4d2e059-80bc-40ad-b3b1-0ab89b6f5e9b)
- **Custom Domain**: Configure in Project → Settings → Domains
- **Docker Production**: Use `./webtop.sh up --prod` for production containers

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: [Lovable Docs](https://docs.lovable.dev)
- **Community**: GitHub Issues and Discussions
- **Professional Support**: Available for enterprise deployments

---

**Built with ❤️ for Marketing Agencies** | Powered by Docker + KDE + React
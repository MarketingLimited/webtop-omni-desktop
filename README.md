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
- **Browser-Based Access**: noVNC web interface with audio streaming
- **Audio Support**: Full audio streaming with virtual devices
- **SSH Access**: Secure terminal access for advanced users
- **Resource Monitoring**: Real-time performance dashboards

## 🛠 Quick Start

### Prerequisites
- **Docker & Docker Compose**: Version 20.10+ with Compose v2
- **System Requirements**: 8GB+ RAM (16GB recommended), 50GB+ disk space
- **Operating System**: Linux, macOS, or Windows with WSL2
- **Browser**: Modern web browser (Chrome, Firefox, Safari)
- **jq**: For container management (auto-installed if missing)

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
   - Initialize enhanced volume management
   - Validate Docker Compose files

3. **Build and start the environment**
   ```bash
   # Single container (traditional)
   ./webtop.sh build
   ./webtop.sh up
   
   # Multi-container with auto port discovery
   ./webtop.sh up --name client1 --auth   # Auto-assigns available ports
   ./webtop.sh up --name team-alpha        # Creates isolated environment
   
   # Template-based container creation
   ./webtop.sh up --name client2 --template marketing
   ```

4. **Enhanced Volume Management**
   ```bash
   # Initialize volume management (auto-run during install)
   ./setup-volumes.sh
   
   # One-click backup and restore
   ./webtop.sh backup client1
   ./webtop.sh restore client1 backup-20240131
   
   # Clone existing containers
   ./webtop.sh clone client1 client1-backup
   ```

5. **Background Building (Optional)**
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
./webtop.sh backup client1                       # Backup container
./webtop.sh restore client1 backup-20240131      # Restore from backup
./webtop.sh clone client1 client2                # Clone container setup

# Template system for rapid deployment
./webtop.sh template save client1 marketing-template    # Save as template
./webtop.sh template create client3 marketing-template  # Create from template
./webtop.sh template list                               # List templates

# Volume management
./webtop.sh volumes list                         # List all volumes
./webtop.sh volumes backup-all                   # Backup all containers
./webtop.sh volumes cleanup                      # Clean unused volumes
```

### **Traditional Container Operations**
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

### **Multi-Client Management**
1. **Isolated Environments**: Each client gets dedicated container (`client1`, `client2`)
2. **Template-Based Setup**: Quick deployment with `marketing-template`
3. **Team Collaboration**: Shared containers for team projects (`team-alpha`)
4. **Data Isolation**: Complete separation of client data and configurations

### **Content Creation Pipeline**
1. **Design**: GIMP, Inkscape, Krita for graphics
2. **Video Production**: Kdenlive, Blender for content creation
3. **Social Media**: Native mobile apps via Waydroid
4. **Analytics**: Integrated analytics tools and dashboards
5. **Backup & Recovery**: Automated daily backups of all work

### **Development Workflow**
1. **Web Development**: Full-stack development environment with persistent projects
2. **Testing**: Cross-platform testing with Windows/Android apps
3. **Deployment**: CI/CD tools and cloud integration
4. **Environment Cloning**: Clone dev environments for testing

### **Client Collaboration & Handoff**
1. **Template Creation**: Save configured environments as reusable templates
2. **Quick Setup**: Deploy client environments in minutes
3. **Data Migration**: Easy backup/restore for client handoffs
4. **Disaster Recovery**: One-click restore from any backup point

## 🛡 Security & Performance

- **Container Security**: Isolated environment with controlled access per client
- **Data Protection**: Encrypted volumes and secure networking with complete data isolation
- **Performance Optimization**: GPU acceleration and resource management
- **Enterprise Backup**: Automated daily backups with one-click restore capabilities
- **Multi-Container Isolation**: Complete separation between client environments
- **Template Security**: Secure template creation and deployment

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
- [**Audio Diagnostics**](ubuntu-kde-docker/docs/AUDIO_DIAGNOSTICS.md): Client-side audio diagnostics for vnc_audio.html (debug mode, real-time HUD, self-tests)

## 🔧 Technology Stack

**Frontend Development**
- Vite, TypeScript, React, shadcn-ui, Tailwind CSS

**Backend & Infrastructure**
- Docker, Docker Compose, Ubuntu 24.04 LTS, KDE Plasma
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
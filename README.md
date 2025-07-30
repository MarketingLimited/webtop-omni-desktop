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
- **Docker & Docker Compose**: Latest versions
- **System Requirements**: 4GB+ RAM, 20GB+ disk space
- **Browser**: Modern web browser (Chrome, Firefox, Safari)

### Installation

1. **Clone the repository**
   ```bash
   git clone <YOUR_GIT_URL>
   cd <YOUR_PROJECT_NAME>
   ```

2. **Configure environment**
   ```bash
   cd ubuntu-kde-docker
   cp .env.example .env
   # Edit .env file with your preferences
   ```

3. **Build and start the environment**
   ```bash
   # Development environment (recommended)
   ./webtop.sh build --dev
   ./webtop.sh up --dev
   
   # Production environment
   ./webtop.sh build --prod
   ./webtop.sh up --prod
   ```

### Access Your Workspace

- **KDE Desktop (Xpra)**: http://localhost:14500
- **VNC Desktop**: http://localhost:32768
- **SSH Terminal**: `ssh devuser@localhost -p 32222`

Default credentials: `devuser` / `password`

## 📱 Management Commands

```bash
# Container management
./webtop.sh up [--dev|--prod]     # Start containers
./webtop.sh down                  # Stop containers
./webtop.sh restart               # Restart containers
./webtop.sh logs                  # View logs

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

## 📚 Documentation

- **Setup Guide**: [ubuntu-kde-docker/README.md](ubuntu-kde-docker/README.md)
- **Application List**: 50+ pre-installed marketing applications
- **Troubleshooting**: Common issues and solutions
- **Customization**: Adding applications and custom configurations

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
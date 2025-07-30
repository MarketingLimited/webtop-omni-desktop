#!/bin/bash

# Webtop KDE Marketing Agency Manager
# Enhanced for Web Development, Video Editing, Wine, and Android support

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}
╔══════════════════════════════════════════════════════════════╗
║                    WEBTOP KDE MARKETING SUITE               ║
║           Enhanced for Development & Content Creation        ║
╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Check if .env file exists
check_env() {
    if [ ! -f .env ]; then
        print_warning ".env file not found. Creating from .env.example..."
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success ".env file created from .env.example"
        else
            print_error ".env.example not found. Please create .env file manually."
            exit 1
        fi
    fi
}

# Display help
show_help() {
    print_header
    echo
    echo -e "${CYAN}Usage: $0 [COMMAND] [OPTIONS]${NC}"
    echo
    echo -e "${YELLOW}COMMANDS:${NC}"
    echo "  build [--dev|--prod]     Build Docker image"
    echo "  up [--dev|--prod]        Start the container"
    echo "  down                     Stop and remove containers"
    echo "  restart                  Restart containers"
    echo "  logs                     Show container logs"
    echo "  status                   Show container status"
    echo "  shell                    Access container shell"
    echo "  update                   Update and rebuild"
    echo "  clean                    Clean Docker system"
    echo "  backup                   Backup container data"
    echo "  restore [backup_file]    Restore from backup"
    echo
    echo -e "${YELLOW}ACCESS POINTS:${NC}"
    echo "  web                      Open noVNC in browser"
    echo "  xpra                     Open Xpra client"
    echo "  ssh                      Connect via SSH"
    echo "  terminal                 Open web terminal"
    echo
    echo -e "${YELLOW}DEVELOPMENT:${NC}"
    echo "  dev-setup               Setup development environment"
    echo "  wine-setup              Configure Wine for Windows apps"
    echo "  android-setup           Setup Android/Waydroid environment"
    echo "  video-setup             Configure video editing tools"
    echo
    echo -e "${YELLOW}MONITORING:${NC}"
    echo "  monitor                 Show resource usage"
    echo "  health                  Check container health"
    echo "  benchmark               Run performance benchmark"
    echo
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo "  --dev                   Use development configuration"
    echo "  --prod                  Use production configuration"
    echo "  --help, -h              Show this help message"
    echo
}

# Get configuration type
get_config() {
    case "$1" in
        --dev)
            echo "dev"
            ;;
        --prod)
            echo "prod"
            ;;
        *)
            echo "default"
            ;;
    esac
}

# Build Docker image
build_image() {
    local config=$(get_config "$1")
    print_status "Building Docker image (${config} configuration)..."
    
    case "$config" in
        dev)
            docker-compose -f docker-compose.dev.yml build
            ;;
        prod)
            docker-compose -f docker-compose.prod.yml build
            ;;
        *)
            docker-compose build
            ;;
    esac
    
    print_success "Docker image built successfully!"
}

# Start containers
start_containers() {
    local config=$(get_config "$1")
    print_status "Starting containers (${config} configuration)..."
    
    case "$config" in
        dev)
            docker-compose -f docker-compose.dev.yml up -d
            ;;
        prod)
            docker-compose -f docker-compose.prod.yml up -d
            ;;
        *)
            docker-compose up -d
            ;;
    esac
    
    print_success "Containers started successfully!"
    show_access_info "$config"
}

# Stop containers
stop_containers() {
    print_status "Stopping containers..."
    docker-compose down
    docker-compose -f docker-compose.dev.yml down 2>/dev/null || true
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    print_success "Containers stopped successfully!"
}

# Show access information
show_access_info() {
    local config="$1"
    echo
    print_success "Marketing Agency Webtop is running!"
    echo
    echo -e "${CYAN}Access Points:${NC}"
    
    case "$config" in
        dev)
            echo "  🌐 noVNC (Web):        http://localhost:32768"
            echo "  🎮 Xpra (Web):         http://localhost:14500"
            echo "  🔒 SSH:                ssh developer@localhost -p 2222"
            echo "  💻 Web Terminal:       http://localhost:7681"
            echo "  🔊 Audio Port:          4713"
            ;;
        prod)
            echo "  🌐 Web Interface:      https://your-domain.com"
            echo "  🔒 SSH:                ssh marketing@your-server -p 2222"
            echo "  📊 Monitoring:         http://localhost:3000 (Grafana)"
            echo "  📈 Metrics:            http://localhost:9090 (Prometheus)"
            ;;
        *)
            echo "  🌐 noVNC (Web):        http://localhost:32768"
            echo "  🎮 Xpra (Web):         http://localhost:14500"
            echo "  🔒 SSH:                ssh devuser@localhost -p 2222"
            echo "  💻 Web Terminal:       http://localhost:7681"
            ;;
    esac
    
    echo
    echo -e "${YELLOW}Features Available:${NC}"
    echo "  ✅ KDE Plasma Desktop Environment"
    echo "  ✅ Full Audio Support (Virtual Audio)"
    echo "  ✅ Marketing Tools & Social Media Apps"
    echo "  ✅ Professional Video Editing Suite"
    echo "  ✅ Complete Web Development Stack"
    echo "  ✅ Windows Applications (via Wine)"
    echo "  ✅ Android Apps (via Waydroid)"
    echo "  ✅ Design & Graphics Tools"
    echo "  ✅ Communication & Collaboration"
    echo
}

# Show container status
show_status() {
    print_status "Container Status:"
    docker-compose ps 2>/dev/null || print_warning "Default compose not running"
    docker-compose -f docker-compose.dev.yml ps 2>/dev/null || print_warning "Dev compose not running"
    docker-compose -f docker-compose.prod.yml ps 2>/dev/null || print_warning "Prod compose not running"
}

# Access container shell
access_shell() {
    local container_name="webtop-kde"
    if docker ps --format "table {{.Names}}" | grep -q "webtop-kde-dev"; then
        container_name="webtop-kde-dev"
    elif docker ps --format "table {{.Names}}" | grep -q "webtop-kde-prod"; then
        container_name="webtop-kde-prod"
    fi
    
    print_status "Accessing container shell: $container_name"
    docker exec -it "$container_name" /bin/bash
}

# Open web interfaces
open_web() {
    print_status "Opening noVNC in browser..."
    if command -v xdg-open > /dev/null; then
        xdg-open "http://localhost:32768"
    elif command -v open > /dev/null; then
        open "http://localhost:32768"
    else
        echo "Please open http://localhost:32768 in your browser"
    fi
}

open_xpra() {
    print_status "Opening Xpra in browser..."
    if command -v xdg-open > /dev/null; then
        xdg-open "http://localhost:14500"
    elif command -v open > /dev/null; then
        open "http://localhost:14500"
    else
        echo "Please open http://localhost:14500 in your browser"
    fi
}

# Development setup
dev_setup() {
    print_status "Setting up development environment..."
    local container_name="webtop-kde"
    if docker ps --format "table {{.Names}}" | grep -q "webtop-kde-dev"; then
        container_name="webtop-kde-dev"
    fi
    
    docker exec -it "$container_name" /usr/local/bin/setup-development.sh
    print_success "Development environment configured!"
}

# Wine setup
wine_setup() {
    print_status "Setting up Wine for Windows applications..."
    local container_name="webtop-kde"
    if docker ps --format "table {{.Names}}" | grep -q "webtop-kde-dev"; then
        container_name="webtop-kde-dev"
    fi
    
    docker exec -it "$container_name" /usr/local/bin/setup-wine.sh
    print_success "Wine environment configured!"
}

# Android setup
android_setup() {
    print_status "Setting up Android/Waydroid environment..."
    local container_name="webtop-kde"
    if docker ps --format "table {{.Names}}" | grep -q "webtop-kde-dev"; then
        container_name="webtop-kde-dev"
    fi
    
    docker exec -it "$container_name" /usr/local/bin/setup-waydroid.sh
    print_success "Android environment configured!"
}

# Video editing setup
video_setup() {
    print_status "Setting up video editing tools..."
    local container_name="webtop-kde"
    if docker ps --format "table {{.Names}}" | grep -q "webtop-kde-dev"; then
        container_name="webtop-kde-dev"
    fi
    
    docker exec -it "$container_name" /usr/local/bin/setup-video-editing.sh
    print_success "Video editing environment configured!"
}

# Monitor resources
monitor_resources() {
    print_status "Resource monitoring..."
    docker stats --no-stream
}

# Health check
health_check() {
    print_status "Performing health check..."
    local container_name="webtop-kde"
    if docker ps --format "table {{.Names}}" | grep -q "webtop-kde-dev"; then
        container_name="webtop-kde-dev"
    fi
    
    if docker exec "$container_name" /usr/local/bin/health-check.sh; then
        print_success "Health check passed!"
    else
        print_error "Health check failed!"
    fi
}

# Clean Docker system
clean_system() {
    print_warning "This will remove unused Docker images and containers."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning Docker system..."
        docker system prune -f
        docker volume prune -f
        print_success "Docker system cleaned!"
    fi
}

# Update and rebuild
update_system() {
    print_status "Updating and rebuilding..."
    git pull
    build_image
    stop_containers
    start_containers
    print_success "System updated successfully!"
}

# Main command handling
main() {
    case "$1" in
        build)
            check_env
            build_image "$2"
            ;;
        up|start)
            check_env
            start_containers "$2"
            ;;
        down|stop)
            stop_containers
            ;;
        restart)
            stop_containers
            start_containers "$2"
            ;;
        logs)
            docker-compose logs -f
            ;;
        status)
            show_status
            ;;
        shell)
            access_shell
            ;;
        web)
            open_web
            ;;
        xpra)
            open_xpra
            ;;
        ssh)
            ssh devuser@localhost -p 2222
            ;;
        terminal)
            open "http://localhost:7681" 2>/dev/null || echo "Open http://localhost:7681"
            ;;
        dev-setup)
            dev_setup
            ;;
        wine-setup)
            wine_setup
            ;;
        android-setup)
            android_setup
            ;;
        video-setup)
            video_setup
            ;;
        monitor)
            monitor_resources
            ;;
        health)
            health_check
            ;;
        clean)
            clean_system
            ;;
        update)
            update_system
            ;;
        --help|-h|help)
            show_help
            ;;
        *)
            if [ -z "$1" ]; then
                show_help
            else
                print_error "Unknown command: $1"
                echo "Use '$0 --help' for usage information."
                exit 1
            fi
            ;;
    esac
}

# Run main function
main "$@"
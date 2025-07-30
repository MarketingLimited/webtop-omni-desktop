#!/bin/bash

# Ubuntu KDE Marketing Agency Docker Environment Installation Script
# This script automates the setup and installation process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo -e "${PURPLE}
╔══════════════════════════════════════════════════════════════╗
║           UBUNTU KDE MARKETING AGENCY INSTALLER             ║
║               Automated Setup & Configuration               ║
╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Check system requirements
check_system_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. This is not recommended for Docker."
    fi
    
    # Check available disk space (require at least 10GB)
    available_space=$(df . | awk 'NR==2 {print $4}')
    required_space=$((10 * 1024 * 1024)) # 10GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Insufficient disk space. Required: 10GB, Available: $(($available_space / 1024 / 1024))GB"
        exit 1
    fi
    
    # Check memory (require at least 4GB)
    total_memory=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_memory" -lt 4096 ]; then
        print_warning "Low memory detected: ${total_memory}MB. Recommended: 8GB+"
    fi
    
    print_success "System requirements check completed"
}

# Check Docker installation
check_docker_installation() {
    print_status "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed."
        echo "Please install Docker first:"
        echo "  Ubuntu/Debian: curl -fsSL https://get.docker.com | sh"
        echo "  Or visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running."
        echo "Please start Docker service:"
        echo "  systemctl start docker"
        echo "  sudo systemctl enable docker"
        exit 1
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        print_success "Using Docker Compose v2"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        print_success "Using Docker Compose v1 (legacy)"
    else
        print_error "Docker Compose is not installed."
        echo "Please install Docker Compose:"
        echo "  Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Check Docker version
    docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    print_success "Docker version: $docker_version"
}

# Setup permissions
setup_permissions() {
    print_status "Setting up file permissions..."
    
    # Make all shell scripts executable
    find . -name "*.sh" -type f -exec chmod +x {} \;
    
    # Make specific files executable (in case find missed any)
    chmod +x webtop.sh 2>/dev/null || true
    chmod +x install.sh 2>/dev/null || true
    chmod +x fix-permissions.sh 2>/dev/null || true
    chmod +x entrypoint.sh 2>/dev/null || true
    chmod +x health-check.sh 2>/dev/null || true
    chmod +x setup-*.sh 2>/dev/null || true
    
    print_success "File permissions configured"
}

# Setup environment
setup_environment() {
    print_status "Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success ".env file created from .env.example"
        else
            print_error ".env.example file not found"
            exit 1
        fi
    else
        print_success ".env file already exists"
    fi
    
    # Validate .env file
    if ! grep -q "DEV_USERNAME" .env; then
        print_error ".env file is missing required variables"
        exit 1
    fi
    
    print_success "Environment configuration completed"
}

# Create required directories
create_directories() {
    print_status "Creating required directories..."
    
    # Create log directory
    mkdir -p logs
    mkdir -p ssl
    mkdir -p dev_config
    
    print_success "Required directories created"
}

# Validate Docker Compose files
validate_compose_files() {
    print_status "Validating Docker Compose files..."
    
    local files=("docker-compose.yml" "docker-compose.dev.yml" "docker-compose.prod.yml")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            if $DOCKER_COMPOSE_CMD -f "$file" config &> /dev/null; then
                print_success "$file is valid"
            else
                print_error "$file has syntax errors"
                $DOCKER_COMPOSE_CMD -f "$file" config
                exit 1
            fi
        else
            print_warning "$file not found"
        fi
    done
}

# Show installation summary
show_installation_summary() {
    print_header
    echo
    print_success "Installation completed successfully!"
    echo
    echo -e "${CYAN}Quick Start Commands:${NC}"
    echo "  1. Build the environment:    ./webtop.sh build"
    echo "  2. Start the environment:    ./webtop.sh up"
    echo "  3. Access via web browser:   http://localhost:32768 (noVNC)"
    echo "  4. Access via Xpra:          http://localhost:14500"
    echo "  5. Check status:             ./webtop.sh status"
    echo
    echo -e "${CYAN}For Development:${NC}"
    echo "  Build dev environment:       ./webtop.sh build --dev"
    echo "  Start dev environment:       ./webtop.sh up --dev"
    echo "  Setup development tools:     ./webtop.sh dev-setup"
    echo
    echo -e "${CYAN}Configuration:${NC}"
    echo "  Environment file:            .env"
    echo "  Development config:          docker-compose.dev.yml"
    echo "  Production config:           docker-compose.prod.yml"
    echo
    echo -e "${CYAN}Help:${NC}"
    echo "  Show all commands:           ./webtop.sh --help"
    echo
    echo -e "${YELLOW}Note: The first build may take 20-30 minutes depending on your internet connection.${NC}"
    echo
}

# Main installation function
main() {
    print_header
    echo
    
    print_status "Starting Ubuntu KDE Marketing Agency Docker installation..."
    echo
    
    check_system_requirements
    check_docker_installation
    setup_permissions
    setup_environment
    create_directories
    validate_compose_files
    
    show_installation_summary
}

# Run installation
main "$@"
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

# Check Docker and Docker Compose
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    # Check for modern Docker Compose (v2) or fallback to legacy
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        print_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi
    
    print_status "Using: $DOCKER_COMPOSE_CMD"
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
    echo "  build-bg [--dev|--prod]  Build Docker image in background"
    echo "  build-status             Check background build progress"
    echo "  build-logs               Show build logs"
    echo "  build-stop               Stop background build"
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
    echo "  "
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

# Get Docker Compose file
get_compose_file() {
    local config="$1"
    case "$config" in
        dev)
            echo "docker-compose.dev.yml"
            ;;
        prod)
            echo "docker-compose.prod.yml"
            ;;
        *)
            echo "docker-compose.yml"
            ;;
    esac
}

# Build Docker image
build_image() {
    local config=$(get_config "$1")
    local compose_file=$(get_compose_file "$config")
    local background_flag="$2"
    
    if [ ! -f "$compose_file" ]; then
        print_error "Docker Compose file not found: $compose_file"
        exit 1
    fi
    
    if [ "$background_flag" = "--background" ] || [ "$background_flag" = "bg" ]; then
        build_image_background "$config" "$compose_file"
    else
        print_status "Building Docker image (${config} configuration)..."
        $DOCKER_COMPOSE_CMD -f "$compose_file" build
        print_success "Docker image built successfully!"
    fi
}

# Build Docker image in background
build_image_background() {
    local config="$1"
    local compose_file="$2"
    local pid_file="build-${config}.pid"
    local log_file="build-${config}.log"
    local start_time=$(date +%s)
    
    # Check if build is already running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        print_warning "Background build already running for ${config} configuration"
        print_status "Check progress with: $0 build-status --${config}"
        return 0
    fi
    
    print_status "Starting background build (${config} configuration)..."
    echo "Build started at: $(date)" > "$log_file"
    echo "Configuration: $config" >> "$log_file"
    echo "Compose file: $compose_file" >> "$log_file"
    echo "Start time: $start_time" >> "$log_file"
    echo "========================================" >> "$log_file"
    
    # Start background build process
    nohup bash -c "
        echo 'Build process started' >> '$log_file'
        $DOCKER_COMPOSE_CMD -f '$compose_file' build >> '$log_file' 2>&1
        build_exit_code=\$?
        echo '========================================' >> '$log_file'
        echo 'Build completed at: \$(date)' >> '$log_file'
        if [ \$build_exit_code -eq 0 ]; then
            echo 'Status: SUCCESS' >> '$log_file'
        else
            echo 'Status: FAILED' >> '$log_file'
            echo 'Exit code: \$build_exit_code' >> '$log_file'
        fi
        rm -f '$pid_file'
    " > /dev/null 2>&1 &
    
    local build_pid=$!
    echo "$build_pid" > "$pid_file"
    
    print_success "Background build started (PID: $build_pid)"
    print_status "Check progress with: $0 build-status"
    print_status "View logs with: $0 build-logs"
    print_status "Stop build with: $0 build-stop"
}

# Check background build status
check_build_status() {
    local config=$(get_config "$1")
    local pid_file="build-${config}.pid"
    local log_file="build-${config}.log"
    
    if [ ! -f "$log_file" ]; then
        print_warning "No build log found for ${config} configuration"
        return 1
    fi
    
    # Check if build is running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        local pid=$(cat "$pid_file")
        print_status "Background build running (PID: $pid) - ${config} configuration"
        echo
        
        # Show recent progress
        echo -e "${CYAN}Recent build output:${NC}"
        tail -10 "$log_file"
        echo
        echo -e "${YELLOW}Use '$0 build-logs' to see full output${NC}"
        echo -e "${YELLOW}Use '$0 build-stop' to stop the build${NC}"
    else
        # Build finished - show final status
        if grep -q "Status: SUCCESS" "$log_file" 2>/dev/null; then
            print_success "Background build completed successfully! (${config} configuration)"
        elif grep -q "Status: FAILED" "$log_file" 2>/dev/null; then
            print_error "Background build failed! (${config} configuration)"
            echo -e "${YELLOW}Check logs with: $0 build-logs${NC}"
        else
            print_warning "Build status unclear. Check logs with: $0 build-logs"
        fi
        
        # Show build summary
        if [ -f "$log_file" ]; then
            echo
            echo -e "${CYAN}Build Summary:${NC}"
            grep -E "(Build started at|Build completed at|Status:)" "$log_file" 2>/dev/null || echo "No summary available"
        fi
    fi
}

# Show build logs
show_build_logs() {
    local config=$(get_config "$1")
    local log_file="build-${config}.log"
    local follow_flag="$2"
    
    if [ ! -f "$log_file" ]; then
        print_warning "No build log found for ${config} configuration"
        return 1
    fi
    
    print_status "Build logs for ${config} configuration:"
    echo
    
    if [ "$follow_flag" = "-f" ] || [ "$follow_flag" = "--follow" ]; then
        tail -f "$log_file"
    else
        cat "$log_file"
    fi
}

# Stop background build
stop_build() {
    local config=$(get_config "$1")
    local pid_file="build-${config}.pid"
    local log_file="build-${config}.log"
    
    if [ ! -f "$pid_file" ]; then
        print_warning "No background build running for ${config} configuration"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    
    if kill -0 "$pid" 2>/dev/null; then
        print_status "Stopping background build (PID: $pid)..."
        
        # Try graceful termination first
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null
        fi
        
        # Log the interruption
        echo "========================================" >> "$log_file"
        echo "Build stopped by user at: $(date)" >> "$log_file"
        echo "Status: INTERRUPTED" >> "$log_file"
        
        rm -f "$pid_file"
        print_success "Background build stopped"
    else
        print_warning "Build process not running (PID: $pid)"
        rm -f "$pid_file"
    fi
}

# Cleanup build files
cleanup_build_files() {
    local config="$1"
    
    if [ "$config" = "all" ]; then
        print_status "Cleaning up all build files..."
        rm -f build-*.pid build-*.log
        print_success "All build files cleaned up"
    else
        local actual_config=$(get_config "$config")
        print_status "Cleaning up build files for ${actual_config} configuration..."
        rm -f "build-${actual_config}.pid" "build-${actual_config}.log"
        print_success "Build files for ${actual_config} configuration cleaned up"
    fi
}

# Start containers
start_containers() {
    local config=$(get_config "$1")
    local compose_file=$(get_compose_file "$config")
    
    print_status "Starting containers (${config} configuration)..."
    
    if [ ! -f "$compose_file" ]; then
        print_error "Docker Compose file not found: $compose_file"
        exit 1
    fi
    
    $DOCKER_COMPOSE_CMD -f "$compose_file" up -d
    
    print_success "Containers started successfully!"
    show_access_info "$config"
}

# Stop containers
stop_containers() {
    print_status "Stopping containers..."
    
    # Try to stop all possible configurations
    for file in docker-compose.yml docker-compose.dev.yml docker-compose.prod.yml; do
        if [ -f "$file" ]; then
            $DOCKER_COMPOSE_CMD -f "$file" down 2>/dev/null || true
        fi
    done
    
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
    
    for file in docker-compose.yml docker-compose.dev.yml docker-compose.prod.yml; do
        if [ -f "$file" ]; then
            echo -e "\n${CYAN}$file:${NC}"
            $DOCKER_COMPOSE_CMD -f "$file" ps 2>/dev/null || print_warning "No containers running for $file"
        fi
    done
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
    # Always check Docker first
    check_docker
    
    case "$1" in
        build)
            check_env
            if [ "$2" = "--background" ] || [ "$3" = "--background" ]; then
                build_image "$2" "--background"
            else
                build_image "$2"
            fi
            ;;
        build-bg)
            check_env
            build_image "$2" "bg"
            ;;
        build-status|progress)
            check_build_status "$2"
            ;;
        build-logs)
            show_build_logs "$2" "$3"
            ;;
        build-stop)
            stop_build "$2"
            ;;
        build-cleanup)
            cleanup_build_files "$2"
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
            local config=$(get_config "$2")
            local compose_file=$(get_compose_file "$config")
            $DOCKER_COMPOSE_CMD -f "$compose_file" logs -f
            ;;
        status)
            show_status
            # Also check build status
            echo
            for config in default dev prod; do
                if [ -f "build-${config}.log" ]; then
                    check_build_status "--${config}" 2>/dev/null || true
                fi
            done
            ;;
        shell)
            access_shell
            ;;
        web)
            open_web
            ;;
        ssh)
            ssh devuser@localhost -p 2222
            ;;
        terminal)
            if command -v xdg-open > /dev/null; then
                xdg-open "http://localhost:7681"
            elif command -v open > /dev/null; then
                open "http://localhost:7681"
            else
                echo "Open http://localhost:7681 in your browser"
            fi
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
#!/bin/bash

# Webtop KDE Marketing Agency Manager
# Enhanced with multi-container support and HTTP authentication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Container registry file
CONTAINER_REGISTRY=".container-registry.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Container options
CONTAINER_NAME=""
CONTAINER_PORTS=""
ENABLE_AUTH=""

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

# Load environment variables with defaults
load_env() {
    source .env
    
    # Set default base ports if not defined
    export BASE_HTTP_PORT=${BASE_HTTP_PORT:-32769}
    export BASE_SSH_PORT=${BASE_SSH_PORT:-2223}
    export BASE_TTYD_PORT=${BASE_TTYD_PORT:-7682}
    export BASE_AUDIO_PORT=${BASE_AUDIO_PORT:-8081}
    export BASE_PULSE_PORT=${BASE_PULSE_PORT:-4714}
}

# Check if port is available
is_port_available() {
    local port=$1
    ! ss -tuln | grep -q ":$port "
}

# Find next available port starting from base
find_available_port() {
    local base_port=$1
    local current_port=$base_port
    
    while ! is_port_available $current_port; do
        ((current_port++))
        # Prevent infinite loop
        if [ $current_port -gt $((base_port + 1000)) ]; then
            print_error "Could not find available port starting from $base_port"
            exit 1
        fi
    done
    
    echo $current_port
}

# Get assigned ports for container
get_container_ports() {
    local container_name=$1
    
    if [ ! -f "$CONTAINER_REGISTRY" ]; then
        echo "{}" > "$CONTAINER_REGISTRY"
    fi
    
    # Check if container already has assigned ports
    if jq -e ".\"$container_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
        local http_port=$(jq -r ".\"$container_name\".ports.http" "$CONTAINER_REGISTRY")
        local ssh_port=$(jq -r ".\"$container_name\".ports.ssh" "$CONTAINER_REGISTRY")
        local ttyd_port=$(jq -r ".\"$container_name\".ports.ttyd" "$CONTAINER_REGISTRY")
        local audio_port=$(jq -r ".\"$container_name\".ports.audio" "$CONTAINER_REGISTRY")
        local pulse_port=$(jq -r ".\"$container_name\".ports.pulse" "$CONTAINER_REGISTRY")
        
        echo "$http_port:80,$ssh_port:22,$ttyd_port:7681,$audio_port:8080,$pulse_port:4713"
        return
    fi
    
    # Find available ports
    load_env
    local http_port=$(find_available_port $BASE_HTTP_PORT)
    local ssh_port=$(find_available_port $BASE_SSH_PORT)
    local ttyd_port=$(find_available_port $BASE_TTYD_PORT)
    local audio_port=$(find_available_port $BASE_AUDIO_PORT)
    local pulse_port=$(find_available_port $BASE_PULSE_PORT)
    
    # Store in registry
    local temp_file=$(mktemp)
    jq ".\"$container_name\" = {
        \"name\": \"webtop-$container_name\",
        \"ports\": {
            \"http\": $http_port,
            \"ssh\": $ssh_port,
            \"ttyd\": $ttyd_port,
            \"audio\": $audio_port,
            \"pulse\": $pulse_port
        },
        \"created\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"status\": \"assigned\"
    }" "$CONTAINER_REGISTRY" > "$temp_file" && mv "$temp_file" "$CONTAINER_REGISTRY"
    
    echo "$http_port:80,$ssh_port:22,$ttyd_port:7681,$audio_port:8080,$pulse_port:4713"
}

# Display help
show_help() {
    print_header
    echo
    echo -e "${CYAN}Usage: $0 [COMMAND] [OPTIONS]${NC}"
    echo
    echo -e "${YELLOW}COMMANDS:${NC}"
    echo "  build [--dev|--prod]     Build Docker image"
    echo "  up [--dev|--prod]        Start containers"
    echo "  down                     Stop and remove containers"
    echo "  logs                     Show container logs"
    echo "  status                   Show container status"
    echo "  shell                    Access container shell"
    echo "  web                      Open noVNC in browser"
    echo "  update                   Update and rebuild"
    echo "  clean                    Clean Docker system"
    echo
    echo -e "${YELLOW}MULTI-CONTAINER:${NC}"
    echo "  list                     List all managed containers"
    echo "  switch <name>            Switch context to container"
    echo "  remove <name>            Remove specific container"
    echo "  add-user <user:pass>     Add VNC authentication user"
    echo "  remove-user <user>       Remove VNC authentication user"
    echo "  list-users               List VNC authentication users"
    echo
    echo -e "${YELLOW}DEVELOPMENT:${NC}"
    echo "  dev-setup               Setup development environment"
    echo "  wine-setup              Configure Wine for Windows apps"
    echo "  android-setup           Setup Android/Waydroid environment"
    echo "  video-setup             Configure video editing tools"
    echo
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo "  --name=<name>            Custom container name"
    echo "  --ports=<mapping>        Custom port mapping"
    echo "  --auth                   Enable HTTP authentication"
    echo "  --dev                   Use development configuration"
    echo "  --prod                  Use production configuration"
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
    
    # Check if a custom container name was provided
    if [ -n "$CONTAINER_NAME" ]; then
        start_named_container "$CONTAINER_NAME" "$config"
        return
    fi
    
    print_status "Starting containers (${config} configuration)..."
    
    if [ ! -f "$compose_file" ]; then
        print_error "Docker Compose file not found: $compose_file"
        exit 1
    fi
    
    $DOCKER_COMPOSE_CMD -f "$compose_file" up -d
    
    print_success "Containers started successfully!"
    show_access_info "$config"
}

# Start named container with auto port assignment
start_named_container() {
    local container_name="$1"
    local config="$2"
    
    print_status "Starting container: $container_name (${config} configuration)..."
    
    # Get auto-assigned ports
    local port_mappings=$(get_container_ports "$container_name")
    
    # Setup authentication if enabled
    if [ "$ENABLE_AUTH" = "true" ] || [ "$VNC_AUTH_ENABLED" = "true" ]; then
        load_env
        ./auth-setup.sh setup "$container_name"
    fi
    
    # Create temporary docker-compose file for this container
    local temp_compose="docker-compose-${container_name}.yml"
    create_named_compose "$container_name" "$config" "$port_mappings" > "$temp_compose"
    
    # Start the container
    $DOCKER_COMPOSE_CMD -f "$temp_compose" up -d
    
    # Update registry status
    local temp_file=$(mktemp)
    jq ".\"$container_name\".status = \"running\"" "$CONTAINER_REGISTRY" > "$temp_file" && mv "$temp_file" "$CONTAINER_REGISTRY"
    
    print_success "Container '$container_name' started successfully!"
    show_named_container_info "$container_name"
    
    # Clean up temporary compose file
    rm -f "$temp_compose"
}

# Create docker-compose file for named container
create_named_compose() {
    local container_name="$1"
    local config="$2"
    local port_mappings="$3"
    
    # Parse port mappings
    local http_mapping=$(echo "$port_mappings" | cut -d',' -f1)
    local ssh_mapping=$(echo "$port_mappings" | cut -d',' -f2)
    local ttyd_mapping=$(echo "$port_mappings" | cut -d',' -f3)
    local audio_mapping=$(echo "$port_mappings" | cut -d',' -f4)
    local pulse_mapping=$(echo "$port_mappings" | cut -d',' -f5)
    
    cat << EOF
services:
  webtop:
    build: 
      context: .
      dockerfile: Dockerfile
    container_name: webtop-$container_name
    restart: unless-stopped
    privileged: true
    shm_size: "4gb"
    ports:
      - "$http_mapping"
      - "$ssh_mapping"
      - "$ttyd_mapping"
      - "$audio_mapping"
      - "$pulse_mapping"
    env_file:
      - .env
    volumes:
      - ${container_name}_config:/config
      - ${container_name}_logs:/var/log/supervisor
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
    devices:
      - /dev/snd:/dev/snd
    tmpfs:
      - /tmp
      - /run
      - /run/lock
    cap_add:
      - SYS_ADMIN
      - NET_ADMIN
    security_opt:
      - seccomp:unconfined
    healthcheck:
      test: ["CMD", "/usr/local/bin/health-check.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  ${container_name}_config:
  ${container_name}_logs:
EOF
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

# Show named container access information
show_named_container_info() {
    local container_name="$1"
    
    if [ ! -f "$CONTAINER_REGISTRY" ]; then
        print_error "Container registry not found"
        return 1
    fi
    
    local http_port=$(jq -r ".\"$container_name\".ports.http" "$CONTAINER_REGISTRY")
    local ssh_port=$(jq -r ".\"$container_name\".ports.ssh" "$CONTAINER_REGISTRY")
    local ttyd_port=$(jq -r ".\"$container_name\".ports.ttyd" "$CONTAINER_REGISTRY")
    local audio_port=$(jq -r ".\"$container_name\".ports.audio" "$CONTAINER_REGISTRY")
    local pulse_port=$(jq -r ".\"$container_name\".ports.pulse" "$CONTAINER_REGISTRY")
    
    echo
    print_success "Container '$container_name' is running!"
    echo
    echo -e "${CYAN}Access Points:${NC}"
    echo "  🌐 noVNC (Web):        http://localhost:$http_port"
    echo "  🔒 SSH:                ssh devuser@localhost -p $ssh_port"
    echo "  💻 Web Terminal:       http://localhost:$ttyd_port"
    echo "  🔊 Audio Bridge:       http://localhost:$audio_port"
    echo "  🎵 PulseAudio:         localhost:$pulse_port"
    echo
    echo -e "${YELLOW}Container Info:${NC}"
    echo "  📦 Name:               webtop-$container_name"
    echo "  🏷️  Label:              $container_name"
    echo "  📊 Registry:           $CONTAINER_REGISTRY"
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

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name=*)
                CONTAINER_NAME="${1#*=}"
                shift
                ;;
            --name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            --ports=*)
                CONTAINER_PORTS="${1#*=}"
                shift
                ;;
            --ports)
                CONTAINER_PORTS="$2"
                shift 2
                ;;
            --auth)
                ENABLE_AUTH="true"
                shift
                ;;
            *)
                break
                ;;
        esac
    done
}

# List all managed containers
list_containers() {
    if [ ! -f "$CONTAINER_REGISTRY" ]; then
        print_warning "No containers registered yet"
        return 0
    fi
    
    print_status "Managed Containers:"
    echo
    
    local containers=$(jq -r 'keys[]' "$CONTAINER_REGISTRY" 2>/dev/null)
    if [ -z "$containers" ]; then
        print_warning "No containers found in registry"
        return 0
    fi
    
    printf "%-15s %-20s %-10s %-15s %-10s\n" "NAME" "CONTAINER" "STATUS" "HTTP_PORT" "SSH_PORT"
    printf "%-15s %-20s %-10s %-15s %-10s\n" "----" "---------" "------" "---------" "--------"
    
    for container in $containers; do
        local container_id=$(jq -r ".\"$container\".name" "$CONTAINER_REGISTRY")
        local status=$(jq -r ".\"$container\".status" "$CONTAINER_REGISTRY")
        local http_port=$(jq -r ".\"$container\".ports.http" "$CONTAINER_REGISTRY")
        local ssh_port=$(jq -r ".\"$container\".ports.ssh" "$CONTAINER_REGISTRY")
        
        # Check if container is actually running
        if docker ps --format "table {{.Names}}" | grep -q "^$container_id$"; then
            status="running"
        else
            status="stopped"
        fi
        
        printf "%-15s %-20s %-10s %-15s %-10s\n" "$container" "$container_id" "$status" "$http_port" "$ssh_port"
    done
    echo
}

# Remove specific container
remove_container() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        print_error "Container name required"
        echo "Usage: $0 remove <container_name>"
        exit 1
    fi
    
    if [ ! -f "$CONTAINER_REGISTRY" ]; then
        print_error "Container registry not found"
        exit 1
    fi
    
    # Check if container exists in registry
    if ! jq -e ".\"$container_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
        print_error "Container '$container_name' not found in registry"
        exit 1
    fi
    
    local container_id="webtop-$container_name"
    
    print_status "Removing container: $container_name"
    
    # Stop and remove the container
    if docker ps -a --format "table {{.Names}}" | grep -q "^$container_id$"; then
        docker stop "$container_id" 2>/dev/null || true
        docker rm "$container_id" 2>/dev/null || true
        print_success "Container '$container_id' stopped and removed"
    fi
    
    # Remove volumes
    local volumes=$(docker volume ls --format "table {{.Name}}" | grep "^${container_name}_" || true)
    if [ -n "$volumes" ]; then
        echo "$volumes" | xargs docker volume rm 2>/dev/null || true
        print_success "Container volumes removed"
    fi
    
    # Remove from registry
    local temp_file=$(mktemp)
    jq "del(.\"$container_name\")" "$CONTAINER_REGISTRY" > "$temp_file" && mv "$temp_file" "$CONTAINER_REGISTRY"
    
    print_success "Container '$container_name' removed from registry"
}

# Show container info
show_container_info() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        print_error "Container name required"
        echo "Usage: $0 info <container_name>"
        exit 1
    fi
    
    if [ ! -f "$CONTAINER_REGISTRY" ] || ! jq -e ".\"$container_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
        print_error "Container '$container_name' not found in registry"
        exit 1
    fi
    
    show_named_container_info "$container_name"
}

# Open container in browser
open_container() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        print_error "Container name required"
        echo "Usage: $0 open <container_name>"
        exit 1
    fi
    
    if [ ! -f "$CONTAINER_REGISTRY" ] || ! jq -e ".\"$container_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
        print_error "Container '$container_name' not found in registry"
        exit 1
    fi
    
    local http_port=$(jq -r ".\"$container_name\".ports.http" "$CONTAINER_REGISTRY")
    local url="http://localhost:$http_port"
    
    print_status "Opening container '$container_name' at $url"
    
    if command -v xdg-open > /dev/null; then
        xdg-open "$url"
    elif command -v open > /dev/null; then
        open "$url"
    else
        echo "Please open $url in your browser"
    fi
}

# Connect to container via SSH
connect_container() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        print_error "Container name required"
        echo "Usage: $0 connect <container_name>"
        exit 1
    fi
    
    if [ ! -f "$CONTAINER_REGISTRY" ] || ! jq -e ".\"$container_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
        print_error "Container '$container_name' not found in registry"
        exit 1
    fi
    
    local ssh_port=$(jq -r ".\"$container_name\".ports.ssh" "$CONTAINER_REGISTRY")
    
    print_status "Connecting to container '$container_name' via SSH on port $ssh_port"
    ssh devuser@localhost -p "$ssh_port"
}

# Main command handling
main() {
    # Ensure jq is available for container registry management
    if ! command -v jq &> /dev/null; then
        print_status "Installing jq for container registry management..."
        if [ -f "./install-jq.sh" ]; then
            ./install-jq.sh
        else
            print_error "jq is required but not installed. Please install jq manually."
            exit 1
        fi
    fi
    
    # Initialize container registry if it doesn't exist
    if [ ! -f "$CONTAINER_REGISTRY" ]; then
        echo "{}" > "$CONTAINER_REGISTRY"
    fi
    
    # Parse arguments to extract --name, --ports, --auth
    parse_args "$@"
    
    # Remove parsed options to get the actual command
    local remaining_args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name=*|--ports=*|--auth)
                shift
                ;;
            --name|--ports)
                shift 2
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Restore remaining arguments
    set -- "${remaining_args[@]}"
    
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
        list)
            list_containers
            ;;
        remove)
            remove_container "$2"
            ;;
        info)
            show_container_info "$2"
            ;;
        open)
            open_container "$2"
            ;;
        connect)
            connect_container "$2"
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
#!/bin/bash

# Container lifecycle management functions
# Part of the modular webtop.sh refactoring

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
      - ${container_name}_home:/home/devuser
      - ${container_name}_wine:/home/devuser/.wine
      - ${container_name}_projects:/home/devuser/projects
      - ${container_name}_logs:/var/log/supervisor
      - shared_resources:/shared:ro
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
  ${container_name}_home:
  ${container_name}_wine:
  ${container_name}_projects:
  ${container_name}_logs:
  shared_resources:
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
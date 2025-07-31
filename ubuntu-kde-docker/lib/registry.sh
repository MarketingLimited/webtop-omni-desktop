#!/bin/bash

# Container registry management functions
# Part of the modular webtop.sh refactoring

# Get assigned ports for container
get_container_ports() {
    local container_name=$1
    
    ensure_jq
    
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
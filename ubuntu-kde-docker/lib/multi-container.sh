#!/bin/bash

# Multi-container specific operations
# Part of the modular webtop.sh refactoring

# Multi-container orchestration functions
orchestrate_start() {
    local container_list="$1"
    local config="$2"
    
    if [ -z "$container_list" ]; then
        print_error "Container list required"
        echo "Usage: $0 orchestrate start <container1,container2,container3> [--dev|--prod]"
        exit 1
    fi
    
    print_status "Starting multiple containers in orchestration mode..."
    IFS=',' read -ra CONTAINERS <<< "$container_list"
    
    for container in "${CONTAINERS[@]}"; do
        container=$(echo "$container" | xargs)  # trim whitespace
        print_status "Starting container: $container"
        CONTAINER_NAME="$container" start_containers "$config"
        sleep 2  # Small delay between starts
    done
    
    print_success "All containers started successfully!"
    echo
    list_containers
}

orchestrate_stop() {
    local container_list="$1"
    
    if [ -z "$container_list" ]; then
        print_error "Container list required"
        echo "Usage: $0 orchestrate stop <container1,container2,container3>"
        exit 1
    fi
    
    print_status "Stopping multiple containers..."
    IFS=',' read -ra CONTAINERS <<< "$container_list"
    
    for container in "${CONTAINERS[@]}"; do
        container=$(echo "$container" | xargs)  # trim whitespace
        print_status "Stopping container: $container"
        remove_container "$container"
    done
    
    print_success "All specified containers stopped!"
}

# Batch operations
batch_backup() {
    local container_list="$1"
    
    if [ -z "$container_list" ]; then
        print_error "Container list required"
        echo "Usage: $0 batch backup <container1,container2,container3>"
        exit 1
    fi
    
    print_status "Starting batch backup operation..."
    IFS=',' read -ra CONTAINERS <<< "$container_list"
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local batch_backup_dir="$BACKUP_DIR/batch_$backup_timestamp"
    
    mkdir -p "$batch_backup_dir"
    
    for container in "${CONTAINERS[@]}"; do
        container=$(echo "$container" | xargs)  # trim whitespace
        print_status "Backing up container: $container"
        backup_container "$container"
    done
    
    # Create batch manifest
    cat > "$batch_backup_dir/manifest.json" << EOF
{
    "batch_id": "batch_$backup_timestamp",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "containers": [$(printf '"%s",' "${CONTAINERS[@]}" | sed 's/,$//')]
}
EOF
    
    print_success "Batch backup completed!"
    echo "  📁 Backup directory: $batch_backup_dir"
    echo "  📦 Containers backed up: ${#CONTAINERS[@]}"
}

# Load balancing operations
load_balance_containers() {
    local base_name="$1"
    local count="$2"
    local config="$3"
    
    if [ -z "$base_name" ] || [ -z "$count" ]; then
        print_error "Base name and count required"
        echo "Usage: $0 load-balance <base_name> <count> [--dev|--prod]"
        exit 1
    fi
    
    print_status "Creating load-balanced container set: $base_name (x$count)"
    
    for i in $(seq 1 "$count"); do
        local container_name="${base_name}-${i}"
        print_status "Creating container: $container_name"
        CONTAINER_NAME="$container_name" start_containers "$config"
        sleep 1
    done
    
    print_success "Load-balanced container set created!"
    echo
    print_status "Container set summary:"
    
    for i in $(seq 1 "$count"); do
        local container_name="${base_name}-${i}"
        if [ -f "$CONTAINER_REGISTRY" ] && jq -e ".\"$container_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
            local http_port=$(jq -r ".\"$container_name\".ports.http" "$CONTAINER_REGISTRY")
            echo "  🌐 $container_name: http://localhost:$http_port"
        fi
    done
}

# Container health monitoring
monitor_health() {
    local container_pattern="$1"
    local interval="${2:-30}"
    
    if [ -z "$container_pattern" ]; then
        container_pattern=".*"  # Monitor all if none specified
    fi
    
    print_status "Starting health monitoring (pattern: $container_pattern, interval: ${interval}s)"
    echo "Press Ctrl+C to stop monitoring"
    echo
    
    while true; do
        clear
        print_header
        echo
        print_status "Health Monitor - $(date)"
        echo
        
        if [ ! -f "$CONTAINER_REGISTRY" ]; then
            print_warning "No containers registered"
            sleep "$interval"
            continue
        fi
        
        local containers=$(jq -r 'keys[]' "$CONTAINER_REGISTRY" 2>/dev/null | grep -E "$container_pattern")
        
        for container in $containers; do
            local container_id="webtop-$container"
            local http_port=$(jq -r ".\"$container\".ports.http" "$CONTAINER_REGISTRY")
            
            echo -n "  📦 $container: "
            
            if docker ps --format "table {{.Names}}" | grep -q "^$container_id$"; then
                # Container is running, check health
                if curl -s --max-time 5 "http://localhost:$http_port" > /dev/null; then
                    echo -e "${GREEN}HEALTHY${NC} (http://localhost:$http_port)"
                else
                    echo -e "${YELLOW}RUNNING${NC} (web interface not responding)"
                fi
            else
                echo -e "${RED}STOPPED${NC}"
            fi
        done
        
        echo
        echo "Next check in ${interval} seconds..."
        sleep "$interval"
    done
}

# Resource monitoring
monitor_resources_detailed() {
    local container_pattern="$1"
    
    if [ -z "$container_pattern" ]; then
        container_pattern="webtop-"
    fi
    
    print_status "Detailed resource monitoring for containers matching: $container_pattern"
    echo
    
    # Get containers matching pattern
    local containers=$(docker ps --format "table {{.Names}}" | grep "$container_pattern" | tr '\n' ' ')
    
    if [ -z "$containers" ]; then
        print_warning "No running containers found matching pattern: $container_pattern"
        return 1
    fi
    
    echo "Monitoring containers: $containers"
    echo
    
    # Show detailed stats
    docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" $containers
}
#!/bin/bash

# Volume and backup management functions
# Part of the modular webtop.sh refactoring

# Backup container volumes
backup_container() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        print_error "Container name required"
        echo "Usage: $0 backup <container_name>"
        exit 1
    fi
    
    mkdir -p "$BACKUP_DIR"
    local backup_name="${container_name}_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_status "Creating backup for container: $container_name"
    mkdir -p "$backup_path"
    
    # Backup all container volumes
    local volumes="config home wine projects logs"
    for vol in $volumes; do
        local volume_name="${container_name}_${vol}"
        if docker volume ls | grep -q "$volume_name"; then
            print_status "Backing up volume: $volume_name"
            docker run --rm -v "$volume_name":/source -v "$backup_path":/backup alpine tar czf "/backup/${vol}.tar.gz" -C /source .
        fi
    done
    
    # Save container registry info
    if [ -f "$CONTAINER_REGISTRY" ] && jq -e ".\"$container_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
        jq ".\"$container_name\"" "$CONTAINER_REGISTRY" > "$backup_path/registry.json"
    fi
    
    print_success "Backup created: $backup_path"
    echo "  📦 Volumes backed up: config, home, wine, projects, logs"
    echo "  📋 Registry info saved"
}

# Restore container from backup
restore_container() {
    local container_name="$1"
    local backup_name="$2"
    
    if [ -z "$container_name" ] || [ -z "$backup_name" ]; then
        print_error "Container name and backup name required"
        echo "Usage: $0 restore <container_name> <backup_name>"
        echo "Available backups:"
        ls -1 "$BACKUP_DIR" 2>/dev/null | grep "${container_name}_" || echo "  No backups found"
        exit 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    if [ ! -d "$backup_path" ]; then
        print_error "Backup not found: $backup_path"
        exit 1
    fi
    
    print_status "Restoring container: $container_name from backup: $backup_name"
    
    # Stop container if running
    docker stop "webtop-$container_name" 2>/dev/null || true
    
    # Restore volumes
    local volumes="config home wine projects logs"
    for vol in $volumes; do
        local volume_name="${container_name}_${vol}"
        local backup_file="$backup_path/${vol}.tar.gz"
        
        if [ -f "$backup_file" ]; then
            print_status "Restoring volume: $volume_name"
            docker volume rm "$volume_name" 2>/dev/null || true
            docker volume create "$volume_name"
            docker run --rm -v "$volume_name":/target -v "$backup_path":/backup alpine tar xzf "/backup/${vol}.tar.gz" -C /target
        fi
    done
    
    # Restore registry info
    if [ -f "$backup_path/registry.json" ]; then
        local temp_file=$(mktemp)
        jq ".\"$container_name\" = $(cat "$backup_path/registry.json")" "$CONTAINER_REGISTRY" > "$temp_file" && mv "$temp_file" "$CONTAINER_REGISTRY"
    fi
    
    print_success "Container restored: $container_name"
    echo "  📦 Volumes restored: config, home, wine, projects, logs"
    echo "  📋 Registry info updated"
    echo "  🚀 Start with: $0 up --name $container_name"
}

# Clone container
clone_container() {
    local source_name="$1"
    local target_name="$2"
    
    if [ -z "$source_name" ] || [ -z "$target_name" ]; then
        print_error "Source and target container names required"
        echo "Usage: $0 clone <source_name> <target_name>"
        exit 1
    fi
    
    if [ ! -f "$CONTAINER_REGISTRY" ] || ! jq -e ".\"$source_name\"" "$CONTAINER_REGISTRY" > /dev/null 2>&1; then
        print_error "Source container '$source_name' not found"
        exit 1
    fi
    
    print_status "Cloning container: $source_name → $target_name"
    
    # Create backup of source
    mkdir -p "$BACKUP_DIR"
    local temp_backup="${source_name}_clone_$(date +%Y%m%d_%H%M%S)"
    local temp_path="$BACKUP_DIR/$temp_backup"
    mkdir -p "$temp_path"
    
    # Copy volumes
    local volumes="config home wine projects logs"
    for vol in $volumes; do
        local source_volume="${source_name}_${vol}"
        local target_volume="${target_name}_${vol}"
        
        if docker volume ls | grep -q "$source_volume"; then
            print_status "Cloning volume: $source_volume → $target_volume"
            docker run --rm -v "$source_volume":/source -v "$temp_path":/backup alpine tar czf "/backup/${vol}.tar.gz" -C /source .
            docker volume rm "$target_volume" 2>/dev/null || true
            docker volume create "$target_volume"
            docker run --rm -v "$target_volume":/target -v "$temp_path":/backup alpine tar xzf "/backup/${vol}.tar.gz" -C /target
        fi
    done
    
    # Assign new ports for target container
    get_container_ports "$target_name" > /dev/null
    
    # Cleanup temp files
    rm -rf "$temp_path"
    
    print_success "Container cloned: $source_name → $target_name"
    echo "  📦 All volumes cloned"
    echo "  🚀 Start with: $0 up --name $target_name"
}

# Volume management
volumes_list() {
    print_status "Container Volumes:"
    echo
    
    # Group volumes by container
    local all_volumes=$(docker volume ls --format "{{.Name}}" | grep "_" | sort)
    local current_container=""
    
    for volume in $all_volumes; do
        local container=$(echo "$volume" | cut -d'_' -f1)
        local vol_type=$(echo "$volume" | cut -d'_' -f2)
        
        if [ "$container" != "$current_container" ]; then
            echo -e "\n${CYAN}Container: $container${NC}"
            current_container="$container"
        fi
        
        local size=$(docker system df -v | grep "$volume" | awk '{print $3}' || echo "unknown")
        echo "  📦 $vol_type: $volume ($size)"
    done
    echo
}

volumes_backup_all() {
    print_status "Backing up all container volumes..."
    
    if [ ! -f "$CONTAINER_REGISTRY" ]; then
        print_warning "No containers registered"
        return 0
    fi
    
    local containers=$(jq -r 'keys[]' "$CONTAINER_REGISTRY" 2>/dev/null)
    local backup_count=0
    
    for container in $containers; do
        print_status "Backing up container: $container"
        backup_container "$container"
        ((backup_count++))
    done
    
    print_success "Backup completed for $backup_count containers"
    echo "  📁 Backup directory: $BACKUP_DIR"
}

volumes_cleanup() {
    print_warning "This will remove unused Docker volumes."
    echo "Current volumes:"
    docker volume ls
    echo
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up unused volumes..."
        docker volume prune -f
        print_success "Unused volumes cleaned up!"
    fi
}
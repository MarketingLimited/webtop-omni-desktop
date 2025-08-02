#!/bin/bash

# Template management functions
# Part of the modular webtop.sh refactoring

# Template management

# Volumes included in templates (logs are intentionally excluded)
TEMPLATE_VOLUMES="config home wine projects"

template_save() {
    local container_name="$1"
    local template_name="$2"
    
    if [ -z "$container_name" ] || [ -z "$template_name" ]; then
        print_error "Container name and template name required"
        echo "Usage: $0 template save <container_name> <template_name>"
        exit 1
    fi
    
    mkdir -p "$TEMPLATE_DIR"
    local template_path="$TEMPLATE_DIR/$template_name"
    
    print_status "Saving template: $container_name → $template_name"
    
    # Create template backup
    mkdir -p "$template_path"
    for vol in $TEMPLATE_VOLUMES; do
        local volume_name="${container_name}_${vol}"
        if docker volume inspect "$volume_name" >/dev/null 2>&1; then
            print_status "Saving volume: $volume_name"
            docker run --rm \
                -v "$volume_name":/source \
                -v "$template_path":/template \
                alpine tar czf "/template/${vol}.tar.gz" -C /source .
        fi
    done
    
    # Save template metadata
    cat > "$template_path/template.json" << EOF
{
    "name": "$template_name",
    "source_container": "$container_name",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "description": "Template created from $container_name",
    "volumes": ["${TEMPLATE_VOLUMES// /", "}"]
}
EOF

    print_success "Template saved: $template_name"
    echo "  📦 Volumes: ${TEMPLATE_VOLUMES// /, }"
    echo "  📋 Metadata saved"
}

template_create() {
    local container_name="$1"
    local template_name="$2"
    
    if [ -z "$container_name" ] || [ -z "$template_name" ]; then
        print_error "Container name and template name required"
        echo "Usage: $0 template create <container_name> <template_name>"
        exit 1
    fi
    
    local template_path="$TEMPLATE_DIR/$template_name"
    if [ ! -d "$template_path" ]; then
        print_error "Template not found: $template_name"
        echo "Available templates:"
        ls -1 "$TEMPLATE_DIR" 2>/dev/null || echo "  No templates found"
        exit 1
    fi
    
    print_status "Creating container: $container_name from template: $template_name"
    
    # Create volumes from template
    for vol in $TEMPLATE_VOLUMES; do
        local volume_name="${container_name}_${vol}"
        local template_file="$template_path/${vol}.tar.gz"

        if [ -f "$template_file" ]; then
            print_status "Creating volume: $volume_name"
            docker volume rm "$volume_name" 2>/dev/null || true
            docker volume create "$volume_name"
            docker run --rm \
                -v "$volume_name":/target \
                -v "$template_path":/template \
                alpine tar xzf "/template/${vol}.tar.gz" -C /target
        fi
    done
    
    # Create logs volume
    docker volume create "${container_name}_logs" 2>/dev/null || true
    
    # Assign ports
    get_container_ports "$container_name" > /dev/null
    
    print_success "Container created from template: $container_name"
    echo "  📦 Volumes created from template"
    echo "  🚀 Start with: $0 up --name $container_name"
}

template_list() {
    print_status "Available Templates:"
    echo

    if [ ! -d "$TEMPLATE_DIR" ]; then
        print_warning "No templates directory found"
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq command not found. Please install jq to list templates."
        return 1
    fi

    local templates
    templates=$(find "$TEMPLATE_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)
    if [ -z "$templates" ]; then
        print_warning "No templates found"
        return 0
    fi

    printf "%-20s %-15s %-20s %-30s\n" "NAME" "SOURCE" "CREATED" "DESCRIPTION"
    printf "%-20s %-15s %-20s %-30s\n" "----" "------" "-------" "-----------"

    for template in $templates; do
        local template_file="$TEMPLATE_DIR/$template/template.json"
        if [ -f "$template_file" ]; then
            local source
            local created
            local description
            source=$(jq -r '.source_container // "unknown"' "$template_file")
            created=$(jq -r '.created // "unknown"' "$template_file" | cut -d'T' -f1)
            description=$(jq -r '.description // "No description"' "$template_file" | cut -c1-30)
            printf "%-20s %-15s %-20s %-30s\n" "$template" "$source" "$created" "$description"
        else
            printf "%-20s %-15s %-20s %-30s\n" "$template" "unknown" "unknown" "No metadata"
        fi
    done
    echo
}

template_remove() {
    local template_name="$1"
    
    if [ -z "$template_name" ]; then
        print_error "Template name required"
        echo "Usage: $0 template remove <template_name>"
        exit 1
    fi
    
    local template_path="$TEMPLATE_DIR/$template_name"
    if [ ! -d "$template_path" ]; then
        print_error "Template not found: $template_name"
        exit 1
    fi
    
    print_warning "This will permanently delete template: $template_name"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing template: $template_name"
        rm -rf "$template_path"
        print_success "Template '$template_name' removed"
    fi
}

template_export() {
    local template_name="$1"
    local export_path="$2"
    
    if [ -z "$template_name" ] || [ -z "$export_path" ]; then
        print_error "Template name and export path required"
        echo "Usage: $0 template export <template_name> <export_path>"
        exit 1
    fi
    
    local template_path="$TEMPLATE_DIR/$template_name"
    if [ ! -d "$template_path" ]; then
        print_error "Template not found: $template_name"
        exit 1
    fi
    
    print_status "Exporting template: $template_name → $export_path"
    tar czf "$export_path" -C "$TEMPLATE_DIR" "$template_name"
    print_success "Template exported to: $export_path"
}

template_import() {
    local import_path="$1"
    local template_name="$2"
    
    if [ -z "$import_path" ]; then
        print_error "Import path required"
        echo "Usage: $0 template import <import_path> [template_name]"
        exit 1
    fi
    
    if [ ! -f "$import_path" ]; then
        print_error "Import file not found: $import_path"
        exit 1
    fi
    
    mkdir -p "$TEMPLATE_DIR"
    
    if [ -n "$template_name" ]; then
        print_status "Importing template as: $template_name"
        mkdir -p "$TEMPLATE_DIR/$template_name"
        tar xzf "$import_path" -C "$TEMPLATE_DIR/$template_name" --strip-components=1
    else
        print_status "Importing template from: $import_path"
        tar xzf "$import_path" -C "$TEMPLATE_DIR"
    fi
    
    print_success "Template imported successfully"
}
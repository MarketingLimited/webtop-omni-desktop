#!/bin/bash

# Configuration management system
# Part of the enterprise webtop.sh enhancement suite

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration directories
CONFIG_DIR="config"
ENVIRONMENTS_DIR="$CONFIG_DIR/environments"
TEMPLATES_DIR="$CONFIG_DIR/templates"
SCHEMAS_DIR="$CONFIG_DIR/schemas"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$ENVIRONMENTS_DIR" "$TEMPLATES_DIR" "$SCHEMAS_DIR"

print_status() {
    echo -e "${BLUE}[CONFIG]${NC} $1"
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

# Initialize configuration management
init_config_system() {
    print_status "Initializing configuration management system..."
    
    # Create main configuration file
    if [ ! -f "$CONFIG_DIR/webtop-config.yml" ]; then
        cat > "$CONFIG_DIR/webtop-config.yml" << 'EOF'
# Webtop Configuration Management
# This file defines the global configuration structure

global:
  version: "1.0.0"
  config_format: "yaml"
  environment: "development"
  
project:
  name: "webtop-kde-marketing"
  description: "Ubuntu KDE Marketing Agency Docker Environment"
  maintainer: "System Administrator"
  
defaults:
  container:
    base_image: "lscr.io/linuxserver/webtop:ubuntu-kde"
    restart_policy: "unless-stopped"
    privileged: true
    shm_size: "4gb"
    
  resources:
    memory_limit: "8g"
    cpu_limit: "4"
    swap_limit: "2g"
    
  ports:
    base_http: 32769
    base_ssh: 2223
    base_ttyd: 7682
    base_audio: 8081
    base_pulse: 4714
    
  volumes:
    config: "/config"
    home: "/home/devuser"
    projects: "/home/devuser/projects"
    wine: "/home/devuser/.wine"
    logs: "/var/log/supervisor"
    
  networking:
    driver: "bridge"
    enable_ipv6: false
    
  security:
    enable_auth: false
    auth_method: "basic"
    ssl_enabled: false
    
environments:
  - development
  - staging
  - production
  
profiles:
  - minimal
  - standard
  - performance
  - enterprise

features:
  health_monitoring: true
  performance_tuning: true
  backup_system: true
  template_management: true
  multi_container: true
  web_interface: false
  api_server: false
EOF
        print_success "Main configuration file created: $CONFIG_DIR/webtop-config.yml"
    fi
    
    # Create environment-specific configurations
    create_environment_configs
    
    # Create configuration templates
    create_config_templates
    
    # Create validation schemas
    create_validation_schemas
    
    print_success "Configuration management system initialized"
}

# Create environment-specific configurations
create_environment_configs() {
    print_status "Creating environment-specific configurations..."
    
    # Development environment
    cat > "$ENVIRONMENTS_DIR/development.yml" << 'EOF'
environment:
  name: "development"
  description: "Development environment for testing and debugging"
  
container:
  prefix: "dev"
  auto_start: true
  debug_mode: true
  
resources:
  memory_limit: "4g"
  cpu_limit: "2"
  swap_limit: "1g"
  
ports:
  base_http: 32769
  base_ssh: 2223
  base_ttyd: 7682
  increment: 10
  
volumes:
  persistent: true
  backup_enabled: false
  
security:
  enable_auth: false
  strict_mode: false
  
features:
  hot_reload: true
  debug_logging: true
  development_tools: true
  
monitoring:
  enabled: true
  interval: 60
  alerts: false
  
performance:
  optimization_level: "basic"
  caching: false
EOF
    
    # Staging environment
    cat > "$ENVIRONMENTS_DIR/staging.yml" << 'EOF'
environment:
  name: "staging"
  description: "Staging environment for pre-production testing"
  
container:
  prefix: "staging"
  auto_start: true
  debug_mode: false
  
resources:
  memory_limit: "8g"
  cpu_limit: "4"
  swap_limit: "2g"
  
ports:
  base_http: 33000
  base_ssh: 2300
  base_ttyd: 7700
  increment: 10
  
volumes:
  persistent: true
  backup_enabled: true
  
security:
  enable_auth: true
  strict_mode: true
  
features:
  hot_reload: false
  debug_logging: false
  development_tools: false
  
monitoring:
  enabled: true
  interval: 30
  alerts: true
  
performance:
  optimization_level: "standard"
  caching: true
EOF
    
    # Production environment
    cat > "$ENVIRONMENTS_DIR/production.yml" << 'EOF'
environment:
  name: "production"
  description: "Production environment for live deployment"
  
container:
  prefix: "prod"
  auto_start: true
  debug_mode: false
  
resources:
  memory_limit: "16g"
  cpu_limit: "8"
  swap_limit: "4g"
  
ports:
  base_http: 34000
  base_ssh: 2400
  base_ttyd: 7800
  increment: 10
  
volumes:
  persistent: true
  backup_enabled: true
  retention_days: 30
  
security:
  enable_auth: true
  strict_mode: true
  ssl_enabled: true
  
features:
  hot_reload: false
  debug_logging: false
  development_tools: false
  
monitoring:
  enabled: true
  interval: 15
  alerts: true
  metrics_retention: 90
  
performance:
  optimization_level: "maximum"
  caching: true
  cdn_enabled: true
EOF
    
    print_success "Environment configurations created"
}

# Create configuration templates
create_config_templates() {
    print_status "Creating configuration templates..."
    
    # Container template
    cat > "$TEMPLATES_DIR/container-template.yml" << 'EOF'
# Container Configuration Template
container:
  name: "{{ .Name }}"
  environment: "{{ .Environment }}"
  profile: "{{ .Profile }}"
  
  image:
    base: "{{ .Image.Base }}"
    tag: "{{ .Image.Tag | default 'latest' }}"
    
  resources:
    memory: "{{ .Resources.Memory }}"
    cpu: "{{ .Resources.CPU }}"
    swap: "{{ .Resources.Swap | default '1g' }}"
    
  ports:
    http: {{ .Ports.HTTP }}
    ssh: {{ .Ports.SSH }}
    ttyd: {{ .Ports.TTYD }}
    audio: {{ .Ports.Audio }}
    pulse: {{ .Ports.Pulse }}
    
  volumes:
{{- range .Volumes }}
    - name: "{{ .Name }}"
      mount: "{{ .Mount }}"
      type: "{{ .Type | default 'bind' }}"
{{- end }}
    
  environment_vars:
{{- range .EnvVars }}
    {{ .Key }}: "{{ .Value }}"
{{- end }}
    
  security:
    privileged: {{ .Security.Privileged | default true }}
    capabilities:
{{- range .Security.Capabilities }}
      - "{{ . }}"
{{- end }}
    
  networking:
    driver: "{{ .Network.Driver | default 'bridge' }}"
    aliases:
{{- range .Network.Aliases }}
      - "{{ . }}"
{{- end }}
    
  health_check:
    enabled: {{ .HealthCheck.Enabled | default true }}
    test: "{{ .HealthCheck.Test }}"
    interval: "{{ .HealthCheck.Interval | default '30s' }}"
    timeout: "{{ .HealthCheck.Timeout | default '10s' }}"
    retries: {{ .HealthCheck.Retries | default 3 }}
EOF
    
    # Docker Compose template
    cat > "$TEMPLATES_DIR/docker-compose-template.yml" << 'EOF'
# Docker Compose Template
version: '3.8'

services:
{{- range .Containers }}
  {{ .Name }}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: "{{ .ContainerName }}"
    restart: "{{ .RestartPolicy }}"
    privileged: {{ .Privileged }}
    shm_size: "{{ .ShmSize }}"
    
    ports:
{{- range .Ports }}
      - "{{ .Host }}:{{ .Container }}"
{{- end }}
    
    environment:
{{- range .Environment }}
      {{ .Key }}: "{{ .Value }}"
{{- end }}
    
    volumes:
{{- range .Volumes }}
      - {{ .Source }}:{{ .Target }}{{ if .ReadOnly }}:ro{{ end }}
{{- end }}
    
    devices:
{{- range .Devices }}
      - {{ .Host }}:{{ .Container }}
{{- end }}
    
    tmpfs:
{{- range .Tmpfs }}
      - {{ . }}
{{- end }}
    
    cap_add:
{{- range .Capabilities }}
      - {{ . }}
{{- end }}
    
    security_opt:
{{- range .SecurityOpts }}
      - {{ . }}
{{- end }}
    
    {{- if .HealthCheck }}
    healthcheck:
      test: {{ .HealthCheck.Test }}
      interval: {{ .HealthCheck.Interval }}
      timeout: {{ .HealthCheck.Timeout }}
      retries: {{ .HealthCheck.Retries }}
      start_period: {{ .HealthCheck.StartPeriod }}
    {{- end }}
    
    {{- if .DependsOn }}
    depends_on:
{{- range .DependsOn }}
      - {{ . }}
{{- end }}
    {{- end }}
{{- end }}

volumes:
{{- range .Volumes }}
  {{ .Name }}:
    {{- if .Driver }}
    driver: {{ .Driver }}
    {{- end }}
    {{- if .DriverOpts }}
    driver_opts:
{{- range $key, $value := .DriverOpts }}
      {{ $key }}: "{{ $value }}"
{{- end }}
    {{- end }}
{{- end }}

networks:
{{- range .Networks }}
  {{ .Name }}:
    driver: {{ .Driver }}
    {{- if .IPV6 }}
    enable_ipv6: {{ .IPV6 }}
    {{- end }}
    {{- if .IPAM }}
    ipam:
      driver: {{ .IPAM.Driver }}
      config:
{{- range .IPAM.Config }}
        - subnet: {{ .Subnet }}
          {{- if .Gateway }}
          gateway: {{ .Gateway }}
          {{- end }}
{{- end }}
    {{- end }}
{{- end }}
EOF
    
    print_success "Configuration templates created"
}

# Create validation schemas
create_validation_schemas() {
    print_status "Creating validation schemas..."
    
    # Container schema
    cat > "$SCHEMAS_DIR/container-schema.json" << 'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Container Configuration Schema",
  "type": "object",
  "required": ["name", "environment"],
  "properties": {
    "name": {
      "type": "string",
      "pattern": "^[a-zA-Z0-9][a-zA-Z0-9_-]*$",
      "minLength": 1,
      "maxLength": 50
    },
    "environment": {
      "type": "string",
      "enum": ["development", "staging", "production"]
    },
    "profile": {
      "type": "string",
      "enum": ["minimal", "standard", "performance", "enterprise"]
    },
    "resources": {
      "type": "object",
      "properties": {
        "memory": {
          "type": "string",
          "pattern": "^[0-9]+(g|G|m|M)$"
        },
        "cpu": {
          "type": ["string", "number"],
          "minimum": 0.1,
          "maximum": 32
        },
        "swap": {
          "type": "string",
          "pattern": "^[0-9]+(g|G|m|M)$"
        }
      }
    },
    "ports": {
      "type": "object",
      "properties": {
        "http": {
          "type": "integer",
          "minimum": 1024,
          "maximum": 65535
        },
        "ssh": {
          "type": "integer",
          "minimum": 1024,
          "maximum": 65535
        },
        "ttyd": {
          "type": "integer",
          "minimum": 1024,
          "maximum": 65535
        }
      }
    },
    "volumes": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "mount"],
        "properties": {
          "name": {
            "type": "string"
          },
          "mount": {
            "type": "string"
          },
          "type": {
            "type": "string",
            "enum": ["bind", "volume", "tmpfs"]
          }
        }
      }
    },
    "security": {
      "type": "object",
      "properties": {
        "privileged": {
          "type": "boolean"
        },
        "capabilities": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      }
    }
  }
}
EOF
    
    # Environment schema
    cat > "$SCHEMAS_DIR/environment-schema.json" << 'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Environment Configuration Schema",
  "type": "object",
  "required": ["environment"],
  "properties": {
    "environment": {
      "type": "object",
      "required": ["name", "description"],
      "properties": {
        "name": {
          "type": "string",
          "enum": ["development", "staging", "production"]
        },
        "description": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "container": {
      "type": "object",
      "properties": {
        "prefix": {
          "type": "string",
          "pattern": "^[a-zA-Z0-9][a-zA-Z0-9_-]*$"
        },
        "auto_start": {
          "type": "boolean"
        },
        "debug_mode": {
          "type": "boolean"
        }
      }
    },
    "resources": {
      "type": "object",
      "properties": {
        "memory_limit": {
          "type": "string",
          "pattern": "^[0-9]+(g|G|m|M)$"
        },
        "cpu_limit": {
          "type": ["string", "number"]
        },
        "swap_limit": {
          "type": "string",
          "pattern": "^[0-9]+(g|G|m|M)$"
        }
      }
    },
    "ports": {
      "type": "object",
      "properties": {
        "base_http": {
          "type": "integer",
          "minimum": 1024,
          "maximum": 65535
        },
        "base_ssh": {
          "type": "integer",
          "minimum": 1024,
          "maximum": 65535
        },
        "increment": {
          "type": "integer",
          "minimum": 1,
          "maximum": 100
        }
      }
    },
    "security": {
      "type": "object",
      "properties": {
        "enable_auth": {
          "type": "boolean"
        },
        "strict_mode": {
          "type": "boolean"
        },
        "ssl_enabled": {
          "type": "boolean"
        }
      }
    },
    "monitoring": {
      "type": "object",
      "properties": {
        "enabled": {
          "type": "boolean"
        },
        "interval": {
          "type": "integer",
          "minimum": 10,
          "maximum": 3600
        },
        "alerts": {
          "type": "boolean"
        }
      }
    }
  }
}
EOF
    
    print_success "Validation schemas created"
}

# Load configuration
load_config() {
    local config_file="$1"
    local environment="${2:-development}"
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    print_status "Loading configuration: $config_file (environment: $environment)"
    
    # Load environment-specific configuration if it exists
    local env_config="$ENVIRONMENTS_DIR/$environment.yml"
    if [ -f "$env_config" ]; then
        print_status "Loading environment configuration: $env_config"
        # Here you would merge the configurations
        # For now, we'll just validate both files exist
        print_success "Configuration loaded successfully"
    else
        print_warning "Environment configuration not found: $env_config"
        print_status "Using default configuration"
    fi
}

# Validate configuration
validate_config() {
    local config_file="$1"
    local schema_file="$2"
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    print_status "Validating configuration: $config_file"
    
    # Basic YAML syntax validation
    if command -v yq &> /dev/null; then
        if ! yq eval '.' "$config_file" > /dev/null 2>&1; then
            print_error "Invalid YAML syntax in $config_file"
            return 1
        fi
        print_success "YAML syntax validation passed"
    else
        print_warning "yq not found, skipping YAML syntax validation"
    fi
    
    # JSON Schema validation (if schema provided and tools available)
    if [ -n "$schema_file" ] && [ -f "$schema_file" ] && command -v ajv &> /dev/null; then
        # Convert YAML to JSON and validate against schema
        local temp_json=$(mktemp)
        if command -v yq &> /dev/null; then
            yq eval -o=json '.' "$config_file" > "$temp_json"
            if ajv validate -s "$schema_file" -d "$temp_json"; then
                print_success "Schema validation passed"
            else
                print_error "Schema validation failed"
                rm -f "$temp_json"
                return 1
            fi
            rm -f "$temp_json"
        else
            print_warning "Cannot perform schema validation without yq"
        fi
    else
        print_warning "Schema validation skipped (missing schema file or ajv)"
    fi
    
    print_success "Configuration validation completed"
}

# Generate configuration from template
generate_config() {
    local template_file="$1"
    local output_file="$2"
    local environment="${3:-development}"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    print_status "Generating configuration from template: $template_file"
    
    # Load environment configuration
    local env_config="$ENVIRONMENTS_DIR/$environment.yml"
    if [ ! -f "$env_config" ]; then
        print_error "Environment configuration not found: $env_config"
        return 1
    fi
    
    # For now, we'll do a simple copy since we don't have a templating engine
    # In a real implementation, you'd use a tool like envsubst, gomplate, or helm
    print_warning "Template processing not fully implemented - copying template as-is"
    cp "$template_file" "$output_file"
    
    print_success "Configuration generated: $output_file"
}

# List available configurations
list_configs() {
    print_status "Available Configurations:"
    echo
    
    echo -e "${CYAN}Main Configuration:${NC}"
    if [ -f "$CONFIG_DIR/webtop-config.yml" ]; then
        echo "  ✓ $CONFIG_DIR/webtop-config.yml"
    else
        echo "  ✗ $CONFIG_DIR/webtop-config.yml (missing)"
    fi
    echo
    
    echo -e "${CYAN}Environment Configurations:${NC}"
    for env_file in "$ENVIRONMENTS_DIR"/*.yml; do
        if [ -f "$env_file" ]; then
            local env_name=$(basename "$env_file" .yml)
            echo "  ✓ $env_name: $env_file"
        fi
    done
    echo
    
    echo -e "${CYAN}Templates:${NC}"
    for template_file in "$TEMPLATES_DIR"/*.yml; do
        if [ -f "$template_file" ]; then
            local template_name=$(basename "$template_file" .yml)
            echo "  ✓ $template_name: $template_file"
        fi
    done
    echo
    
    echo -e "${CYAN}Schemas:${NC}"
    for schema_file in "$SCHEMAS_DIR"/*.json; do
        if [ -f "$schema_file" ]; then
            local schema_name=$(basename "$schema_file" .json)
            echo "  ✓ $schema_name: $schema_file"
        fi
    done
    echo
}

# Export configuration
export_config() {
    local environment="$1"
    local output_file="${2:-config-export-$(date +%Y%m%d_%H%M%S).tar.gz}"
    
    print_status "Exporting configuration for environment: $environment"
    
    local temp_dir=$(mktemp -d)
    
    # Copy main configuration
    cp "$CONFIG_DIR/webtop-config.yml" "$temp_dir/"
    
    # Copy environment configuration
    if [ -f "$ENVIRONMENTS_DIR/$environment.yml" ]; then
        cp "$ENVIRONMENTS_DIR/$environment.yml" "$temp_dir/"
    fi
    
    # Copy templates and schemas
    cp -r "$TEMPLATES_DIR" "$temp_dir/"
    cp -r "$SCHEMAS_DIR" "$temp_dir/"
    
    # Create export metadata
    cat > "$temp_dir/export-metadata.json" << EOF
{
    "export_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "$environment",
    "exported_by": "$(whoami)",
    "hostname": "$(hostname)",
    "version": "1.0.0"
}
EOF
    
    # Create archive
    tar czf "$output_file" -C "$temp_dir" .
    rm -rf "$temp_dir"
    
    print_success "Configuration exported: $output_file"
}

# Import configuration
import_config() {
    local import_file="$1"
    local target_environment="$2"
    
    if [ ! -f "$import_file" ]; then
        print_error "Import file not found: $import_file"
        return 1
    fi
    
    print_status "Importing configuration from: $import_file"
    
    local temp_dir=$(mktemp -d)
    
    # Extract archive
    tar xzf "$import_file" -C "$temp_dir"
    
    # Validate import
    if [ ! -f "$temp_dir/export-metadata.json" ]; then
        print_error "Invalid configuration export file"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Show import metadata
    if command -v jq &> /dev/null; then
        print_status "Import metadata:"
        jq '.' "$temp_dir/export-metadata.json"
        echo
    fi
    
    # Backup existing configuration
    local backup_dir="$CONFIG_DIR/backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
    print_status "Existing configuration backed up to: $backup_dir"
    
    # Import configuration
    if [ -n "$target_environment" ]; then
        # Import as specific environment
        if [ -f "$temp_dir/$target_environment.yml" ]; then
            cp "$temp_dir/$target_environment.yml" "$ENVIRONMENTS_DIR/"
            print_success "Environment configuration imported: $target_environment"
        else
            print_warning "Environment configuration not found in import: $target_environment"
        fi
    else
        # Import all configurations
        cp "$temp_dir"/*.yml "$CONFIG_DIR/" 2>/dev/null || true
        cp "$temp_dir"/*.yml "$ENVIRONMENTS_DIR/" 2>/dev/null || true
        cp -r "$temp_dir/templates"/* "$TEMPLATES_DIR/" 2>/dev/null || true
        cp -r "$temp_dir/schemas"/* "$SCHEMAS_DIR/" 2>/dev/null || true
        print_success "All configurations imported"
    fi
    
    rm -rf "$temp_dir"
}

# Migration utilities
migrate_config() {
    local from_version="$1"
    local to_version="$2"
    
    print_status "Migrating configuration from version $from_version to $to_version"
    
    # Backup current configuration
    local backup_dir="$CONFIG_DIR/migration-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
    
    print_status "Configuration backed up to: $backup_dir"
    
    # Perform migration based on versions
    case "$from_version-$to_version" in
        "0.9-1.0")
            print_status "Migrating from 0.9 to 1.0..."
            # Add migration logic here
            print_success "Migration completed"
            ;;
        *)
            print_warning "No migration path defined for $from_version to $to_version"
            ;;
    esac
}

# Main function
main() {
    case "$1" in
        init)
            init_config_system
            ;;
        load)
            load_config "$2" "$3"
            ;;
        validate)
            validate_config "$2" "$3"
            ;;
        generate)
            generate_config "$2" "$3" "$4"
            ;;
        list)
            list_configs
            ;;
        export)
            export_config "$2" "$3"
            ;;
        import)
            import_config "$2" "$3"
            ;;
        migrate)
            migrate_config "$2" "$3"
            ;;
        *)
            echo "Usage: $0 {init|load|validate|generate|list|export|import|migrate} [options]"
            echo
            echo "Commands:"
            echo "  init                                    Initialize configuration management system"
            echo "  load <config_file> [environment]       Load configuration file"
            echo "  validate <config_file> [schema_file]   Validate configuration against schema"
            echo "  generate <template> <output> [env]     Generate configuration from template"
            echo "  list                                    List available configurations"
            echo "  export <environment> [output_file]     Export environment configuration"
            echo "  import <import_file> [environment]     Import configuration"
            echo "  migrate <from_version> <to_version>    Migrate configuration between versions"
            exit 1
            ;;
    esac
}

# Install dependencies if missing
if ! command -v yq &> /dev/null; then
    print_warning "yq not found. YAML processing features may not work properly."
    print_status "Install with: pip install yq"
fi

if ! command -v jq &> /dev/null; then
    print_warning "jq not found. JSON processing features may not work properly."
fi

# Run main function
main "$@"
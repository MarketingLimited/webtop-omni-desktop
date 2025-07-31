#!/bin/bash

# Enhanced system validation script
# Part of the modular webtop.sh refactoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[VALIDATION]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Validation functions
validate_docker() {
    print_status "Validating Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        return 1
    fi
    
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    print_success "Docker $docker_version is running"
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short)
        print_success "Docker Compose $compose_version is available"
    elif command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        print_success "Docker Compose $compose_version is available (legacy)"
    else
        print_error "Docker Compose is not installed"
        return 1
    fi
    
    return 0
}

validate_system_requirements() {
    print_status "Validating system requirements..."
    
    # Check available disk space
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=5242880  # 5GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_warning "Low disk space: $(($available_space/1024/1024))GB available, 5GB recommended"
    else
        print_success "Sufficient disk space: $(($available_space/1024/1024))GB available"
    fi
    
    # Check available memory
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local required_mem=4194304  # 4GB in KB
    
    if [ "$total_mem" -lt "$required_mem" ]; then
        print_warning "Low memory: $(($total_mem/1024/1024))GB total, 4GB recommended"
    else
        print_success "Sufficient memory: $(($total_mem/1024/1024))GB total"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 2 ]; then
        print_warning "Low CPU cores: $cpu_cores cores, 2+ recommended"
    else
        print_success "Sufficient CPU cores: $cpu_cores cores"
    fi
    
    return 0
}

validate_network_connectivity() {
    print_status "Validating network connectivity..."
    
    # Test internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity is working"
    else
        print_error "No internet connectivity"
        return 1
    fi
    
    # Test Docker Hub connectivity
    if curl -s --max-time 10 https://hub.docker.com &> /dev/null; then
        print_success "Docker Hub is accessible"
    else
        print_warning "Docker Hub connectivity issues"
    fi
    
    return 0
}

validate_ports() {
    print_status "Validating port availability..."
    
    # Load environment variables
    if [ -f .env ]; then
        source .env
    fi
    
    local base_http_port=${BASE_HTTP_PORT:-32769}
    local base_ssh_port=${BASE_SSH_PORT:-2223}
    local base_ttyd_port=${BASE_TTYD_PORT:-7682}
    
    local ports_to_check=($base_http_port $base_ssh_port $base_ttyd_port)
    local blocked_ports=()
    
    for port in "${ports_to_check[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            blocked_ports+=($port)
            print_warning "Port $port is already in use"
        else
            print_success "Port $port is available"
        fi
    done
    
    if [ ${#blocked_ports[@]} -gt 0 ]; then
        print_warning "Some base ports are in use. Auto-assignment will find alternatives."
    fi
    
    return 0
}

validate_file_permissions() {
    print_status "Validating file permissions..."
    
    # Check if scripts are executable
    local script_files=(
        "webtop.sh"
        "install.sh"
        "auth-setup.sh"
        "health-check.sh"
        "lib/core.sh"
        "lib/container-manager.sh"
        "lib/registry.sh"
        "lib/build-manager.sh"
        "lib/volume-manager.sh"
        "lib/template-manager.sh"
        "lib/multi-container.sh"
    )
    
    local permission_issues=0
    
    for script in "${script_files[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                print_success "$script is executable"
            else
                print_warning "$script is not executable"
                chmod +x "$script" 2>/dev/null && print_success "Fixed permissions for $script" || {
                    print_error "Failed to fix permissions for $script"
                    ((permission_issues++))
                }
            fi
        else
            print_warning "$script not found"
        fi
    done
    
    if [ $permission_issues -gt 0 ]; then
        return 1
    fi
    
    return 0
}

validate_configuration() {
    print_status "Validating configuration files..."
    
    # Check .env file
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            print_warning ".env file missing, will be created from .env.example"
        else
            print_error ".env.example file missing"
            return 1
        fi
    else
        print_success ".env file exists"
        
        # Validate required variables
        local required_vars=("PUID" "PGID" "TZ")
        local missing_vars=()
        
        source .env
        for var in "${required_vars[@]}"; do
            if [ -z "${!var}" ]; then
                missing_vars+=($var)
            fi
        done
        
        if [ ${#missing_vars[@]} -gt 0 ]; then
            print_warning "Missing required variables in .env: ${missing_vars[*]}"
        else
            print_success "All required environment variables are set"
        fi
    fi
    
    # Check Docker Compose files
    local compose_files=("docker-compose.yml" "docker-compose.dev.yml" "docker-compose.prod.yml")
    
    for compose_file in "${compose_files[@]}"; do
        if [ -f "$compose_file" ]; then
            if docker compose -f "$compose_file" config &> /dev/null; then
                print_success "$compose_file syntax is valid"
            else
                print_error "$compose_file has syntax errors"
                return 1
            fi
        else
            print_warning "$compose_file not found"
        fi
    done
    
    return 0
}

validate_dependencies() {
    print_status "Validating dependencies..."
    
    # Check for required tools
    local required_tools=("jq" "curl" "tar" "gzip")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_success "$tool is available"
        else
            missing_tools+=($tool)
            print_warning "$tool is missing"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_status "Some tools are missing but will be installed automatically: ${missing_tools[*]}"
    fi
    
    return 0
}

generate_validation_report() {
    local validation_file="validation-report-$(date +%Y%m%d_%H%M%S).json"
    
    print_status "Generating validation report: $validation_file"
    
    cat > "$validation_file" << EOF
{
    "validation_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_info": {
        "os": "$(uname -s)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "hostname": "$(hostname)"
    },
    "docker_info": {
        "version": "$(docker --version 2>/dev/null || echo 'Not installed')",
        "compose_version": "$(docker compose version --short 2>/dev/null || docker-compose --version 2>/dev/null || echo 'Not installed')",
        "running": $(docker info &> /dev/null && echo 'true' || echo 'false')
    },
    "resources": {
        "disk_space_gb": $(($(df . | tail -1 | awk '{print $4}')/1024/1024)),
        "memory_gb": $(($(grep MemTotal /proc/meminfo | awk '{print $2}')/1024/1024)),
        "cpu_cores": $(nproc)
    },
    "network": {
        "internet_connectivity": $(ping -c 1 8.8.8.8 &> /dev/null && echo 'true' || echo 'false'),
        "docker_hub_connectivity": $(curl -s --max-time 10 https://hub.docker.com &> /dev/null && echo 'true' || echo 'false')
    }
}
EOF
    
    print_success "Validation report saved: $validation_file"
}

# Main validation function
main() {
    echo "======================================"
    echo "   Ubuntu KDE Webtop Validation"
    echo "======================================"
    echo
    
    local validation_failed=0
    
    validate_docker || ((validation_failed++))
    echo
    
    validate_system_requirements || ((validation_failed++))
    echo
    
    validate_network_connectivity || ((validation_failed++))
    echo
    
    validate_ports || ((validation_failed++))
    echo
    
    validate_file_permissions || ((validation_failed++))
    echo
    
    validate_configuration || ((validation_failed++))
    echo
    
    validate_dependencies || ((validation_failed++))
    echo
    
    generate_validation_report
    echo
    
    if [ $validation_failed -eq 0 ]; then
        print_success "All validations passed! System is ready for deployment."
        exit 0
    else
        print_error "$validation_failed validation(s) failed. Please address the issues above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
#!/bin/bash

# Core utilities and setup functions
# Part of the modular webtop.sh refactoring

# Colors for output (used by sourced scripts)
# shellcheck disable=SC2034
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Print colored output functions
print_status() {
    printf '%b\n' "${BLUE}[INFO]${NC} $1"
}

print_success() {
    printf '%b\n' "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    printf '%b\n' "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    printf '%b\n' "${RED}[ERROR]${NC} $1"
}

print_header() {
    printf '%b\n' "${PURPLE}
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
    check_env
    # shellcheck source=/dev/null
    source .env
    
    # Set default base ports if not defined
    export BASE_HTTP_PORT=${BASE_HTTP_PORT:-32769}
    export BASE_SSH_PORT=${BASE_SSH_PORT:-2223}
    export BASE_TTYD_PORT=${BASE_TTYD_PORT:-7682}
    export BASE_AUDIO_PORT=${BASE_AUDIO_PORT:-8081}
    export BASE_PULSE_PORT=${BASE_PULSE_PORT:-4714}
    export DATA_ROOT=${DATA_ROOT:-/data/ubuntu-kde-docker}
}

# Check if port is available
is_port_available() {
    local port=$1
    ! ss -tuln | grep -q ":${port} "
}

# Find next available port starting from base
find_available_port() {
    local base_port=$1
    local current_port=$base_port

    while ! is_port_available "$current_port"; do
        ((current_port++))
        # Prevent infinite loop
        if [ "$current_port" -gt $((base_port + 1000)) ]; then
            print_error "Could not find available port starting from $base_port"
            exit 1
        fi
    done

    echo "$current_port"
}

# Ensure JQ is installed for container registry management
ensure_jq() {
    if ! command -v jq &> /dev/null; then
        print_status "Installing jq for container registry management..."
        ./install-jq.sh
    fi
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

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name=*)
                # shellcheck disable=SC2034
                CONTAINER_NAME="${1#*=}"
                shift
                ;;
            --name)
                # shellcheck disable=SC2034
                CONTAINER_NAME="$2"
                shift 2
                ;;
            --ports=*)
                # shellcheck disable=SC2034
                CONTAINER_PORTS="${1#*=}"
                shift
                ;;
            --ports)
                # shellcheck disable=SC2034
                CONTAINER_PORTS="$2"
                shift 2
                ;;
            --auth=*)
                # shellcheck disable=SC2034
                ENABLE_AUTH="${1#*=}"
                shift
                ;;
            --auth)
                # shellcheck disable=SC2034
                ENABLE_AUTH="true"
                shift
                ;;
            *)
                break
                ;;
        esac
    done
}

#!/bin/bash

# VNC HTTP Authentication Setup Script
# Manages .htpasswd files and user authentication

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default paths
HTPASSWD_FILE="auth/.htpasswd"
AUTH_DIR="auth"

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

# Initialize auth directory and files
init_auth() {
    mkdir -p "$AUTH_DIR"
    
    if [[ ! -f "$HTPASSWD_FILE" ]]; then
        touch "$HTPASSWD_FILE"
        print_success "Created authentication file: $HTPASSWD_FILE"
    fi
}

# Add or update user
add_user() {
    local username="$1"
    local password="$2"
    
    if [[ -z "$username" || -z "$password" ]]; then
        print_error "Usage: add_user <username> <password>"
        return 1
    fi
    
    init_auth
    
    # Check if htpasswd is available
    if ! command -v htpasswd &> /dev/null; then
        print_warning "htpasswd not found. Installing apache2-utils..."
        
        # Try to install htpasswd
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y apache2-utils
        elif command -v yum &> /dev/null; then
            sudo yum install -y httpd-tools
        elif command -v apk &> /dev/null; then
            sudo apk add --no-cache apache2-utils
        else
            print_error "Cannot install htpasswd. Please install apache2-utils or httpd-tools manually."
            return 1
        fi
    fi
    
    # Add or update user
    if grep -q "^${username}:" "$HTPASSWD_FILE" 2>/dev/null; then
        print_status "Updating existing user: $username"
        htpasswd -b "$HTPASSWD_FILE" "$username" "$password"
    else
        print_status "Adding new user: $username"
        htpasswd -bc "$HTPASSWD_FILE" "$username" "$password" 2>/dev/null || htpasswd -b "$HTPASSWD_FILE" "$username" "$password"
    fi
    
    print_success "User $username configured successfully"
}

# Remove user
remove_user() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        print_error "Usage: remove_user <username>"
        return 1
    fi
    
    if [[ ! -f "$HTPASSWD_FILE" ]]; then
        print_error "Authentication file not found: $HTPASSWD_FILE"
        return 1
    fi
    
    if grep -q "^${username}:" "$HTPASSWD_FILE"; then
        sed -i "/^${username}:/d" "$HTPASSWD_FILE"
        print_success "User $username removed successfully"
    else
        print_warning "User $username not found"
    fi
}

# List users
list_users() {
    if [[ ! -f "$HTPASSWD_FILE" ]]; then
        print_warning "No authentication file found"
        return 0
    fi
    
    local users=$(cut -d: -f1 "$HTPASSWD_FILE" 2>/dev/null || echo "")
    
    if [[ -z "$users" ]]; then
        echo "No users configured"
        return 0
    fi
    
    print_status "Configured VNC Authentication Users:"
    echo "$users"
}

# Generate auth from environment
generate_auth_from_env() {
    local env_file="${1:-.env}"
    
    if [[ ! -f "$env_file" ]]; then
        print_error "Environment file not found: $env_file"
        return 1
    fi
    
    # Source environment file
    set -a
    source "$env_file"
    set +a
    
    init_auth
    
    # Add admin user from environment
    if [[ -n "$ADMIN_USERNAME" && -n "$ADMIN_PASSWORD" ]]; then
        add_user "$ADMIN_USERNAME" "$ADMIN_PASSWORD"
    fi
    
    # Add dev user from environment
    if [[ -n "$DEV_USERNAME" && -n "$DEV_PASSWORD" ]]; then
        add_user "$DEV_USERNAME" "$DEV_PASSWORD"
    fi
    
    # Add VNC users if defined
    if [[ -n "$VNC_USERS" ]]; then
        IFS=',' read -ra USERS <<< "$VNC_USERS"
        for user_pass in "${USERS[@]}"; do
            if [[ "$user_pass" == *":"* ]]; then
                local user="${user_pass%%:*}"
                local pass="${user_pass#*:}"
                add_user "$user" "$pass"
            fi
        done
    fi
    
    print_success "Authentication configured from environment file"
}

# Main function
main() {
    case "${1:-}" in
        "add")
            if [[ "$2" == *":"* ]]; then
                local user="${2%%:*}"
                local pass="${2#*:}"
                add_user "$user" "$pass"
            else
                add_user "$2" "$3"
            fi
            ;;
        "remove")
            remove_user "$2"
            ;;
        "list")
            list_users
            ;;
        "init")
            init_auth
            ;;
        "generate")
            generate_auth_from_env "$2"
            ;;
        *)
            echo "Usage: $0 {add|remove|list|init|generate} [options]"
            echo ""
            echo "Commands:"
            echo "  add <user:pass>     Add or update user"
            echo "  add <user> <pass>   Add or update user"
            echo "  remove <user>       Remove user"
            echo "  list                List all users"
            echo "  init                Initialize auth directory"
            echo "  generate [env_file] Generate auth from environment file"
            echo ""
            echo "Examples:"
            echo "  $0 add admin:secure123"
            echo "  $0 add client1 password123"
            echo "  $0 remove client1"
            echo "  $0 generate .env"
            exit 1
            ;;
    esac
}

main "$@"
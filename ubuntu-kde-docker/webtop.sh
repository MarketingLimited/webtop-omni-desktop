#!/bin/bash

# Webtop KDE Marketing Agency Manager - Modular Version
# Enhanced with multi-container support and HTTP authentication

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Global variables
CONTAINER_REGISTRY=".container-registry.json"
BACKUP_DIR="./backups"
TEMPLATE_DIR="./templates"

# Container options
CONTAINER_NAME=""
CONTAINER_PORTS=""
ENABLE_AUTH=""

# Load modular libraries
source lib/core.sh
source lib/registry.sh
source lib/container-manager.sh
source lib/build-manager.sh
source lib/volume-manager.sh
source lib/template-manager.sh
source lib/multi-container.sh

# Display help
show_help() {
    print_header
    echo
    echo -e "${CYAN}Usage: $0 [COMMAND] [OPTIONS]${NC}"
    echo
    echo -e "${YELLOW}BASIC COMMANDS:${NC}"
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
    echo -e "${YELLOW}BUILD MANAGEMENT:${NC}"
    echo "  build-bg [--dev|--prod]  Build in background"
    echo "  build-status             Check background build status"
    echo "  build-logs [-f]          Show build logs"
    echo "  build-stop               Stop background build"
    echo "  build-cleanup [all]      Cleanup build files"
    echo
    echo -e "${YELLOW}CONTAINER MANAGEMENT:${NC}"
    echo "  list                     List all managed containers"
    echo "  remove <name>            Remove specific container"
    echo "  info <name>              Show container information"
    echo "  open <name>              Open container in browser"
    echo "  connect <name>           Connect via SSH"
    echo
    echo -e "${YELLOW}BACKUP & RESTORE:${NC}"
    echo "  backup <name>            Backup container volumes"
    echo "  restore <name> <backup>  Restore from backup"
    echo "  clone <source> <target>  Clone container"
    echo
    echo -e "${YELLOW}TEMPLATE MANAGEMENT:${NC}"
    echo "  template save <container> <name>     Save container as template"
    echo "  template create <name> <template>    Create container from template"
    echo "  template list                        List available templates"
    echo "  template remove <name>               Remove template"
    echo "  template export <name> <path>        Export template"
    echo "  template import <path> [name]        Import template"
    echo
    echo -e "${YELLOW}VOLUME MANAGEMENT:${NC}"
    echo "  volumes list             List all container volumes"
    echo "  volumes backup-all       Backup all container volumes"
    echo "  volumes cleanup          Clean unused volumes"
    echo
    echo -e "${YELLOW}MULTI-CONTAINER:${NC}"
    echo "  orchestrate start <list> [config]    Start multiple containers"
    echo "  orchestrate stop <list>              Stop multiple containers"
    echo "  batch backup <list>                  Backup multiple containers"
    echo "  load-balance <base> <count> [config] Create load-balanced set"
    echo "  monitor-health [pattern] [interval]  Monitor container health"
    echo "  monitor-resources [pattern]          Monitor resource usage"
    echo
    echo -e "${YELLOW}DEVELOPMENT:${NC}"
    echo "  dev-setup               Setup development environment"
    echo "  wine-setup              Configure Wine for Windows apps"
    echo "  android-setup           Setup Android/Waydroid environment"
    echo "  video-setup             Configure video editing tools"
    echo
    echo -e "${YELLOW}SYSTEM:${NC}"
    echo "  validate                Run system validation"
    echo "  monitor                 Monitor resource usage"
    echo "  health                  Perform health check"
    echo
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo "  --name=<n>              Custom container name"
    echo "  --ports=<mapping>       Custom port mapping"
    echo "  --auth                  Enable HTTP authentication"
    echo "  --dev                   Use development configuration"
    echo "  --prod                  Use production configuration"
    echo
}

# Initialize system
initialize_system() {
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
    
    # Initialize backup and template directories
    mkdir -p "$BACKUP_DIR" "$TEMPLATE_DIR"
    
    # Create shared resources volume if it doesn't exist
    if ! docker volume ls | grep -q "shared_resources" 2>/dev/null; then
        print_status "Creating shared resources volume..."
        docker volume create shared_resources >/dev/null 2>&1 || true
    fi
}

# Main command handling
main() {
    # Initialize system
    initialize_system
    
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
    
    # Always check Docker first for commands that need it
    case "$1" in
        build*|up|start|down|stop|restart|logs|status|shell|monitor*|health|clean|update)
            check_docker
            ;;
    esac
    
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
            ensure_jq
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
        backup)
            backup_container "$2"
            ;;
        restore)
            restore_container "$2" "$3"
            ;;
        clone)
            clone_container "$2" "$3"
            ;;
        template)
            case "$2" in
                save)
                    template_save "$3" "$4"
                    ;;
                create)
                    template_create "$3" "$4"
                    ;;
                list)
                    template_list
                    ;;
                remove)
                    template_remove "$3"
                    ;;
                export)
                    template_export "$3" "$4"
                    ;;
                import)
                    template_import "$3" "$4"
                    ;;
                *)
                    print_error "Unknown template command: $2"
                    echo "Usage: $0 template [save|create|list|remove|export|import] [args...]"
                    exit 1
                    ;;
            esac
            ;;
        volumes)
            case "$2" in
                list)
                    volumes_list
                    ;;
                backup-all)
                    volumes_backup_all
                    ;;
                cleanup)
                    volumes_cleanup
                    ;;
                *)
                    print_error "Unknown volumes command: $2"
                    echo "Usage: $0 volumes [list|backup-all|cleanup]"
                    exit 1
                    ;;
            esac
            ;;
        orchestrate)
            case "$2" in
                start)
                    orchestrate_start "$3" "$4"
                    ;;
                stop)
                    orchestrate_stop "$3"
                    ;;
                *)
                    print_error "Unknown orchestrate command: $2"
                    echo "Usage: $0 orchestrate [start|stop] [args...]"
                    exit 1
                    ;;
            esac
            ;;
        batch)
            case "$2" in
                backup)
                    batch_backup "$3"
                    ;;
                *)
                    print_error "Unknown batch command: $2"
                    echo "Usage: $0 batch [backup] [args...]"
                    exit 1
                    ;;
            esac
            ;;
        load-balance)
            load_balance_containers "$2" "$3" "$4"
            ;;
        monitor-health)
            monitor_health "$2" "$3"
            ;;
        monitor-resources)
            monitor_resources_detailed "$2"
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
        validate)
            ./scripts/setup-validation.sh
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
#!/bin/bash

# Build management functions with background build support
# Part of the modular webtop.sh refactoring

# Helper functions for build file names
get_build_pid_file() {
    local config="$1"
    echo "build-${config}.pid"
}

get_build_log_file() {
    local config="$1"
    echo "build-${config}.log"
}

# Build Docker image
build_image() {
    local config
    config=$(get_config "$1")
    local compose_file
    compose_file=$(get_compose_file "$config")
    local background_flag="$2"

    if [ ! -f "$compose_file" ]; then
        print_error "Docker Compose file not found: $compose_file"
        exit 1
    fi

    if [ "$background_flag" = "--background" ] || [ "$background_flag" = "bg" ]; then
        build_image_background "$config" "$compose_file"
    else
        print_status "Building Docker image (${config} configuration)..."
        $DOCKER_COMPOSE_CMD -f "$compose_file" build
        print_success "Docker image built successfully!"
    fi
}

# Build Docker image in background
build_image_background() {
    local config="$1"
    local compose_file="$2"
    local pid_file
    pid_file=$(get_build_pid_file "$config")
    local log_file
    log_file=$(get_build_log_file "$config")
    local start_time
    start_time=$(date +%s)

    # Check if build is already running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        print_warning "Background build already running for ${config} configuration"
        print_status "Check progress with: $0 build-status --${config}"
        return 0
    fi

    print_status "Starting background build (${config} configuration)..."
    {
        echo "Build started at: $(date)"
        echo "Configuration: $config"
        echo "Compose file: $compose_file"
        echo "Start time: $start_time"
        echo "========================================"
    } > "$log_file"

    # Start background build process
    nohup bash -c "
        echo \"Build process started\" >> '$log_file'
        $DOCKER_COMPOSE_CMD -f '$compose_file' build >> '$log_file' 2>&1
        build_exit_code=\$?
        echo \"========================================\" >> '$log_file'
        echo \"Build completed at: \$(date)\" >> '$log_file'
        if [ \$build_exit_code -eq 0 ]; then
            echo \"Status: SUCCESS\" >> '$log_file'
        else
            echo \"Status: FAILED\" >> '$log_file'
            echo \"Exit code: \$build_exit_code\" >> '$log_file'
        fi
        rm -f '$pid_file'
    " > /dev/null 2>&1 &

    local build_pid=$!
    echo "$build_pid" > "$pid_file"

    print_success "Background build started (PID: $build_pid)"
    print_status "Check progress with: $0 build-status"
    print_status "View logs with: $0 build-logs"
    print_status "Stop build with: $0 build-stop"
}

# Check background build status
check_build_status() {
    local config
    config=$(get_config "$1")
    local pid_file
    pid_file=$(get_build_pid_file "$config")
    local log_file
    log_file=$(get_build_log_file "$config")

    if [ ! -f "$log_file" ]; then
        print_warning "No build log found for ${config} configuration"
        return 1
    fi

    # Check if build is running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        local pid
        pid=$(cat "$pid_file")
        print_status "Background build running (PID: $pid) - ${config} configuration"
        echo

        # Show recent progress
        echo -e "${CYAN}Recent build output:${NC}"
        tail -10 "$log_file"
        echo
        echo -e "${YELLOW}Use '$0 build-logs' to see full output${NC}"
        echo -e "${YELLOW}Use '$0 build-stop' to stop the build${NC}"
    else
        # Build finished - show final status
        if grep -q "Status: SUCCESS" "$log_file" 2>/dev/null; then
            print_success "Background build completed successfully! (${config} configuration)"
        elif grep -q "Status: FAILED" "$log_file" 2>/dev/null; then
            print_error "Background build failed! (${config} configuration)"
            echo -e "${YELLOW}Check logs with: $0 build-logs${NC}"
        else
            print_warning "Build status unclear. Check logs with: $0 build-logs"
        fi

        # Show build summary
        if [ -f "$log_file" ]; then
            echo
            echo -e "${CYAN}Build Summary:${NC}"
            grep -E "(Build started at|Build completed at|Status:)" "$log_file" 2>/dev/null || echo "No summary available"
        fi
    fi
}

# Show build logs
show_build_logs() {
    local config
    config=$(get_config "$1")
    local log_file
    log_file=$(get_build_log_file "$config")
    local follow_flag="$2"

    if [ ! -f "$log_file" ]; then
        print_warning "No build log found for ${config} configuration"
        return 1
    fi

    print_status "Build logs for ${config} configuration:"
    echo

    if [ "$follow_flag" = "-f" ] || [ "$follow_flag" = "--follow" ]; then
        tail -f "$log_file"
    else
        cat "$log_file"
    fi
}

# Stop background build
stop_build() {
    local config
    config=$(get_config "$1")
    local pid_file
    pid_file=$(get_build_pid_file "$config")
    local log_file
    log_file=$(get_build_log_file "$config")

    if [ ! -f "$pid_file" ]; then
        print_warning "No background build running for ${config} configuration"
        return 1
    fi

    local pid
    pid=$(cat "$pid_file")

    if kill -0 "$pid" 2>/dev/null; then
        print_status "Stopping background build (PID: $pid)..."

        # Try graceful termination first
        kill -TERM "$pid" 2>/dev/null
        sleep 2

        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null
        fi

        # Log the interruption
        {
            echo "========================================"
            echo "Build stopped by user at: $(date)"
            echo "Status: INTERRUPTED"
        } >> "$log_file"

        rm -f "$pid_file"
        print_success "Background build stopped"
    else
        print_warning "Build process not running (PID: $pid)"
        rm -f "$pid_file"
    fi
}

# Cleanup build files
cleanup_build_files() {
    local config="$1"

    if [ "$config" = "all" ]; then
        print_status "Cleaning up all build files..."
        rm -f build-*.pid build-*.log
        print_success "All build files cleaned up"
    else
        local actual_config
        actual_config=$(get_config "$config")
        print_status "Cleaning up build files for ${actual_config} configuration..."
        rm -f "$(get_build_pid_file "$actual_config")" "$(get_build_log_file "$actual_config")"
        print_success "Build files for ${actual_config} configuration cleaned up"
    fi
}


#!/bin/bash

# Performance tuning and optimization utility
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

# Configuration
PERFORMANCE_CONFIG_FILE="config/performance-tuner.yml"
TUNING_LOG_FILE="logs/performance-tuning.log"
BENCHMARKS_DIR="benchmarks"

# Ensure directories exist
mkdir -p logs config benchmarks

print_status() {
    echo -e "${BLUE}[PERF]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OPTIMIZED]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[TUNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAILED]${NC} $1"
}

print_benchmark() {
    echo -e "${PURPLE}[BENCHMARK]${NC} $1"
}

# Initialize default performance configuration
init_performance_config() {
    if [ ! -f "$PERFORMANCE_CONFIG_FILE" ]; then
        print_status "Creating default performance tuning configuration..."
        cat > "$PERFORMANCE_CONFIG_FILE" << 'EOF'
performance_tuning:
  enabled: true
  auto_apply: false
  
docker_optimization:
  enabled: true
  settings:
    storage_driver_opts:
      - "overlay2.size=50G"
    default_ulimits:
      - "nofile=65536:65536"
      - "nproc=32768:32768"
    log_opts:
      max_size: "100m"
      max_file: "3"
    experimental: true
  
container_optimization:
  enabled: true
  settings:
    memory_optimization:
      swappiness: 10
      vm_max_map_count: 262144
      shared_memory_size: "4g"
    cpu_optimization:
      cpu_shares: 1024
      cpu_period: 100000
      cpu_quota: 200000
    io_optimization:
      blkio_weight: 500
      device_read_bps: "100mb"
      device_write_bps: "100mb"
  
network_optimization:
  enabled: true
  settings:
    tcp_optimization:
      tcp_window_scaling: 1
      tcp_timestamps: 1
      tcp_sack: 1
      tcp_congestion_control: "bbr"
    buffer_optimization:
      net_core_rmem_max: 134217728
      net_core_wmem_max: 134217728
      net_ipv4_tcp_rmem: "4096 87380 134217728"
      net_ipv4_tcp_wmem: "4096 65536 134217728"
  
graphics_optimization:
  enabled: true
  settings:
      quality: 6
      compression: 2
      jpeg_quality: 8
      tight_compression: true
  
monitoring:
  enabled: true
  metrics_collection: true
  benchmarking: true
  alerting: true

profiles:
  development:
    priority: "performance"
    memory_limit: "8g"
    cpu_limit: "4"
    
  production:
    priority: "stability"
    memory_limit: "16g"
    cpu_limit: "8"
    
  minimal:
    priority: "resource_efficiency"
    memory_limit: "2g"
    cpu_limit: "2"
EOF
        print_success "Performance tuning configuration created: $PERFORMANCE_CONFIG_FILE"
    fi
}

# Apply Docker daemon optimizations
optimize_docker_daemon() {
    print_status "Optimizing Docker daemon configuration..."
    
    local docker_config_dir="/etc/docker"
    local daemon_json="$docker_config_dir/daemon.json"
    
    # Backup existing configuration
    if [ -f "$daemon_json" ]; then
        cp "$daemon_json" "${daemon_json}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up existing Docker daemon configuration"
    fi
    
    # Create optimized daemon.json
    sudo mkdir -p "$docker_config_dir"
    sudo tee "$daemon_json" > /dev/null << 'EOF'
{
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.size=50G"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "default-ulimits": {
        "nofile": {
            "hard": 65536,
            "soft": 65536
        },
        "nproc": {
            "hard": 32768,
            "soft": 32768
        }
    },
    "experimental": true,
    "metrics-addr": "127.0.0.1:9323",
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 5,
    "default-shm-size": "4G"
}
EOF
    
    print_warning "Docker daemon configuration updated. Restart Docker daemon to apply changes:"
    print_warning "sudo systemctl restart docker"
    
    log_tuning "docker_daemon" "optimized" "Updated daemon configuration with performance optimizations"
}

# Apply system-level optimizations
optimize_system() {
    print_status "Applying system-level optimizations..."
    
    # Memory optimizations
    print_status "Configuring memory optimizations..."
    
    # Reduce swappiness for better performance
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -w vm.swappiness=10
    
    # Increase memory map count for containers
    echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -w vm.max_map_count=262144
    
    # Optimize dirty page handling
    echo 'vm.dirty_ratio=15' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl -w vm.dirty_ratio=15
    sudo sysctl -w vm.dirty_background_ratio=5
    
    print_success "Memory optimizations applied"
    
    # Network optimizations
    print_status "Configuring network optimizations..."
    
    # TCP optimizations
    echo 'net.core.rmem_max=134217728' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'net.core.wmem_max=134217728' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'net.ipv4.tcp_rmem=4096 87380 134217728' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'net.ipv4.tcp_wmem=4096 65536 134217728' | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Enable TCP window scaling
    echo 'net.ipv4.tcp_window_scaling=1' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'net.ipv4.tcp_timestamps=1' | sudo tee -a /etc/sysctl.conf > /dev/null
    echo 'net.ipv4.tcp_sack=1' | sudo tee -a /etc/sysctl.conf > /dev/null
    
    # Set BBR congestion control if available
    if modinfo tcp_bbr &> /dev/null; then
        echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf > /dev/null
        echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf > /dev/null
        print_success "BBR congestion control enabled"
    fi
    
    # Apply network settings
    sudo sysctl -p > /dev/null
    print_success "Network optimizations applied"
    
    # File system optimizations
    print_status "Configuring file system optimizations..."
    
    # Increase file descriptor limits
    echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf > /dev/null
    echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf > /dev/null
    echo '* soft nproc 32768' | sudo tee -a /etc/security/limits.conf > /dev/null
    echo '* hard nproc 32768' | sudo tee -a /etc/security/limits.conf > /dev/null
    
    print_success "File system optimizations applied"
    
    log_tuning "system" "optimized" "Applied system-level performance optimizations"
}

# Container-specific optimizations
optimize_container() {
    local container_name="$1"
    local profile="${2:-production}"
    
    if [ -z "$container_name" ]; then
        print_error "Container name required"
        return 1
    fi
    
    print_status "Optimizing container: $container_name (profile: $profile)"
    
    # Get container configuration based on profile
    local memory_limit cpu_limit
    case "$profile" in
        development)
            memory_limit="8g"
            cpu_limit="4"
            ;;
        production)
            memory_limit="16g"
            cpu_limit="8"
            ;;
        minimal)
            memory_limit="2g"
            cpu_limit="2"
            ;;
        *)
            memory_limit="8g"
            cpu_limit="4"
            ;;
    esac
    
    # Apply container optimizations
    local container_id="webtop-$container_name"
    
    if docker ps --format "{{.Names}}" | grep -q "^$container_id$"; then
        print_status "Updating running container resource limits..."
        
        # Update memory limit
        docker update --memory="$memory_limit" "$container_id" 2>/dev/null && \
            print_success "Memory limit updated to $memory_limit"
        
        # Update CPU limit
        docker update --cpus="$cpu_limit" "$container_id" 2>/dev/null && \
            print_success "CPU limit updated to $cpu_limit"
        
        # Optimize container processes
        docker exec "$container_id" bash -c "
            # Adjust OOM killer settings
            echo -1000 > /proc/self/oom_score_adj
            
            # Optimize process scheduling
            echo 'kernel.sched_migration_cost_ns = 5000000' >> /etc/sysctl.conf
            echo 'kernel.sched_autogroup_enabled = 0' >> /etc/sysctl.conf
            
            # Apply container-specific optimizations
            sysctl -p > /dev/null 2>&1 || true
        " 2>/dev/null || print_warning "Some container optimizations may have failed"
        
        print_success "Container $container_name optimized with $profile profile"
    else
        print_warning "Container $container_id is not running. Optimizations will apply on next start."
    fi
    
    log_tuning "container" "$container_name" "Applied $profile optimization profile"
}

# Benchmark performance
run_benchmarks() {
    local container_name="$1"
    local benchmark_type="${2:-all}"
    
    print_benchmark "Running performance benchmarks..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local benchmark_file="$BENCHMARKS_DIR/benchmark_${timestamp}.json"
    
    # Initialize benchmark results
    cat > "$benchmark_file" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "container": "$container_name",
    "benchmark_type": "$benchmark_type",
    "system_info": {
        "cpu_cores": $(nproc),
        "memory_gb": $(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 )),
        "docker_version": "$(docker --version | awk '{print $3}' | sed 's/,//')"
    },
    "results": {}
}
EOF
    
    # CPU benchmark
    if [ "$benchmark_type" = "all" ] || [ "$benchmark_type" = "cpu" ]; then
        print_benchmark "Running CPU benchmark..."
        local cpu_start=$(date +%s%N)
        
        # Simple CPU stress test
        local cpu_result=$(timeout 10s bash -c '
            count=0
            start=$(date +%s%N)
            while true; do
                count=$((count + 1))
                if [ $((count % 100000)) -eq 0 ]; then
                    current=$(date +%s%N)
                    if [ $((current - start)) -gt 10000000000 ]; then
                        break
                    fi
                fi
            done
            echo $count
        ' 2>/dev/null || echo "0")
        
        local cpu_end=$(date +%s%N)
        local cpu_duration=$(( (cpu_end - cpu_start) / 1000000 ))
        
        # Update benchmark file
        local temp_file=$(mktemp)
        jq ".results.cpu = {\"operations\": $cpu_result, \"duration_ms\": $cpu_duration, \"ops_per_second\": $(( cpu_result * 1000 / cpu_duration ))}" "$benchmark_file" > "$temp_file" && mv "$temp_file" "$benchmark_file"
        
        print_benchmark "CPU benchmark: $cpu_result operations in ${cpu_duration}ms"
    fi
    
    # Memory benchmark
    if [ "$benchmark_type" = "all" ] || [ "$benchmark_type" = "memory" ]; then
        print_benchmark "Running memory benchmark..."
        local mem_start=$(date +%s%N)
        
        # Memory allocation test
        local mem_result=$(timeout 10s bash -c '
            count=0
            arrays=()
            while [ $count -lt 1000 ]; do
                arrays[count]=$(head -c 1000000 /dev/zero | tr "\0" "A")
                count=$((count + 1))
            done
            echo $count
        ' 2>/dev/null || echo "0")
        
        local mem_end=$(date +%s%N)
        local mem_duration=$(( (mem_end - mem_start) / 1000000 ))
        
        # Update benchmark file
        local temp_file=$(mktemp)
        jq ".results.memory = {\"allocations\": $mem_result, \"duration_ms\": $mem_duration, \"mb_per_second\": $(( mem_result * 1000 / mem_duration ))}" "$benchmark_file" > "$temp_file" && mv "$temp_file" "$benchmark_file"
        
        print_benchmark "Memory benchmark: ${mem_result}MB allocated in ${mem_duration}ms"
    fi
    
    # Disk I/O benchmark
    if [ "$benchmark_type" = "all" ] || [ "$benchmark_type" = "disk" ]; then
        print_benchmark "Running disk I/O benchmark..."
        local disk_start=$(date +%s%N)
        
        # Write test
        local write_result=$(timeout 10s dd if=/dev/zero of=/tmp/benchmark_write bs=1M count=100 2>&1 | grep -E "copied|transferred" | awk '{print $(NF-1)}' | head -1 || echo "0")
        rm -f /tmp/benchmark_write
        
        # Read test
        local read_result=$(timeout 10s dd if=/dev/zero of=/tmp/benchmark_read bs=1M count=100 && sync && timeout 10s dd if=/tmp/benchmark_read of=/dev/null bs=1M 2>&1 | grep -E "copied|transferred" | awk '{print $(NF-1)}' | tail -1 || echo "0")
        rm -f /tmp/benchmark_read
        
        local disk_end=$(date +%s%N)
        local disk_duration=$(( (disk_end - disk_start) / 1000000 ))
        
        # Update benchmark file
        local temp_file=$(mktemp)
        jq ".results.disk = {\"write_speed\": \"$write_result\", \"read_speed\": \"$read_result\", \"duration_ms\": $disk_duration}" "$benchmark_file" > "$temp_file" && mv "$temp_file" "$benchmark_file"
        
        print_benchmark "Disk I/O benchmark - Write: $write_result, Read: $read_result"
    fi
    
    # Container-specific benchmarks
    if [ -n "$container_name" ] && [ "$container_name" != "system" ]; then
        local container_id="webtop-$container_name"
        if docker ps --format "{{.Names}}" | grep -q "^$container_id$"; then
            print_benchmark "Running container-specific benchmarks..."
            
            # VNC connection test
            local vnc_test_result="false"
            local container_http_port=$(jq -r ".\"$container_name\".ports.http" .container-registry.json 2>/dev/null || echo "")
            if [ -n "$container_http_port" ] && [ "$container_http_port" != "null" ]; then
                if curl -s --max-time 5 "http://localhost:$container_http_port" > /dev/null; then
                    vnc_test_result="true"
                fi
            fi
            
            # Container resource usage
            local container_stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$container_id" 2>/dev/null || echo "0%,0B / 0B")
            local cpu_usage=$(echo "$container_stats" | cut -d',' -f1 | sed 's/%//')
            local mem_usage=$(echo "$container_stats" | cut -d',' -f2)
            
            # Update benchmark file
            local temp_file=$(mktemp)
            jq ".results.container = {\"vnc_accessible\": $vnc_test_result, \"cpu_usage\": \"$cpu_usage%\", \"memory_usage\": \"$mem_usage\"}" "$benchmark_file" > "$temp_file" && mv "$temp_file" "$benchmark_file"
            
            print_benchmark "Container benchmarks - VNC: $vnc_test_result, CPU: ${cpu_usage}%, Memory: $mem_usage"
        fi
    fi
    
    print_success "Benchmarks completed. Results saved to: $benchmark_file"
    
    # Show benchmark summary
    if command -v jq &> /dev/null; then
        echo
        print_benchmark "Benchmark Summary:"
        jq -r '.results | to_entries[] | "\(.key): \(.value)"' "$benchmark_file" 2>/dev/null || cat "$benchmark_file"
    fi
    
    log_tuning "benchmark" "$container_name" "Completed performance benchmarks"
}

# Compare benchmark results
compare_benchmarks() {
    print_status "Comparing benchmark results..."
    
    if [ ! -d "$BENCHMARKS_DIR" ]; then
        print_warning "No benchmarks directory found"
        return 1
    fi
    
    local benchmark_files=$(ls -t "$BENCHMARKS_DIR"/benchmark_*.json 2>/dev/null | head -5)
    
    if [ -z "$benchmark_files" ]; then
        print_warning "No benchmark files found"
        return 1
    fi
    
    echo
    print_benchmark "Recent Benchmark Comparison:"
    printf "%-20s %-15s %-15s %-15s %-15s\n" "TIMESTAMP" "CPU_OPS/SEC" "MEM_MB/SEC" "DISK_WRITE" "DISK_READ"
    printf "%-20s %-15s %-15s %-15s %-15s\n" "----------" "-----------" "-----------" "----------" "---------"
    
    for file in $benchmark_files; do
        if command -v jq &> /dev/null; then
            local timestamp=$(jq -r '.timestamp' "$file" | cut -d'T' -f1)
            local cpu_ops=$(jq -r '.results.cpu.ops_per_second // "N/A"' "$file")
            local mem_speed=$(jq -r '.results.memory.mb_per_second // "N/A"' "$file")
            local disk_write=$(jq -r '.results.disk.write_speed // "N/A"' "$file")
            local disk_read=$(jq -r '.results.disk.read_speed // "N/A"' "$file")
            
            printf "%-20s %-15s %-15s %-15s %-15s\n" "$timestamp" "$cpu_ops" "$mem_speed" "$disk_write" "$disk_read"
        fi
    done
    echo
}

# Monitor real-time performance
monitor_performance() {
    local interval="${1:-5}"
    local container_name="$2"
    
    print_status "Starting real-time performance monitoring (interval: ${interval}s)"
    print_status "Press Ctrl+C to stop monitoring"
    echo
    
    while true; do
        clear
        echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║                   PERFORMANCE MONITOR                       ║${NC}"
        echo -e "${PURPLE}║                   $(date +'%Y-%m-%d %H:%M:%S')                   ║${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        
        # System performance
        print_status "System Performance:"
        echo "  CPU Load: $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')"
        echo "  Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
        echo "  Disk: $(df -h . | awk 'NR==2{print $5}')"
        echo
        
        # Container performance
        if [ -n "$container_name" ]; then
            local container_id="webtop-$container_name"
            if docker ps --format "{{.Names}}" | grep -q "^$container_id$"; then
                print_status "Container Performance ($container_name):"
                docker stats --no-stream --format "  CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}, Network: {{.NetIO}}, Block I/O: {{.BlockIO}}" "$container_id"
                echo
            fi
        else
            print_status "All Webtop Containers:"
            local containers=$(docker ps --format "{{.Names}}" | grep "webtop-" || echo "")
            if [ -n "$containers" ]; then
                docker stats --no-stream --format "  {{.Name}}: CPU {{.CPUPerc}}, Memory {{.MemPerc}}" $containers
            else
                echo "  No webtop containers running"
            fi
            echo
        fi
        
        # Network performance
        print_status "Network Performance:"
        local rx_bytes=$(cat /proc/net/dev | grep -E "(eth0|ens|enp)" | head -1 | awk '{print $2}')
        local tx_bytes=$(cat /proc/net/dev | grep -E "(eth0|ens|enp)" | head -1 | awk '{print $10}')
        echo "  RX: $(numfmt --to=iec $rx_bytes)B, TX: $(numfmt --to=iec $tx_bytes)B"
        echo
        
        echo "Next update in ${interval} seconds..."
        sleep "$interval"
    done
}

# Auto-optimize based on current performance
auto_optimize() {
    local container_name="$1"
    
    print_status "Running automatic optimization analysis..."
    
    # Analyze current performance
    local cpu_usage=$(uptime | awk -F'load average:' '{print $1}' | awk '{print $NF}')
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    local disk_usage=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')
    
    print_status "Current system metrics:"
    echo "  CPU Load: $cpu_usage"
    echo "  Memory Usage: ${mem_usage}%"
    echo "  Disk Usage: ${disk_usage}%"
    echo
    
    # Determine optimization recommendations
    local needs_optimization=false
    
    if (( $(echo "$cpu_usage > 2.0" | bc -l 2>/dev/null || echo "0") )); then
        print_warning "High CPU load detected. Recommending CPU optimizations."
        needs_optimization=true
    fi
    
    if [ "$mem_usage" -gt 80 ]; then
        print_warning "High memory usage detected. Recommending memory optimizations."
        needs_optimization=true
    fi
    
    if [ "$disk_usage" -gt 80 ]; then
        print_warning "High disk usage detected. Recommending disk cleanup."
        needs_optimization=true
    fi
    
    if [ "$needs_optimization" = "true" ]; then
        print_status "Applying automatic optimizations..."
        
        # Apply system optimizations
        optimize_system
        
        # Optimize container if specified
        if [ -n "$container_name" ]; then
            optimize_container "$container_name" "production"
        fi
        
        print_success "Automatic optimization completed"
    else
        print_success "System performance is optimal. No optimizations needed."
    fi
    
    log_tuning "auto_optimize" "${container_name:-system}" "Completed automatic optimization analysis"
}

# Log tuning activities
log_tuning() {
    local component="$1"
    local target="$2"
    local action="$3"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo "[$timestamp] [$component] [$target] $action" >> "$TUNING_LOG_FILE"
}

# Generate performance report
generate_performance_report() {
    local report_file="performance-report-$(date +%Y%m%d_%H%M%S).json"
    
    print_status "Generating performance report..."
    
    # Get latest benchmark if available
    local latest_benchmark=""
    if [ -d "$BENCHMARKS_DIR" ]; then
        latest_benchmark=$(ls -t "$BENCHMARKS_DIR"/benchmark_*.json 2>/dev/null | head -1)
    fi
    
    cat > "$report_file" << EOF
{
    "report_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "system_info": {
        "cpu_cores": $(nproc),
        "memory_gb": $(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 )),
        "disk_total_gb": $(( $(df --total | tail -1 | awk '{print $2}') / 1024 / 1024 )),
        "docker_version": "$(docker --version | awk '{print $3}' | sed 's/,//' 2>/dev/null || echo 'unknown')"
    },
    "current_performance": {
        "cpu_load": "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')",
        "memory_usage_percent": $(free | awk 'NR==2{printf "%.0f", $3*100/$2}'),
        "disk_usage_percent": $(df . | tail -1 | awk '{print $5}' | sed 's/%//'),
        "running_containers": $(docker ps --format "{{.Names}}" | grep -c "webtop-" || echo "0")
    },
    "optimizations_applied": {
        "docker_daemon": $([ -f "/etc/docker/daemon.json" ] && echo "true" || echo "false"),
        "system_tuning": $([ -f "/etc/sysctl.conf" ] && grep -q "vm.swappiness" /etc/sysctl.conf && echo "true" || echo "false"),
        "network_optimization": $([ -f "/etc/sysctl.conf" ] && grep -q "net.core.rmem_max" /etc/sysctl.conf && echo "true" || echo "false")
    },
    "latest_benchmark": $([ -n "$latest_benchmark" ] && cat "$latest_benchmark" | jq '.results' || echo 'null'),
    "tuning_log_entries": $([ -f "$TUNING_LOG_FILE" ] && wc -l < "$TUNING_LOG_FILE" || echo "0")
}
EOF
    
    print_success "Performance report generated: $report_file"
}

# Main function
main() {
    case "$1" in
        init)
            init_performance_config
            ;;
        optimize)
            case "$2" in
                docker)
                    optimize_docker_daemon
                    ;;
                system)
                    optimize_system
                    ;;
                container)
                    optimize_container "$3" "$4"
                    ;;
                auto)
                    auto_optimize "$3"
                    ;;
                *)
                    print_error "Unknown optimization target: $2"
                    echo "Usage: $0 optimize {docker|system|container|auto} [container_name] [profile]"
                    exit 1
                    ;;
            esac
            ;;
        benchmark)
            run_benchmarks "$2" "$3"
            ;;
        compare)
            compare_benchmarks
            ;;
        monitor)
            monitor_performance "$2" "$3"
            ;;
        report)
            generate_performance_report
            ;;
        *)
            echo "Usage: $0 {init|optimize|benchmark|compare|monitor|report} [options]"
            echo
            echo "Commands:"
            echo "  init                                    Initialize performance tuning configuration"
            echo "  optimize docker                         Optimize Docker daemon configuration"
            echo "  optimize system                         Apply system-level optimizations"
            echo "  optimize container <name> [profile]     Optimize specific container"
            echo "  optimize auto [container]               Auto-optimize based on current performance"
            echo "  benchmark [container] [type]            Run performance benchmarks"
            echo "  compare                                 Compare recent benchmark results"
            echo "  monitor [interval] [container]          Start real-time performance monitoring"
            echo "  report                                  Generate performance report"
            echo
            echo "Profiles: development, production, minimal"
            echo "Benchmark types: cpu, memory, disk, all"
            exit 1
            ;;
    esac
}

# Install dependencies if missing
if ! command -v bc &> /dev/null; then
    print_warning "bc not found. Some calculations may not work properly."
fi

if ! command -v jq &> /dev/null; then
    print_warning "jq not found. JSON processing features may not work properly."
fi

# Run main function
main "$@"
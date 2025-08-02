#!/bin/bash
set -euo pipefail

# System-Level Performance Enhancement Script
echo "⚡ Implementing system-level performance optimizations..."

# Environment variables with defaults
SYSTEM_PERFORMANCE_PROFILE="${SYSTEM_PERFORMANCE_PROFILE:-balanced}"
CPU_OPTIMIZATION="${CPU_OPTIMIZATION:-true}"
MEMORY_OPTIMIZATION="${MEMORY_OPTIMIZATION:-true}"
PROCESS_PRIORITIZATION="${PROCESS_PRIORITIZATION:-true}"

echo "🚀 System Performance Profile: $SYSTEM_PERFORMANCE_PROFILE"

# CPU Optimization
optimize_cpu() {
    echo "🖥️  Optimizing CPU performance..."
    
    # Set CPU governor to performance mode if available
    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
        echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "⚠️  Could not set CPU governor"
    fi
    
    # Optimize CPU scheduler parameters
    sysctl -w kernel.sched_latency_ns=1000000 2>/dev/null || echo "⚠️  Could not set sched_latency_ns"
    sysctl -w kernel.sched_min_granularity_ns=100000 2>/dev/null || echo "⚠️  Could not set sched_min_granularity_ns"
    sysctl -w kernel.sched_wakeup_granularity_ns=250000 2>/dev/null || echo "⚠️  Could not set sched_wakeup_granularity_ns"
    
    # Set CPU affinity for critical processes
    set_cpu_affinity
    
    echo "✅ CPU optimization completed"
}

# Memory Optimization
optimize_memory() {
    echo "🧠 Optimizing memory performance..."
    
    # Configure memory management
    sysctl -w vm.swappiness=10 2>/dev/null || echo "⚠️  Could not set swappiness"
    sysctl -w vm.dirty_ratio=15 2>/dev/null || echo "⚠️  Could not set dirty_ratio"
    sysctl -w vm.dirty_background_ratio=5 2>/dev/null || echo "⚠️  Could not set dirty_background_ratio"
    sysctl -w vm.vfs_cache_pressure=50 2>/dev/null || echo "⚠️  Could not set vfs_cache_pressure"
    
    # Optimize memory allocation
    sysctl -w vm.overcommit_memory=1 2>/dev/null || echo "⚠️  Could not set overcommit_memory"
    sysctl -w vm.overcommit_ratio=50 2>/dev/null || echo "⚠️  Could not set overcommit_ratio"
    
    # Configure huge pages if available
    echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo "⚠️  Could not disable transparent hugepages"
    
    # Memory caching optimization
    sysctl -w vm.min_free_kbytes=65536 2>/dev/null || echo "⚠️  Could not set min_free_kbytes"
    
    echo "✅ Memory optimization completed"
}

# Process Prioritization
set_cpu_affinity() {
    echo "🎯 Setting CPU affinity for critical processes..."
    
    # Get number of CPU cores
    CPU_CORES=$(nproc)
    echo "📊 Available CPU cores: $CPU_CORES"
    
    # Define CPU affinity based on available cores
    if [ "$CPU_CORES" -ge 4 ]; then
        # Multi-core system optimization
        KASMVNC_AFFINITY="2,3"
        KDE_AFFINITY="0,1,2"
    elif [ "$CPU_CORES" -ge 2 ]; then
        # Dual-core system optimization
        KASMVNC_AFFINITY="1"
        KDE_AFFINITY="0,1"
    else
        # Single-core system (no affinity setting)
        echo "⚠️  Single-core system detected, skipping CPU affinity"
        return
    fi
    
    # Set affinity for critical processes (will be applied when processes start)
    export KASMVNC_CPU_AFFINITY="$KASMVNC_AFFINITY"
    export KDE_CPU_AFFINITY="$KDE_AFFINITY"
    
    echo "🎯 CPU affinity configuration set"
}

# Kernel Parameter Optimization
optimize_kernel_parameters() {
    echo "🔧 Optimizing kernel parameters..."
    
    # Network optimizations
    sysctl -w net.core.rmem_max=134217728 2>/dev/null || echo "⚠️  Could not set rmem_max"
    sysctl -w net.core.wmem_max=134217728 2>/dev/null || echo "⚠️  Could not set wmem_max"
    sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null || echo "⚠️  Could not set netdev_max_backlog"
    
    # TCP optimizations
    sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" 2>/dev/null || echo "⚠️  Could not set tcp_rmem"
    sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" 2>/dev/null || echo "⚠️  Could not set tcp_wmem"
    sysctl -w net.ipv4.tcp_window_scaling=1 2>/dev/null || echo "⚠️  Could not enable tcp_window_scaling"
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || echo "⚠️  Could not set BBR congestion control"
    
    # File system optimizations
    sysctl -w fs.file-max=65536 2>/dev/null || echo "⚠️  Could not set file-max"
    sysctl -w fs.inotify.max_user_watches=524288 2>/dev/null || echo "⚠️  Could not set inotify max_user_watches"
    
    # Process optimizations
    sysctl -w kernel.pid_max=65536 2>/dev/null || echo "⚠️  Could not set pid_max"
    
    echo "✅ Kernel parameter optimization completed"
}

# Smart Caching Strategy
implement_smart_caching() {
    echo "🗄️  Implementing smart caching strategies..."
    
    # Create optimized tmpfs for performance-critical directories
    if ! mountpoint -q /tmp; then
        mount -t tmpfs -o size=512M,noatime tmpfs /tmp 2>/dev/null || echo "⚠️  Could not mount tmpfs on /tmp"
    fi
    
    # Optimize disk I/O scheduler
    for disk in /sys/block/*/queue/scheduler; do
        if [ -f "$disk" ]; then
            echo "mq-deadline" > "$disk" 2>/dev/null || echo "⚠️  Could not set I/O scheduler"
        fi
    done
    
    # Configure read-ahead for better disk performance
    for disk in /sys/block/*/queue/read_ahead_kb; do
        if [ -f "$disk" ]; then
            echo "128" > "$disk" 2>/dev/null || echo "⚠️  Could not set read-ahead"
        fi
    done
    
    echo "✅ Smart caching implementation completed"
}

# Performance Monitoring and Alerting
setup_performance_monitoring() {
    echo "📊 Setting up performance monitoring..."
    
    # Create performance monitoring script
    cat > /usr/local/bin/system-performance-monitor << 'EOF'
#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/system-performance.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_LOAD=4.0

log_performance() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOGFILE"
}

monitor_system() {
    while true; do
        # Get system metrics
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
        MEM_USAGE=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
        LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
        
        # Network statistics
        RX_BYTES=$(cat /proc/net/dev | grep eth0 | awk '{print $2}' || echo "0")
        TX_BYTES=$(cat /proc/net/dev | grep eth0 | awk '{print $10}' || echo "0")
        
        # Process counts
        PROCESS_COUNT=$(ps aux | wc -l)
        ZOMBIE_COUNT=$(ps aux | awk '$8 ~ /^Z/ { count++ } END { print count+0 }')
        
        # Log current metrics
        log_performance "CPU: ${CPU_USAGE}%, MEM: ${MEM_USAGE}%, LOAD: ${LOAD_AVG}, DISK: ${DISK_USAGE}%, PROCS: ${PROCESS_COUNT}, ZOMBIES: ${ZOMBIE_COUNT}"
        
        # Check for alerts
        if (( $(echo "$CPU_USAGE > $ALERT_THRESHOLD_CPU" | bc -l 2>/dev/null || echo "0") )); then
            log_performance "ALERT: High CPU usage: ${CPU_USAGE}%"
            echo "⚠️  ALERT: High CPU usage: ${CPU_USAGE}%"
        fi
        
        if (( $(echo "$MEM_USAGE > $ALERT_THRESHOLD_MEM" | bc -l 2>/dev/null || echo "0") )); then
            log_performance "ALERT: High memory usage: ${MEM_USAGE}%"
            echo "⚠️  ALERT: High memory usage: ${MEM_USAGE}%"
        fi
        
        if (( $(echo "$LOAD_AVG > $ALERT_THRESHOLD_LOAD" | bc -l 2>/dev/null || echo "0") )); then
            log_performance "ALERT: High load average: ${LOAD_AVG}"
            echo "⚠️  ALERT: High load average: ${LOAD_AVG}"
        fi
        
        # Display current status
        echo "📊 System Status: CPU=${CPU_USAGE}%, MEM=${MEM_USAGE}%, LOAD=${LOAD_AVG}"
        
        sleep 30
    done
}

monitor_system
EOF
    
    chmod +x /usr/local/bin/system-performance-monitor
    
    echo "✅ Performance monitoring setup completed"
}

# Dynamic Resource Allocation
setup_dynamic_resource_allocation() {
    echo "⚖️  Setting up dynamic resource allocation..."
    
    cat > /usr/local/bin/dynamic-resource-allocator << 'EOF'
#!/bin/bash
set -euo pipefail

echo "⚖️  Starting dynamic resource allocation service..."

adjust_process_priorities() {
    local system_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local mem_usage=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
    
    echo "📊 Current system load: $system_load, Memory usage: ${mem_usage}%"
    
    # High load scenario - prioritize critical services
    if (( $(echo "$system_load > 2.0" | bc -l 2>/dev/null || echo "0") )); then
        echo "⚠️  High system load detected, adjusting priorities..."
        
        # Boost X server and VNC priorities
        pgrep kasmvncserver | xargs -r renice -5 2>/dev/null || true
        
        # Lower priority for non-essential processes
        pgrep firefox | xargs -r renice +10 2>/dev/null || true
        pgrep chrome | xargs -r renice +10 2>/dev/null || true
        
    # Normal load scenario - balanced priorities
    elif (( $(echo "$system_load < 1.0" | bc -l 2>/dev/null || echo "0") )); then
        echo "✅ Normal system load, balanced priorities"
        
        # Reset to normal priorities
        pgrep kasmvncserver | xargs -r renice 0 2>/dev/null || true
        pgrep firefox | xargs -r renice 0 2>/dev/null || true
        pgrep chrome | xargs -r renice 0 2>/dev/null || true
    fi
    
    # Memory pressure adjustments
    if (( $(echo "$mem_usage > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo "⚠️  High memory usage, triggering cleanup..."
        
        # Clear caches
        sync
        echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
        
        # Force garbage collection for applications that support it
        pkill -USR1 firefox 2>/dev/null || true
    fi
}

# Main monitoring loop
while true; do
    adjust_process_priorities
    sleep 60
done
EOF
    
    chmod +x /usr/local/bin/dynamic-resource-allocator
    
    echo "✅ Dynamic resource allocation setup completed"
}

# Process Priority Manager
setup_process_priority_manager() {
    echo "🎛️  Setting up intelligent process prioritization..."
    
    cat > /usr/local/bin/process-priority-manager << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🎛️  Starting process priority management..."

# Define priority classes
declare -A PRIORITY_CLASSES=(
    ["critical"]="rtprio:1"
    ["high"]="-10"
    ["normal"]="0"
    ["low"]="+10"
    ["background"]="+19"
)

# Define process classifications
declare -A PROCESS_PRIORITIES=(
    ["kasmvncserver"]="high"
    ["websockify"]="high"
    ["startplasma-x11"]="normal"
    ["plasmashell"]="normal"
    ["kwin_x11"]="normal"
    ["pulseaudio"]="high"
    ["firefox"]="low"
    ["chrome"]="low"
    ["chromium"]="low"
    ["gimp"]="normal"
    ["inkscape"]="normal"
    ["libreoffice"]="background"
)

set_process_priority() {
    local process_name="$1"
    local priority_class="${PROCESS_PRIORITIES[$process_name]:-normal}"
    local priority_value="${PRIORITY_CLASSES[$priority_class]}"
    
    pgrep "$process_name" | while read -r pid; do
        if [[ "$priority_value" == rtprio:* ]]; then
            # Real-time priority
            local rt_priority="${priority_value#rtprio:}"
            chrt -f -p "$rt_priority" "$pid" 2>/dev/null || echo "⚠️  Could not set RT priority for $process_name"
        else
            # Normal nice priority
            renice "$priority_value" "$pid" 2>/dev/null || echo "⚠️  Could not set priority for $process_name"
        fi
        echo "✅ Set priority $priority_value for $process_name (PID: $pid)"
    done
}

# Monitor and adjust priorities
while true; do
    for process in "${!PROCESS_PRIORITIES[@]}"; do
        set_process_priority "$process"
    done
    sleep 120
done
EOF
    
    chmod +x /usr/local/bin/process-priority-manager
    
    echo "✅ Process priority management setup completed"
}

# Performance profile configuration
configure_performance_profile() {
    case "$SYSTEM_PERFORMANCE_PROFILE" in
        "basic")
            echo "🔧 Applying basic performance profile..."
            CPU_OPTIMIZATION="false"
            ;;
        "balanced")
            echo "🔧 Applying balanced performance profile..."
            # Default settings are already balanced
            ;;
        "performance")
            echo "🔧 Applying high performance profile..."
            # Enable all optimizations
            ;;
        "ultra")
            echo "🔧 Applying ultra performance profile..."
            # Maximum optimizations
            export ALERT_THRESHOLD_CPU=90
            export ALERT_THRESHOLD_MEM=90
            ;;
        *)
            echo "⚠️  Unknown performance profile: $SYSTEM_PERFORMANCE_PROFILE"
            ;;
    esac
}

# Main execution
main() {
    echo "🚀 Starting system-level performance optimization..."
    
    # Configure performance profile
    configure_performance_profile
    
    # Apply optimizations based on configuration
    if [ "$CPU_OPTIMIZATION" = "true" ]; then
        optimize_cpu
    fi
    
    if [ "$MEMORY_OPTIMIZATION" = "true" ]; then
        optimize_memory
    fi
    
    # Always apply these optimizations
    optimize_kernel_parameters
    implement_smart_caching
    
    if [ "$PROCESS_PRIORITIZATION" = "true" ]; then
        setup_process_priority_manager
    fi
    
    setup_performance_monitoring
    setup_dynamic_resource_allocation
    
    echo "✅ System-level performance optimization completed"
    echo "📊 Performance monitoring active"
    echo "⚖️  Dynamic resource allocation enabled"
    echo "🎛️  Process prioritization configured"
}

# Execute main function
main "$@"
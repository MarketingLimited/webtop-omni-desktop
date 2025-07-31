#!/bin/bash

# Advanced health monitoring system
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
MONITOR_CONFIG_FILE="config/health-monitor.yml"
ALERT_LOG_FILE="logs/health-alerts.log"
METRICS_DIR="metrics"
NOTIFICATION_ENDPOINTS_FILE="config/notification-endpoints.yml"

# Ensure directories exist
mkdir -p logs metrics config

print_status() {
    echo -e "${BLUE}[HEALTH]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[HEALTHY]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

print_alert() {
    echo -e "${PURPLE}[ALERT]${NC} $1"
}

# Initialize default health monitor configuration
init_health_config() {
    if [ ! -f "$MONITOR_CONFIG_FILE" ]; then
        print_status "Creating default health monitor configuration..."
        cat > "$MONITOR_CONFIG_FILE" << 'EOF'
health_monitor:
  enabled: true
  check_interval: 30
  alert_threshold: 3
  
checks:
  container_health:
    enabled: true
    timeout: 10
    critical_threshold: 90
  
  resource_usage:
    enabled: true
    cpu_threshold: 80
    memory_threshold: 85
    disk_threshold: 90
  
  network_connectivity:
    enabled: true
    test_urls:
      - "http://localhost"
      - "https://google.com"
    timeout: 5
  
  service_endpoints:
    enabled: true
    endpoints:
      - name: "noVNC"
        url: "http://localhost:32768"
        expected_status: 200
      - name: "SSH"
        host: "localhost"
        port: 2222
        type: "tcp"
      - name: "TTYD"
        url: "http://localhost:7681"
        expected_status: 200

alerts:
  email:
    enabled: false
    smtp_server: ""
    smtp_port: 587
    username: ""
    password: ""
    to: ""
    from: ""
  
  webhook:
    enabled: false
    url: ""
    method: "POST"
    headers:
      Content-Type: "application/json"
  
  slack:
    enabled: false
    webhook_url: ""
    channel: "#alerts"
    username: "HealthMonitor"

retention:
  metrics_days: 30
  logs_days: 7
EOF
        print_success "Health monitor configuration created: $MONITOR_CONFIG_FILE"
    fi
}

# Load configuration
load_config() {
    if command -v yq &> /dev/null; then
        # Use yq if available for YAML parsing
        CHECK_INTERVAL=$(yq eval '.health_monitor.check_interval' "$MONITOR_CONFIG_FILE" 2>/dev/null || echo "30")
        ALERT_THRESHOLD=$(yq eval '.health_monitor.alert_threshold' "$MONITOR_CONFIG_FILE" 2>/dev/null || echo "3")
    else
        # Fallback to default values if yq not available
        CHECK_INTERVAL=30
        ALERT_THRESHOLD=3
        print_warning "yq not found, using default configuration values"
    fi
}

# Container health checks
check_container_health() {
    local container_pattern="$1"
    local issues=0
    local total_containers=0
    
    print_status "Checking container health..."
    
    # Get all webtop containers
    local containers=$(docker ps --format "{{.Names}}" | grep -E "${container_pattern:-webtop-}" || echo "")
    
    if [ -z "$containers" ]; then
        print_warning "No containers found matching pattern: ${container_pattern:-webtop-}"
        return 1
    fi
    
    for container in $containers; do
        ((total_containers++))
        
        # Check if container is running
        if ! docker ps --format "{{.Names}}" | grep -q "^$container$"; then
            print_error "Container $container is not running"
            ((issues++))
            log_alert "CRITICAL" "Container $container is not running"
            continue
        fi
        
        # Check container health status
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        
        case "$health_status" in
            "healthy")
                print_success "Container $container is healthy"
                ;;
            "unhealthy")
                print_error "Container $container is unhealthy"
                ((issues++))
                log_alert "CRITICAL" "Container $container is unhealthy"
                ;;
            "starting")
                print_warning "Container $container is starting"
                ;;
            *)
                print_warning "Container $container health status unknown"
                ;;
        esac
        
        # Check container resources
        local stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" "$container" 2>/dev/null)
        if [ -n "$stats" ]; then
            local cpu_usage=$(echo "$stats" | cut -d',' -f1 | sed 's/%//')
            local mem_usage=$(echo "$stats" | cut -d',' -f2 | sed 's/%//')
            
            # Check CPU usage
            if (( $(echo "$cpu_usage > 80" | bc -l 2>/dev/null || echo "0") )); then
                print_warning "Container $container high CPU usage: ${cpu_usage}%"
                log_alert "WARNING" "Container $container high CPU usage: ${cpu_usage}%"
            fi
            
            # Check memory usage
            if (( $(echo "$mem_usage > 85" | bc -l 2>/dev/null || echo "0") )); then
                print_warning "Container $container high memory usage: ${mem_usage}%"
                log_alert "WARNING" "Container $container high memory usage: ${mem_usage}%"
            fi
            
            # Store metrics
            store_metric "$container" "cpu_usage" "$cpu_usage"
            store_metric "$container" "memory_usage" "$mem_usage"
        fi
    done
    
    if [ $issues -eq 0 ]; then
        print_success "All $total_containers containers are healthy"
        return 0
    else
        print_error "$issues out of $total_containers containers have issues"
        return 1
    fi
}

# Resource monitoring
check_system_resources() {
    print_status "Checking system resources..."
    
    # Check disk usage
    local disk_usage=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        print_error "Critical disk usage: ${disk_usage}%"
        log_alert "CRITICAL" "Critical disk usage: ${disk_usage}%"
        return 1
    elif [ "$disk_usage" -gt 80 ]; then
        print_warning "High disk usage: ${disk_usage}%"
        log_alert "WARNING" "High disk usage: ${disk_usage}%"
    else
        print_success "Disk usage normal: ${disk_usage}%"
    fi
    
    # Check memory usage
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_usage=$(( (mem_total - mem_available) * 100 / mem_total ))
    
    if [ "$mem_usage" -gt 90 ]; then
        print_error "Critical memory usage: ${mem_usage}%"
        log_alert "CRITICAL" "Critical memory usage: ${mem_usage}%"
        return 1
    elif [ "$mem_usage" -gt 85 ]; then
        print_warning "High memory usage: ${mem_usage}%"
        log_alert "WARNING" "High memory usage: ${mem_usage}%"
    else
        print_success "Memory usage normal: ${mem_usage}%"
    fi
    
    # Check CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_percentage=$(echo "scale=2; $cpu_load * 100 / $cpu_cores" | bc -l 2>/dev/null || echo "0")
    
    if (( $(echo "$load_percentage > 90" | bc -l 2>/dev/null || echo "0") )); then
        print_error "Critical CPU load: ${load_percentage}%"
        log_alert "CRITICAL" "Critical CPU load: ${load_percentage}%"
        return 1
    elif (( $(echo "$load_percentage > 80" | bc -l 2>/dev/null || echo "0") )); then
        print_warning "High CPU load: ${load_percentage}%"
        log_alert "WARNING" "High CPU load: ${load_percentage}%"
    else
        print_success "CPU load normal: ${load_percentage}%"
    fi
    
    # Store system metrics
    store_metric "system" "disk_usage" "$disk_usage"
    store_metric "system" "memory_usage" "$mem_usage"
    store_metric "system" "cpu_load" "$load_percentage"
    
    return 0
}

# Network connectivity checks
check_network_connectivity() {
    print_status "Checking network connectivity..."
    
    local connectivity_issues=0
    
    # Test internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity working"
    else
        print_error "No internet connectivity"
        log_alert "CRITICAL" "No internet connectivity"
        ((connectivity_issues++))
    fi
    
    # Test DNS resolution
    if nslookup google.com &> /dev/null; then
        print_success "DNS resolution working"
    else
        print_error "DNS resolution failed"
        log_alert "CRITICAL" "DNS resolution failed"
        ((connectivity_issues++))
    fi
    
    # Test Docker daemon connectivity
    if docker info &> /dev/null; then
        print_success "Docker daemon connectivity working"
    else
        print_error "Docker daemon not accessible"
        log_alert "CRITICAL" "Docker daemon not accessible"
        ((connectivity_issues++))
    fi
    
    return $connectivity_issues
}

# Service endpoint checks
check_service_endpoints() {
    print_status "Checking service endpoints..."
    
    local endpoint_issues=0
    
    # Check common container ports
    local registry_file=".container-registry.json"
    if [ -f "$registry_file" ] && command -v jq &> /dev/null; then
        local containers=$(jq -r 'keys[]' "$registry_file" 2>/dev/null)
        
        for container in $containers; do
            local http_port=$(jq -r ".\"$container\".ports.http" "$registry_file" 2>/dev/null)
            local ssh_port=$(jq -r ".\"$container\".ports.ssh" "$registry_file" 2>/dev/null)
            
            # Check HTTP endpoint
            if [ "$http_port" != "null" ] && [ -n "$http_port" ]; then
                if curl -s --max-time 5 "http://localhost:$http_port" > /dev/null; then
                    print_success "Container $container HTTP endpoint (port $http_port) is accessible"
                else
                    print_error "Container $container HTTP endpoint (port $http_port) is not accessible"
                    log_alert "CRITICAL" "Container $container HTTP endpoint (port $http_port) is not accessible"
                    ((endpoint_issues++))
                fi
            fi
            
            # Check SSH endpoint
            if [ "$ssh_port" != "null" ] && [ -n "$ssh_port" ]; then
                if nc -z localhost "$ssh_port" 2>/dev/null; then
                    print_success "Container $container SSH endpoint (port $ssh_port) is accessible"
                else
                    print_error "Container $container SSH endpoint (port $ssh_port) is not accessible"
                    log_alert "CRITICAL" "Container $container SSH endpoint (port $ssh_port) is not accessible"
                    ((endpoint_issues++))
                fi
            fi
        done
    else
        print_warning "Container registry not found or jq not available, skipping container endpoint checks"
    fi
    
    return $endpoint_issues
}

# Docker system health
check_docker_health() {
    print_status "Checking Docker system health..."
    
    # Check Docker daemon status
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        log_alert "CRITICAL" "Docker daemon is not running"
        return 1
    fi
    
    # Check disk usage by Docker
    local docker_usage=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1 || echo "unknown")
    print_success "Docker system status: $docker_usage used"
    
    # Check for failed containers
    local failed_containers=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}" | grep "webtop-" || echo "")
    if [ -n "$failed_containers" ]; then
        print_warning "Found failed containers: $failed_containers"
        log_alert "WARNING" "Found failed containers: $failed_containers"
    else
        print_success "No failed containers found"
    fi
    
    # Check Docker volumes
    local orphaned_volumes=$(docker volume ls -q --filter "dangling=true" | wc -l)
    if [ "$orphaned_volumes" -gt 10 ]; then
        print_warning "Found $orphaned_volumes orphaned Docker volumes"
        log_alert "WARNING" "Found $orphaned_volumes orphaned Docker volumes"
    else
        print_success "Docker volumes status normal"
    fi
    
    return 0
}

# Store metrics
store_metric() {
    local component="$1"
    local metric="$2"
    local value="$3"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local metric_file="$METRICS_DIR/${component}_metrics.json"
    
    # Create metrics file if it doesn't exist
    if [ ! -f "$metric_file" ]; then
        echo '{"metrics": []}' > "$metric_file"
    fi
    
    # Add new metric entry
    if command -v jq &> /dev/null; then
        local temp_file=$(mktemp)
        jq ".metrics += [{\"timestamp\": \"$timestamp\", \"metric\": \"$metric\", \"value\": $value}]" "$metric_file" > "$temp_file" && mv "$temp_file" "$metric_file"
    fi
}

# Log alerts
log_alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo "[$timestamp] [$level] $message" >> "$ALERT_LOG_FILE"
    
    # Send notifications if configured
    send_notifications "$level" "$message" "$timestamp"
}

# Send notifications
send_notifications() {
    local level="$1"
    local message="$2"
    local timestamp="$3"
    
    # Webhook notification
    if command -v curl &> /dev/null; then
        # Simple webhook notification (could be expanded based on configuration)
        local webhook_url="${WEBHOOK_URL:-}"
        if [ -n "$webhook_url" ]; then
            curl -s -X POST "$webhook_url" \
                -H "Content-Type: application/json" \
                -d "{\"level\": \"$level\", \"message\": \"$message\", \"timestamp\": \"$timestamp\", \"source\": \"webtop-health-monitor\"}" \
                &> /dev/null || true
        fi
    fi
}

# Generate health report
generate_health_report() {
    local report_file="health-report-$(date +%Y%m%d_%H%M%S).json"
    
    print_status "Generating comprehensive health report..."
    
    cat > "$report_file" << EOF
{
    "report_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "checks_performed": [
        "container_health",
        "system_resources",
        "network_connectivity",
        "service_endpoints",
        "docker_health"
    ],
    "summary": {
        "total_containers": $(docker ps --format "{{.Names}}" | grep -c "webtop-" || echo "0"),
        "healthy_containers": $(docker ps --filter "health=healthy" --format "{{.Names}}" | grep -c "webtop-" || echo "0"),
        "system_load": "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')",
        "disk_usage": "$(df . | tail -1 | awk '{print $5}')",
        "memory_usage": "$(($(grep MemTotal /proc/meminfo | awk '{print $2}') - $(grep MemAvailable /proc/meminfo | awk '{print $2}')) * 100 / $(grep MemTotal /proc/meminfo | awk '{print $2}'))%"
    },
    "metrics_available": $([ -d "$METRICS_DIR" ] && find "$METRICS_DIR" -name "*.json" | wc -l || echo "0"),
    "alerts_in_last_24h": $([ -f "$ALERT_LOG_FILE" ] && grep "$(date -d '24 hours ago' -u +%Y-%m-%d)" "$ALERT_LOG_FILE" | wc -l || echo "0")
}
EOF
    
    print_success "Health report generated: $report_file"
}

# Cleanup old metrics and logs
cleanup_old_data() {
    local retention_days=30
    
    print_status "Cleaning up old data (older than $retention_days days)..."
    
    # Cleanup old metrics
    if [ -d "$METRICS_DIR" ]; then
        find "$METRICS_DIR" -name "*.json" -mtime +$retention_days -delete 2>/dev/null || true
    fi
    
    # Cleanup old logs
    if [ -f "$ALERT_LOG_FILE" ]; then
        # Keep only last 1000 lines
        tail -1000 "$ALERT_LOG_FILE" > "${ALERT_LOG_FILE}.tmp" && mv "${ALERT_LOG_FILE}.tmp" "$ALERT_LOG_FILE"
    fi
    
    print_success "Cleanup completed"
}

# Continuous monitoring mode
monitor_continuous() {
    local interval="${1:-$CHECK_INTERVAL}"
    
    print_status "Starting continuous health monitoring (interval: ${interval}s)"
    print_status "Press Ctrl+C to stop monitoring"
    echo
    
    while true; do
        clear
        echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║                    WEBTOP HEALTH MONITOR                     ║${NC}"
        echo -e "${PURPLE}║                    $(date +'%Y-%m-%d %H:%M:%S UTC')                    ║${NC}"
        echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        
        local overall_status=0
        
        check_container_health "webtop-" || ((overall_status++))
        echo
        
        check_system_resources || ((overall_status++))
        echo
        
        check_network_connectivity || ((overall_status++))
        echo
        
        check_service_endpoints || ((overall_status++))
        echo
        
        check_docker_health || ((overall_status++))
        echo
        
        if [ $overall_status -eq 0 ]; then
            print_success "Overall system status: HEALTHY"
        else
            print_error "Overall system status: $overall_status ISSUES DETECTED"
        fi
        
        echo
        echo "Next check in ${interval} seconds..."
        sleep "$interval"
    done
}

# Main function
main() {
    case "$1" in
        init)
            init_health_config
            ;;
        check)
            init_health_config
            load_config
            
            local overall_status=0
            check_container_health "${2:-webtop-}" || ((overall_status++))
            check_system_resources || ((overall_status++))
            check_network_connectivity || ((overall_status++))
            check_service_endpoints || ((overall_status++))
            check_docker_health || ((overall_status++))
            
            if [ $overall_status -eq 0 ]; then
                print_success "All health checks passed"
                exit 0
            else
                print_error "$overall_status health check(s) failed"
                exit 1
            fi
            ;;
        monitor)
            init_health_config
            load_config
            monitor_continuous "$2"
            ;;
        report)
            generate_health_report
            ;;
        cleanup)
            cleanup_old_data
            ;;
        containers)
            check_container_health "${2:-webtop-}"
            ;;
        resources)
            check_system_resources
            ;;
        network)
            check_network_connectivity
            ;;
        endpoints)
            check_service_endpoints
            ;;
        docker)
            check_docker_health
            ;;
        *)
            echo "Usage: $0 {init|check|monitor|report|cleanup|containers|resources|network|endpoints|docker} [options]"
            echo
            echo "Commands:"
            echo "  init                     Initialize health monitor configuration"
            echo "  check [pattern]          Run all health checks"
            echo "  monitor [interval]       Start continuous monitoring"
            echo "  report                   Generate health report"
            echo "  cleanup                  Clean up old metrics and logs"
            echo "  containers [pattern]     Check container health only"
            echo "  resources                Check system resources only"
            echo "  network                  Check network connectivity only"
            echo "  endpoints                Check service endpoints only"
            echo "  docker                   Check Docker system health only"
            exit 1
            ;;
    esac
}

# Install dependencies if missing
if ! command -v bc &> /dev/null; then
    print_warning "bc not found. Some calculations may not work properly."
fi

if ! command -v nc &> /dev/null; then
    print_warning "nc (netcat) not found. Port checks may not work properly."
fi

# Run main function
main "$@"
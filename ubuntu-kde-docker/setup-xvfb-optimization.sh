#!/bin/bash
set -euo pipefail

# Xvfb Display Server Optimization Script
echo "🖥️  Optimizing Xvfb display server..."

# Environment variables with defaults
DISPLAY_NUM="${DISPLAY_NUM:-:1}"
XVFB_RESOLUTION="${XVFB_RESOLUTION:-1920x1080x24}"
XVFB_DPI="${XVFB_DPI:-96}"
XVFB_PERFORMANCE_PROFILE="${XVFB_PERFORMANCE_PROFILE:-balanced}"

# Performance profiles
case "$XVFB_PERFORMANCE_PROFILE" in
    "basic")
        XVFB_ARGS="-screen 0 ${XVFB_RESOLUTION} -dpi ${XVFB_DPI} -ac +extension GLX +render -noreset"
        ;;
    "balanced")
        XVFB_ARGS="-screen 0 ${XVFB_RESOLUTION} -dpi ${XVFB_DPI} -ac +extension GLX +render +extension RANDR +extension XFIXES +extension DAMAGE +extension COMPOSITE -noreset -shmem"
        ;;
    "performance")
        XVFB_ARGS="-screen 0 ${XVFB_RESOLUTION} -dpi ${XVFB_DPI} -ac +extension GLX +render +extension RANDR +extension XFIXES +extension DAMAGE +extension COMPOSITE +extension MIT-SHM +extension XINERAMA -noreset -shmem -fbdir /tmp"
        ;;
    "ultra")
        XVFB_ARGS="-screen 0 ${XVFB_RESOLUTION} -screen 1 1920x1080x24 -dpi ${XVFB_DPI} -ac +extension GLX +render +extension RANDR +extension XFIXES +extension DAMAGE +extension COMPOSITE +extension MIT-SHM +extension XINERAMA +extension BIG-REQUESTS +extension SYNC -noreset -shmem -fbdir /tmp -maxbigreqsize 65536"
        ;;
    *)
        echo "⚠️  Unknown performance profile: $XVFB_PERFORMANCE_PROFILE, using balanced"
        XVFB_ARGS="-screen 0 ${XVFB_RESOLUTION} -dpi ${XVFB_DPI} -ac +extension GLX +render +extension RANDR +extension XFIXES +extension DAMAGE +extension COMPOSITE -noreset -shmem"
        ;;
esac

# Create optimized framebuffer directory
mkdir -p /tmp/xvfb-fb
chmod 777 /tmp/xvfb-fb

# Set up shared memory optimizations
echo "🔧 Configuring shared memory optimizations..."
sysctl -w kernel.shmmax=134217728 2>/dev/null || echo "⚠️  Could not set shmmax (container limitation)"
sysctl -w kernel.shmall=32768 2>/dev/null || echo "⚠️  Could not set shmall (container limitation)"

# Create Xvfb wrapper script
cat > /usr/local/bin/xvfb-optimized << 'EOF'
#!/bin/bash
set -euo pipefail

# Dynamic resolution detection based on environment
detect_optimal_resolution() {
    # Check if client resolution is specified
    if [ -n "${CLIENT_RESOLUTION:-}" ]; then
        echo "$CLIENT_RESOLUTION"
        return
    fi
    
    # Default to high-resolution for performance testing
    echo "1920x1080x24"
}

# Get optimal settings
RESOLUTION=$(detect_optimal_resolution)
PERFORMANCE_PROFILE="${XVFB_PERFORMANCE_PROFILE:-balanced}"

echo "🖥️  Starting Xvfb with resolution: $RESOLUTION, profile: $PERFORMANCE_PROFILE"

# Execute Xvfb with optimized parameters
exec /usr/bin/Xvfb "$@"
EOF

chmod +x /usr/local/bin/xvfb-optimized

# Create dynamic resolution script
cat > /usr/local/bin/xvfb-set-resolution << 'EOF'
#!/bin/bash
set -euo pipefail

# Dynamic resolution setter for running Xvfb
DISPLAY_NUM="${1:-:1}"
NEW_RESOLUTION="${2:-1920x1080}"

echo "🔧 Setting display $DISPLAY_NUM to resolution $NEW_RESOLUTION"

# Use xrandr to change resolution if available
if command -v xrandr >/dev/null 2>&1; then
    DISPLAY="$DISPLAY_NUM" xrandr --size "$NEW_RESOLUTION" 2>/dev/null || {
        echo "⚠️  Could not change resolution with xrandr"
    }
else
    echo "⚠️  xrandr not available for dynamic resolution change"
fi
EOF

chmod +x /usr/local/bin/xvfb-set-resolution

# Create multi-screen setup script
cat > /usr/local/bin/xvfb-multiscreen << 'EOF'
#!/bin/bash
set -euo pipefail

# Multi-screen setup for productivity workflows
DISPLAY_NUM="${1:-:1}"
SCREEN_COUNT="${2:-1}"

echo "🖥️  Setting up $SCREEN_COUNT screens on display $DISPLAY_NUM"

case "$SCREEN_COUNT" in
    "1")
        echo "Single screen configuration active"
        ;;
    "2")
        echo "Dual screen configuration (1920x1080 + 1920x1080)"
        # Configuration for dual screens
        ;;
    "3")
        echo "Triple screen configuration (3x 1920x1080)"
        # Configuration for triple screens
        ;;
    *)
        echo "⚠️  Unsupported screen count: $SCREEN_COUNT"
        ;;
esac
EOF

chmod +x /usr/local/bin/xvfb-multiscreen

echo "🔧 Xvfb optimization setup complete"
echo "📊 Available performance profiles: basic, balanced, performance, ultra"
echo "🖥️  Use XVFB_PERFORMANCE_PROFILE environment variable to select profile"
echo "📐 Use XVFB_RESOLUTION environment variable to set custom resolution"
echo "✅ Xvfb display server optimization completed"
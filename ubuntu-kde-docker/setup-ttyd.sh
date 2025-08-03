#!/bin/bash
set -euo pipefail

# TTYD Setup and Health Check Script for Marketing Agency WebTop
echo "🔧 Setting up TTYD terminal service..."

# Set default values
TTYD_USER=${TTYD_USER:-terminal}
TTYD_PASSWORD=${TTYD_PASSWORD:-terminal}
TTYD_PORT=${TTYD_PORT:-7681}

# Create TTYD log directory
mkdir -p /var/log/supervisor

# Test TTYD configuration
echo "Testing TTYD configuration..."
echo "TTYD_USER: $TTYD_USER"
echo "TTYD_PORT: $TTYD_PORT"

# Check if TTYD is installed
if ! command -v ttyd >/dev/null 2>&1; then
    echo "❌ TTYD not found, installing..."
    apt-get update && apt-get install -y ttyd && \
        apt-get clean && rm -rf /var/lib/apt/lists/*
fi

# Ensure wrapper script is executable
chmod +x /usr/local/bin/ttyd-wrapper.sh

# Create TTYD health check script
cat <<'EOF' > /usr/local/bin/ttyd-health.sh
#!/bin/bash
TTYD_PORT=${TTYD_PORT:-7681}

if pgrep -f "ttyd.*$TTYD_PORT" >/dev/null; then
    echo "✅ TTYD process is running"
else
    echo "❌ TTYD process not found"
    exit 1
fi

if ss -ltn | awk '{print $4}' | grep -q ":$TTYD_PORT$"; then
    echo "✅ TTYD is listening on port $TTYD_PORT"
else
    echo "❌ TTYD is not listening on port $TTYD_PORT"
    exit 1
fi

echo "✅ TTYD health check passed"
EOF

chmod +x /usr/local/bin/ttyd-health.sh

echo "✅ TTYD setup completed"

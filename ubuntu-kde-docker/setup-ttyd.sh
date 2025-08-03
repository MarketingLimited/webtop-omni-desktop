#!/bin/bash

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
if ! command -v ttyd &> /dev/null; then
    echo "❌ TTYD not found, installing..."
    apt-get update && apt-get install -y ttyd
fi

# Create TTYD wrapper script with better error handling
cat <<'EOF' > /usr/local/bin/ttyd-wrapper.sh
#!/bin/bash

# TTYD Wrapper Script with Error Handling
set -e

TTYD_USER=${TTYD_USER:-terminal}
TTYD_PASSWORD=${TTYD_PASSWORD:-terminal}
TTYD_PORT=${TTYD_PORT:-7681}

echo "🔧 Starting TTYD service..."
echo "User: $TTYD_USER"
echo "Port: $TTYD_PORT"

# Wait for system to be ready
sleep 5

# Check if port is available
if netstat -tuln | grep -q ":$TTYD_PORT "; then
    echo "⚠️  Port $TTYD_PORT is already in use"
    exit 1
fi

# Start TTYD with proper error handling
exec /usr/bin/ttyd \
    --port "$TTYD_PORT" \
    --credential "$TTYD_USER:$TTYD_PASSWORD" \
    --writable \
    --reconnect 10 \
    --max-clients 5 \
    --once \
    bash
EOF

chmod +x /usr/local/bin/ttyd-wrapper.sh

# Create TTYD health check script
cat <<'EOF' > /usr/local/bin/ttyd-health.sh
#!/bin/bash

# TTYD Health Check Script
TTYD_PORT=${TTYD_PORT:-7681}

# Check if TTYD process is running
if pgrep -f "ttyd.*$TTYD_PORT" > /dev/null; then
    echo "✅ TTYD process is running"
else
    echo "❌ TTYD process not found"
    exit 1
fi

# Check if port is listening
if netstat -tuln | grep -q ":$TTYD_PORT "; then
    echo "✅ TTYD is listening on port $TTYD_PORT"
else
    echo "❌ TTYD is not listening on port $TTYD_PORT"
    exit 1
fi

echo "✅ TTYD health check passed"
EOF

chmod +x /usr/local/bin/ttyd-health.sh

echo "✅ TTYD setup completed"
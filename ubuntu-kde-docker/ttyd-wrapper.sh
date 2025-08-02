#!/bin/bash
set -euo pipefail

# TTYD Wrapper Script with Error Handling
TTYD_USER="${TTYD_USER:-terminal}"
TTYD_PASSWORD="${TTYD_PASSWORD:-terminal}"
TTYD_PORT="${TTYD_PORT:-7681}"

echo "🔧 Starting TTYD service..."
echo "User: $TTYD_USER"
echo "Port: $TTYD_PORT"

# Wait briefly to ensure environment is ready
sleep 5

# Ensure ttyd is available
if ! command -v ttyd >/dev/null 2>&1; then
    echo "❌ ttyd command not found"
    exit 1
fi

# Check if desired port is free
if ss -ltn | awk '{print $4}' | grep -q ":$TTYD_PORT$"; then
    echo "⚠️  Port $TTYD_PORT is already in use"
    exit 1
fi

echo "🚀 Starting ttyd on port $TTYD_PORT..."
exec /usr/bin/ttyd \
    --port "$TTYD_PORT" \
    --credential "$TTYD_USER:$TTYD_PASSWORD" \
    --writable \
    --reconnect 10 \
    --max-clients 5 \
    --once \
    bash

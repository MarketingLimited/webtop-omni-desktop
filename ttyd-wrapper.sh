#!/bin/bash
set -euo pipefail

# TTYD wrapper script to ensure proper startup
echo "🔧 Starting TTYD terminal service..."

# Set defaults
TTYD_USER="${TTYD_USER:-terminal}"
TTYD_PASSWORD="${TTYD_PASSWORD:-terminal}"
TTYD_PORT="${TTYD_PORT:-7681}"

# Ensure ttyd is available
if ! command -v ttyd >/dev/null 2>&1; then
    echo "❌ ttyd command not found"
    exit 1
fi

# Start ttyd with credentials
echo "🚀 Starting ttyd on port ${TTYD_PORT}..."
exec ttyd --port "${TTYD_PORT}" --credential "${TTYD_USER}:${TTYD_PASSWORD}" bash
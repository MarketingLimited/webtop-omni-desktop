#!/bin/bash
# wait-for-service.sh: A script to wait for a file/socket to exist before executing a command.

set -euo pipefail

TARGET_FILE="$1"
shift
COMMAND_TO_RUN="$@"
TIMEOUT=60

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }

echo "Waiting for '$TARGET_FILE' to be available..."

start_time=$(date +%s)
retry_count=0
max_retries=3

while [ ! -e "$TARGET_FILE" ]; do
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
        retry_count=$((retry_count + 1))
        if [ "$retry_count" -le "$max_retries" ]; then
            yellow "Warning: Timeout reached, retrying ($retry_count/$max_retries)..."
            start_time=$(date +%s)
            sleep 2
        else
            red "Error: Timed out after $TIMEOUT seconds waiting for '$TARGET_FILE' (tried $max_retries times)." >&2
            exit 1
        fi
    fi
    sleep 1
done

green "Service '$TARGET_FILE' is ready. Executing command: $COMMAND_TO_RUN"

# Add environment setup for PipeWire services
if [[ "$COMMAND_TO_RUN" == *"pipewire"* ]] || [[ "$COMMAND_TO_RUN" == *"wireplumber"* ]]; then
    export PIPEWIRE_LOG_LEVEL=2
    export PIPEWIRE_LATENCY=1024/44100
fi

exec $COMMAND_TO_RUN

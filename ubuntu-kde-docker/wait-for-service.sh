#!/bin/bash
# wait-for-service.sh: A script to wait for a file/socket to exist before executing a command.

set -euo pipefail

TARGET_FILE="$1"
shift
COMMAND_TO_RUN="$@"
TIMEOUT=30

echo "Waiting for '$TARGET_FILE' to be available..."

start_time=$(date +%s)
while [ ! -e "$TARGET_FILE" ]; do
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
        echo "Error: Timed out after $TIMEOUT seconds waiting for '$TARGET_FILE'." >&2
        exit 1
    fi
    sleep 1
done

echo "Service '$TARGET_FILE' is ready. Executing command: $COMMAND_TO_RUN"
exec $COMMAND_TO_RUN

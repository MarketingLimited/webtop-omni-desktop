#!/usr/bin/env bash
set -euo pipefail

# Determine the directory where this script resides
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make all shell scripts within this directory tree executable
find "$SCRIPT_DIR" -type f -name '*.sh' -print0 | xargs -0 -r chmod +x

echo "✅ All shell scripts under $(basename "$SCRIPT_DIR") are now executable."

#!/bin/bash

# Fix Permissions Script
# This script sets executable permissions for all shell script files

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Fixing permissions for all shell script files...${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Find and fix permissions for all .sh files
echo "Setting executable permissions for .sh files..."

# Make all .sh files executable
find . -name "*.sh" -type f -exec chmod +x {} \;

# Specifically ensure key scripts are executable
chmod +x webtop.sh 2>/dev/null || true
chmod +x install.sh 2>/dev/null || true
chmod +x fix-permissions.sh 2>/dev/null || true
chmod +x entrypoint.sh 2>/dev/null || true
chmod +x health-check.sh 2>/dev/null || true
chmod +x setup-*.sh 2>/dev/null || true

# List all shell scripts and their permissions
echo
echo "Shell script files and their permissions:"
echo "========================================="
find . -name "*.sh" -type f -exec ls -la {} \; | awk '{print $1, $9}' | sort

echo
echo -e "${GREEN}✅ All shell script permissions have been fixed!${NC}"

# Verify key scripts
echo
echo "Verifying key scripts:"
for script in webtop.sh install.sh entrypoint.sh health-check.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo -e "  ✅ $script - executable"
        else
            echo -e "  ❌ $script - not executable"
        fi
    else
        echo -e "  ⚠️  $script - not found"
    fi
done

echo
echo -e "${GREEN}🎉 Permission fix complete! You can now run:${NC}"
echo "  ./webtop.sh --help"
echo "  ./install.sh"
echo
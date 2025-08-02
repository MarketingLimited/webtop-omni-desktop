#!/bin/bash
set -euo pipefail

# Install jq for JSON parsing if not available
if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq for JSON parsing..."

    if command -v apt-get >/dev/null 2>&1; then
        # Remove broken PostgreSQL repository first
        sudo rm -f /etc/apt/sources.list.d/pgdg.list* 2>/dev/null || true
        sudo apt-get update -qq
        sudo apt-get install -y jq
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y jq
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y jq
    elif command -v brew >/dev/null 2>&1; then
        brew install jq
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm jq
    else
        echo "Please install jq manually for your system"
        echo "Ubuntu/Debian: sudo apt-get install jq"
        echo "Fedora: sudo dnf install jq"
        echo "CentOS/RHEL: sudo yum install jq"
        echo "macOS: brew install jq"
        echo "Arch: sudo pacman -S jq"
        exit 1
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "jq installed successfully"
    else
        echo "Failed to install jq"
        exit 1
    fi
fi


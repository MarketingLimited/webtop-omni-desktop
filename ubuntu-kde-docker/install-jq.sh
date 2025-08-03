#!/bin/bash

# Install jq for JSON parsing if not available
if ! command -v jq &> /dev/null; then
    echo "Installing jq for JSON parsing..."
    
    if command -v apt-get &> /dev/null; then
        # Remove broken PostgreSQL repository first
        sudo rm -f /etc/apt/sources.list.d/pgdg.list* 2>/dev/null || true
        sudo apt-get update -qq && sudo apt-get install -y jq 2>/dev/null
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq 2>/dev/null
    elif command -v brew &> /dev/null; then
        brew install jq 2>/dev/null
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm jq 2>/dev/null
    else
        echo "Please install jq manually for your system"
        echo "Ubuntu/Debian: sudo apt-get install jq"
        echo "CentOS/RHEL: sudo yum install jq"
        echo "macOS: brew install jq"
        echo "Arch: sudo pacman -S jq"
        exit 1
    fi
    
    if command -v jq &> /dev/null; then
        echo "jq installed successfully"
    else
        echo "Failed to install jq"
        exit 1
    fi
fi
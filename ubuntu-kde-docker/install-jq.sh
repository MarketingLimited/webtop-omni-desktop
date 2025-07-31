#!/bin/bash

# Install jq for JSON parsing if not available
if ! command -v jq &> /dev/null; then
    echo "Installing jq for JSON parsing..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm jq
    else
        echo "Please install jq manually for your system"
        echo "Ubuntu/Debian: sudo apt-get install jq"
        echo "CentOS/RHEL: sudo yum install jq"
        echo "macOS: brew install jq"
        echo "Arch: sudo pacman -S jq"
        exit 1
    fi
    
    echo "jq installed successfully"
else
    echo "jq is already installed"
fi
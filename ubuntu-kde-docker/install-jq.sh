#!/bin/bash

# Install jq for JSON parsing if not available
if ! command -v jq &> /dev/null; then
    echo "Installing jq for JSON parsing..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y jq
    elif command -v yum &> /dev/null; then
        yum install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        echo "Please install jq manually for your system"
        exit 1
    fi
    
    echo "jq installed successfully"
else
    echo "jq is already installed"
fi
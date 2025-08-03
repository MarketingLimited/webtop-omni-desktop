#!/bin/bash
# Master script to apply all container fixes
set -euo pipefail

echo "🔧 Applying comprehensive container fixes..."

# Make all scripts executable
/usr/local/bin/make-scripts-executable.sh

# Apply container-specific fixes
if [ -x /usr/local/bin/setup-container-fixes.sh ]; then
    /usr/local/bin/setup-container-fixes.sh
fi

echo "✅ Container fixes applied successfully"
echo "📋 Key improvements:"
echo "   - Enhanced D-Bus stability with health monitoring"
echo "   - Improved service dependency management"
echo "   - Better error handling and recovery mechanisms"
echo "   - Optimized supervisor configuration"
echo "   - Graceful handling of missing components"
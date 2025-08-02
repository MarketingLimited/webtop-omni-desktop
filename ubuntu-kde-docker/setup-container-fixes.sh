#!/bin/bash
set -euo pipefail

echo "🔧 Applying container fixes..."

# Ensure relevant scripts are executable
find /usr/local/bin -type f \( \
    -name "setup-*.sh" -o \
    -name "check-*.sh" -o \
    -name "start-*.sh" \
\) -exec chmod +x {} +

# Run available setup scripts
scripts=(
    setup-container-dbus.sh
    setup-font-config.sh
    setup-wine-container.sh
    setup-android-container.sh
    setup-enhanced-monitoring.sh
    setup-system-optimization.sh
    setup-network-optimization.sh
    setup-kde-optimization.sh
)

for script in "${scripts[@]}"; do
    script_path="/usr/local/bin/${script}"
    if [ -x "$script_path" ]; then
        echo "▶️ Running ${script}..."
        "$script_path"
    fi
done

echo "✅ Container fixes applied successfully"


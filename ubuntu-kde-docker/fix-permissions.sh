#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"
DEV_HOME="/home/${DEV_USERNAME}"
readonly DEV_USERNAME DEV_UID DEV_GID DEV_HOME

echo "🔧 Fixing file permissions and ownership..."

# Ensure the dev user exists
if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
    echo "User $DEV_USERNAME does not exist, cannot fix permissions"
    exit 1
fi

# Fix home directory ownership
chown -R "${DEV_UID}:${DEV_GID}" "$DEV_HOME" 2>/dev/null || true

# Fix desktop and application directories
dirs=(Desktop Documents Downloads Pictures Videos Music Public Templates .local .config .vnc)
for dir in "${dirs[@]}"; do
    path="${DEV_HOME}/${dir}"
    if [ -d "$path" ]; then
        chown -R "${DEV_UID}:${DEV_GID}" "$path"
        chmod -R u+rwX "$path"
    fi
done

# Fix desktop files permissions
desktop_dir="${DEV_HOME}/Desktop"
if [ -d "$desktop_dir" ]; then
    find "$desktop_dir" -type f -name "*.desktop" -exec chmod +x {} + 2>/dev/null || true
fi

# Fix XDG runtime directory
xdg_dir="/run/user/${DEV_UID}"
if [ -d "$xdg_dir" ]; then
    chown "${DEV_UID}:${DEV_GID}" "$xdg_dir"
    chmod 700 "$xdg_dir"
fi

# Fix supervisor log directory permissions
log_dir="/var/log/supervisor"
mkdir -p "$log_dir"
chmod 755 "$log_dir"

echo "✅ Permissions fixed successfully"


#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"

echo "🔧 Fixing file permissions and ownership..."

# Ensure the dev user exists
if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
    echo "User $DEV_USERNAME does not exist, cannot fix permissions"
    exit 1
fi

# Fix home directory ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}" 2>/dev/null || true

# Fix desktop and application directories
for dir in Desktop .local .config .vnc; do
    if [ -d "/home/${DEV_USERNAME}/$dir" ]; then
        chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/$dir"
        chmod -R u+rwX "/home/${DEV_USERNAME}/$dir"
    fi
done

# Fix desktop files permissions
find "/home/${DEV_USERNAME}/Desktop" -name "*.desktop" -exec chmod +x {} \; 2>/dev/null || true

# Fix XDG runtime directory
if [ -d "/run/user/${DEV_UID}" ]; then
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"
fi

# Fix supervisor log directory permissions
mkdir -p /var/log/supervisor
chmod 755 /var/log/supervisor

echo "✅ Permissions fixed successfully"
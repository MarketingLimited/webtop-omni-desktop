#!/bin/bash
# Pre-check for Android kernel modules needed by Waydroid
set -e

# Skip checks when running in a container
if [ -n "$CONTAINER" ] || [ -f /.dockerenv ] || [ -f /.containerenv ] \
   || grep -qaE '(docker|lxc|kubepods|containerd|podman)' /proc/1/cgroup; then
    echo "Warning: Detected container environment; skipping Android kernel module checks." >&2
    exit 0
fi

missing=()
for mod in binder_linux ashmem_linux; do
    if ! lsmod | grep -q "$mod"; then
        missing+=("$mod")
    fi
done

if [ ${#missing[@]} -ne 0 ]; then
    echo "Missing kernel modules: ${missing[*]}" >&2
    echo "Android support requires binder_linux and ashmem_linux on the host." >&2
    echo "Refer to ubuntu-kde-docker/README.md#android-host-kernel-modules for loading instructions." >&2
    exit 1
else
    echo "All required Android kernel modules are present."
fi

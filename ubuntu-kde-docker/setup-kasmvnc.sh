#!/bin/bash
set -euo pipefail

# Install KasmVNC from latest release
ARCH="$(dpkg --print-architecture)"
RELEASE="noble"
DEB_URL="https://github.com/kasmtech/KasmVNC/releases/latest/download/kasmvncserver_${RELEASE}_${ARCH}.deb"

wget -q -O /tmp/kasmvncserver.deb "$DEB_URL"
apt-get update
apt-get install -y /tmp/kasmvncserver.deb
rm -f /tmp/kasmvncserver.deb
apt-get clean

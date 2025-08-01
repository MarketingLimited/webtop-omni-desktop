#!/bin/bash
set -euo pipefail

# Install KasmVNC version 1.3.4 for the current architecture
ARCH="$(dpkg --print-architecture)"
RELEASE="noble"
VERSION="1.3.4"
DEB_URL="https://github.com/kasmtech/KasmVNC/releases/download/v${VERSION}/kasmvncserver_${RELEASE}_${VERSION}_${ARCH}.deb"

wget -q -O /tmp/kasmvncserver.deb "$DEB_URL"
apt-get update
apt-get install -y /tmp/kasmvncserver.deb
rm -f /tmp/kasmvncserver.deb
apt-get clean

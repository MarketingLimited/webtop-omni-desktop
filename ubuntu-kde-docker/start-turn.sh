#!/bin/bash
set -e

TURN_PORT="${WEBRTC_TURN_PORT:-3478}"
REALM="${WEBRTC_TURN_REALM:-webtop}"
USER="${WEBRTC_TURN_USERNAME:-webtop}"
PASS="${WEBRTC_TURN_PASSWORD:-webtop}"

exec /usr/bin/turnserver -a -v --no-cli --no-tls --no-dtls \
  --listening-port "$TURN_PORT" \
  --realm "$REALM" \
  --user "$USER:$PASS"

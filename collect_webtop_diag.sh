#!/usr/bin/env bash
# collect_webtop_diag.sh
# Collects environment + supervisor + PulseAudio + AudioBridge diagnostics from a running container.

set -uo pipefail

CONTAINER="${1:-webtop-kde}"
DESKTOP_USER="${DESKTOP_USER:-devuser}"
PULSE_TCP="${PULSE_SERVER_OVERRIDE:-tcp:localhost:4713}"
BRIDGE_PORT="${BRIDGE_PORT:-8080}"
BRIDGE_PATH="${BRIDGE_PATH:-/opt/audio-bridge}"

ts() { date -u +'%F %T UTC'; }
hdr() { printf '\n\n===== [%s] %s =====\n' "$(ts)" "$*"; }
rin() { docker exec -i "$CONTAINER" bash -lc "$*" ; }          # run in container (may fail)
rinq(){ docker exec -i "$CONTAINER" bash -lc "$*" || true; }   # run in container, ignore failures

hdr "BASIC CHECKS"
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
  echo "ERROR: container '$CONTAINER' is not running"; exit 1
fi
docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}' | (grep -E "\s$CONTAINER$" || true)
printf 'Params -> CONTAINER=%s  DESKTOP_USER=%s  PULSE_TCP=%s  BRIDGE_PORT=%s  BRIDGE_PATH=%s\n' \
  "$CONTAINER" "$DESKTOP_USER" "$PULSE_TCP" "$BRIDGE_PORT" "$BRIDGE_PATH"

hdr "1) OS & SUPERVISOR BASICS INSIDE CONTAINER"
rinq 'cat /etc/os-release; echo ---; uname -a'
rinq 'echo "# supervisorctl location & version"; command -v supervisorctl; supervisorctl version || true'
rinq 'echo "# supervisord.conf (first 200 lines)"; sed -n "1,200p" /etc/supervisor/supervisord.conf 2>/dev/null || true'
rinq 'echo "# include lines (if any)"; grep -RIn "^\[include\]" /etc/supervisor/supervisord.conf 2>/dev/null || true'
rinq 'echo "# tools availability"; for x in bash sudo su getent pactl pulseaudio node curl awk sed ss; do printf "%-10s -> " "$x"; command -v "$x" || echo "NOT FOUND"; done'

hdr "2) USERS & PERMISSIONS"
rinq "echo '# getent passwd ${DESKTOP_USER}'; getent passwd ${DESKTOP_USER} || true"
rinq "echo '# id ${DESKTOP_USER}'; id ${DESKTOP_USER} || true"
rinq "echo '# groups ${DESKTOP_USER}'; groups ${DESKTOP_USER} || true"
rinq "echo '# sudoers for ${DESKTOP_USER}'; sudo -l -U ${DESKTOP_USER} 2>/dev/null || true; ls -l /etc/sudoers.d 2>/dev/null || true"

hdr "3) PULSEAUDIO ENVIRONMENT & STATE"
rinq 'env | sort | egrep "^(PULSE|XDG|USER|HOME)="' 
rinq 'pulseaudio --version || true'
rinq "PULSE_SERVER='${PULSE_TCP}' pactl info || true"
rinq "echo '--- modules ---';   PULSE_SERVER='${PULSE_TCP}' pactl list modules short 2>/dev/null || true"
rinq "echo '--- sinks ---';     PULSE_SERVER='${PULSE_TCP}' pactl list short sinks 2>/dev/null || true"
rinq "echo '--- sources ---';   PULSE_SERVER='${PULSE_TCP}' pactl list short sources 2>/dev/null || true"

hdr "4) AUDIOBRIDGE FILES & SUPERVISOR PROGRAM DEFINITIONS"
rinq "echo '# AudioBridge dir listing'; ls -l ${BRIDGE_PATH} 2>/dev/null || true"
rinq "echo '# AudioBridge server.js (head)'; head -n 40 ${BRIDGE_PATH}/server.js 2>/dev/null || true"
rinq "echo '# Find supervisor program files referencing server.js'; grep -RIl '${BRIDGE_PATH}/server.js' /etc/supervisor/conf.d 2>/dev/null || true"
rinq "echo '# List all [program:*] stanzas'; grep -RIn '^\[program:.*\]' /etc/supervisor/conf.d 2>/dev/null || true"
rinq "echo '# Dump first 200 lines of each supervisor file in conf.d'; for f in /etc/supervisor/conf.d/*; do [ -f \"\$f\" ] || continue; echo '--- FILE:' \"\$f\"; sed -n '1,200p' \"\$f\"; echo; done"

hdr "5) SUPERVISOR STATUS (NO AUTH, THEN WITH DISCOVERED AUTH IF ANY)"
rinq "echo '# supervisorctl status (no auth)'; supervisorctl status 2>&1 || true"
rinq "echo '# Try supervisorctl with creds if configured'; \
user=\$(grep -RinE '^[[:space:]]*username=' /etc/supervisor/supervisord.conf /etc/supervisor/conf.d 2>/dev/null | tail -n1 | sed -E 's/.*username=([^[:space:]]+).*/\\1/'); \
pass=\$(grep -RinE '^[[:space:]]*password=' /etc/supervisor/supervisord.conf /etc/supervisor/conf.d 2>/dev/null | tail -n1 | sed -E 's/.*password=([^[:space:]]+).*/\\1/'); \
if [ -n \"\$user\" ] && [ -n \"\$pass\" ]; then echo \"using auth (\$user)\"; supervisorctl -u \"\$user\" -p \"\$pass\" status 2>&1 || true; else echo 'no credentials found'; fi"
rinq "echo '# Program names that look like AudioBridge'; supervisorctl status 2>/dev/null | awk '{print \$1}' | grep -i 'AudioBridge' || true"

hdr "6) AUDIOBRIDGE LOGS"
rinq "tail -n 200 /var/log/supervisor/audio-bridge.log 2>/dev/null || echo 'audio-bridge.log not found'"

hdr "7) PORT & HEALTH ENDPOINTS"
rinq "ss -ltnp | grep -E ':${BRIDGE_PORT}\\b' || echo 'Port ${BRIDGE_PORT} not listening'"
rinq "curl -fsS http://127.0.0.1:${BRIDGE_PORT}/health || echo 'GET /health failed with exit code: '$?"
rinq "curl -fsSI http://127.0.0.1:${BRIDGE_PORT}/audio-player.html 2>/dev/null | sed -n '1,10p' || true"

hdr "8) SUPERVISOR CONF.D DIRECTORY OVERVIEW"
rinq "ls -la /etc/supervisor/conf.d 2>/dev/null || true"

hdr "SUMMARY HINTS"
cat <<EOF
- Please send back the FULL output above as-is.
- Key things we’re looking for:
  * The exact supervisor program name that controls AudioBridge.
  * Whether supervisor requires credentials and what the configured username is.
  * Any nonstandard files under /etc/supervisor/conf.d (e.g., a 'supervisord.conf' living there).
  * PulseAudio over TCP is reachable and the virtual devices exist.
EOF

echo
echo "===== [$(ts)] DONE ====="

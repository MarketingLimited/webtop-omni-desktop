#!/usr/bin/env bash
# collect_end_to_end_audio_debug.sh
# Read-only end-to-end diagnostics for Webtop audio path.

set -Eeuo pipefail
IFS=$'\n\t'

CONTAINER="${1:-webtop-kde}"
DESKTOP_USER="${DESKTOP_USER:-devuser}"
PULSE_TCP="${PULSE_SERVER_OVERRIDE:-tcp:localhost:4713}"
BRIDGE_PORT="${BRIDGE_PORT:-8080}"
BRIDGE_PATH="${BRIDGE_PATH:-/opt/audio-bridge}"

ts(){ date -u +'%F %T UTC'; }
say(){ printf '\n===== [%s] %s =====\n' "$(ts)" "$*"; }
rin(){ docker exec -i "$CONTAINER" bash -lc "$*"; }

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1; then
  echo "Container '$CONTAINER' not running"; exit 1
fi

say "BASIC CONTAINER INFO"
docker ps --format 'table {{.ID}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}' | (grep -E "\s$CONTAINER$" || true)
echo "Params -> CONTAINER=$CONTAINER DESKTOP_USER=$DESKTOP_USER PULSE_TCP=$PULSE_TCP BRIDGE_PORT=$BRIDGE_PORT BRIDGE_PATH=$BRIDGE_PATH"

say "OS, TOOLS & USERS"
rin "set -e; head -n1 /etc/os-release; uname -a"
rin "command -v supervisorctl || true; command -v node || true; command -v pactl || true; command -v pulseaudio || true"
rin "getent passwd $DESKTOP_USER || true; id $DESKTOP_USER || true; groups $DESKTOP_USER || true"

say "PULSEAUDIO OVERVIEW (TCP EXPECTED)"
rin "PULSE_SERVER='$PULSE_TCP' pactl info 2>&1 | sed -n '1,20p' || true"
rin "PULSE_SERVER='$PULSE_TCP' pactl list short sinks   || true"
rin "PULSE_SERVER='$PULSE_TCP' pactl list short sources || true"
rin "PULSE_SERVER='$PULSE_TCP' pactl list short sink-inputs || true"

say "CHECK IF AUDIO IS FLOWING (synthetic test)"
rin "set -e; PULSE_SERVER='$PULSE_TCP' paplay /usr/share/sounds/alsa/Front_Center.wav >/dev/null 2>&1 & pid=\$!; sleep 1; \
      PULSE_SERVER='$PULSE_TCP' timeout 3 parec --device=virtual_speaker.monitor --raw /tmp/_cap.raw >/dev/null 2>&1 || true; \
      [ -f /tmp/_cap.raw ] && { BYTES=\$(wc -c </tmp/_cap.raw); echo 'Captured bytes from virtual_speaker.monitor: ' \$BYTES; rm -f /tmp/_cap.raw; } || echo 'No capture file created' ; \
      wait \$pid 2>/dev/null || true"

say "SINK-INPUTS DETAIL (which apps playing and where)"
rin "PULSE_SERVER='$PULSE_TCP' pactl list sink-inputs | egrep -i 'Sink Input|Driver:|Owner Module:|Mute:|Volume:|application.name|media.name|sink:|device.description' || true"

say "SUPERVISOR AUTH & STATUS"
rin "set -e; SUPUSER=\$(grep -RinE '^[[:space:]]*username=' /etc/supervisor 2>/dev/null | tail -n1 | sed -E 's/.*username=([^[:space:]]+).*/\1/'); \
          SUPPASS=\$(grep -RinE '^[[:space:]]*password=' /etc/supervisor 2>/dev/null | tail -n1 | sed -E 's/.*password=([^[:space:]]+).*/\1/'); \
          if [ -n \"\$SUPUSER\" ]&&[ -n \"\$SUPPASS\" ]; then echo using auth: \$SUPUSER; SUPCTL=\"supervisorctl -u \$SUPUSER -p \$SUPPASS\"; else SUPCTL=supervisorctl; fi; \
          \$SUPCTL status 2>&1 | sed -n '1,120p'"

say "SUPERVISOR CONFIG: [program:AudioBridge] BLOCK"
rin "CONF=/etc/supervisor/conf.d/supervisord.conf; \
    if [ -f \"\$CONF\" ]; then \
      echo \"-- File: \$CONF\"; \
      awk 'BEGIN{p=0} /^\[program:AudioBridge\]/{p=1} p{print} /^\[program:/ && NR>1 && p && !/^\[program:AudioBridge\]/{exit}' \"\$CONF\" | sed -n '1,60p'; \
      echo '-- END BLOCK'; \
      awk 'BEGIN{c=0} /^\[program:AudioBridge\]/{c++} END{print \"AudioBridge headers found:\", c}' \"\$CONF\"; \
    else echo 'No supervisord.conf under conf.d'; fi"

say "IS WRAPPER PRESENT & CONTENT HEAD"
rin "[ -x /usr/local/bin/audio-bridge-wrapper.sh ] && { head -n 40 /usr/local/bin/audio-bridge-wrapper.sh; } || echo 'wrapper missing'"

say "RUNNING NODE PROCESS (env, user, cmd)"
rin "pgrep -af 'node .*/server.js' || true"
rin "for p in \$(pgrep -f 'node .*/server.js' || true); do \
       echo '--- PID:' \$p; ps -o user,uid,cmd -p \$p; \
       tr '\\0' '\\n' </proc/\$p/environ | egrep -i '^(PULSE_SERVER|XDG_RUNTIME_DIR|HOME|USER|PORT)=' || true; done"

say "PORTS & HEALTH (inside container)"
rin "ss -ltnp | egrep ':$BRIDGE_PORT\\b' || true"
rin "curl -fsSI http://127.0.0.1:$BRIDGE_PORT/health || echo 'GET /health -> not found/404/connection error'"

say "BROWSER SIDE HINT (STATIC)"
cat <<'EOF'
If WebSocket frames are coming but you hear nothing:
- Make sure the page shows "Audio connected" and you clicked the button (user gesture).
- Check site sound is allowed in the browser tab (🔊 icon not muted).
- If multiple output devices exist on your machine, pick the right one in OS sound settings.
EOF

say "ACTIONABLE FINDINGS (auto-heuristics)"
rin "CONF=/etc/supervisor/conf.d/supervisord.conf; \
    bad_header_only=0; \
    if [ -f \"\$CONF\" ]; then \
      lines=\$(awk 'BEGIN{p=0} /^\[program:AudioBridge\]/{p=1; print; next} p && /^\[program:/{exit} p{print}' \"\$CONF\" | wc -l); \
      [ \"\$lines\" -le 1 ] && bad_header_only=1 || true; \
    fi; \
    echo \"AudioBridge block header-only? \$bad_header_only\"; \
    # Check node env
    p=\$(pgrep -f 'node .*/server.js' | head -n1 || true); \
    if [ -n \"\$p\" ]; then \
      envok=\$(tr '\\0' '\\n' </proc/\$p/environ | grep -E '^PULSE_SERVER=' | wc -l); \
      echo \"Node has PULSE_SERVER env? \$envok\"; \
    else echo 'Node PID not found'; fi; \
    # Is any sink-input NOT on virtual_speaker?
    PULSE_SERVER='$PULSE_TCP' pactl list short sink-inputs 2>/dev/null | awk '\$2!=\"virtual_speaker\"{print}' || true"

say "DONE"

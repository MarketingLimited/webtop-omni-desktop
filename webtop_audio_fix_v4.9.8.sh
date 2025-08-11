#!/usr/bin/env bash
# webtop_audio_fix_v4.9.8.sh
# Purpose: make AudioBridge reliably use PulseAudio over TCP (IPv4) and run as the desktop user.
# Idempotent and safe to re-run.

set -Eeuo pipefail
IFS=$'\n\t'

# ---------- Config ----------
CONTAINER="${1:-webtop-kde}"
DESKTOP_USER="${DESKTOP_USER:-devuser}"
# Force IPv4 to avoid ::1 issues from "localhost"
PULSE_TCP="${PULSE_SERVER_OVERRIDE:-tcp:127.0.0.1:4713}"
BRIDGE_PORT="${BRIDGE_PORT:-8080}"
BRIDGE_PATH="${BRIDGE_PATH:-/opt/audio-bridge}"
WAIT_MAX="${WAIT_MAX:-60}"
DO_TONE_TEST="${DO_TONE_TEST:-0}"   # set to 1 to auto-play a short test tone at the end

ts(){ date -u +'%F %T UTC'; }
log(){ printf '[%s] %s\n' "$(ts)" "$*"; }
die(){ printf '[%s] [error] %s\n' "$(ts)" "$*" >&2; exit 1; }
rin(){ docker exec -i "$CONTAINER" bash -lc "$*"; }
rin_stdin(){ docker exec -i "$CONTAINER" bash -s; }

# ---------- Pre-check ----------
log "checking container is running: $CONTAINER"
docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1 || die "container '$CONTAINER' is not running"

# ---------- 0) Persist Pulse client defaults (system+user), env, and disable PipeWire shim ----------
log "0) Persist Pulse client defaults and env; ensure PipeWire is not hijacking audio"
rin_stdin <<'EOS_HOST'
set -euo pipefail
DESK_USER="${DESKTOP_USER:-devuser}"
PULSE_TCP_INNER='__PULSE_TCP__'

# System-wide Pulse client defaults
mkdir -p /etc/pulse
if [ ! -f /etc/pulse/client.conf ] || ! grep -q "default-server" /etc/pulse/client.conf; then
  cat >/etc/pulse/client.conf <<EOF
autospawn = no
default-server = ${PULSE_TCP_INNER}
EOF
else
  sed -i "s|^default-server\\s*=.*|default-server = ${PULSE_TCP_INNER}|g" /etc/pulse/client.conf
  grep -q '^autospawn' /etc/pulse/client.conf || echo "autospawn = no" >> /etc/pulse/client.conf
fi

# User Pulse client defaults
mkdir -p "/home/${DESK_USER}/.config/pulse"
cat >"/home/${DESK_USER}/.config/pulse/client.conf" <<EOF
autospawn = no
default-server = ${PULSE_TCP_INNER}
EOF
chown -R "${DESK_USER}:${DESK_USER}" "/home/${DESK_USER}/.config/pulse"

# Login env for new sessions
grep -q PULSE_SERVER= /etc/environment || echo "PULSE_SERVER=${PULSE_TCP_INNER}" >> /etc/environment
cat >/etc/profile.d/99-pulse.sh <<EOF
export PULSE_SERVER=${PULSE_TCP_INNER}
export PULSE_LATENCY_MSEC=60
EOF
chmod +x /etc/profile.d/99-pulse.sh

# Ensure PipeWire is not taking over
pkill -u "${DESK_USER}" -f "pipewire|pipewire-pulse" 2>/dev/null || true
EOS_HOST
rin "sed -i 's#__PULSE_TCP__#${PULSE_TCP}#g' /etc/pulse/client.conf /etc/profile.d/99-pulse.sh /etc/environment /home/${DESKTOP_USER}/.config/pulse/client.conf || true"

# ---------- 1) Install/update pulse-ensure.sh (IPv4 TCP + virtual devices) ----------
log "1) Install/update pulse-ensure.sh (TCP=$PULSE_TCP)"
rin_stdin <<'EOS_HOST'
set -euo pipefail
cat >/usr/local/bin/pulse-ensure.sh <<'ENSURE'
#!/usr/bin/env bash
set -euo pipefail
DESK_USER="${1:-devuser}"
export PULSE_SERVER='__PULSE_TCP__'
say(){ printf '[pulse-ensure] %s\n' "$*"; }

# Start or verify per-user Pulse with TCP
if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
  say "tcp reachable"
else
  say "starting pulseaudio for ${DESK_USER} with TCP"
  sudo -u "${DESK_USER}" pulseaudio --kill 2>/dev/null || true
  sudo -u "${DESK_USER}" pulseaudio --daemonize=yes \
    -L 'module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1' \
    --exit-idle-time=-1 --log-target=journal || true
  for i in {1..30}; do pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1 && { say 'tcp is up'; break; }; sleep 1; done
fi

# Ensure virtual devices and defaults
say "ensuring virtual devices (no duplicates)"
sinks="$(pactl --server="${PULSE_SERVER}" list short sinks || true)"
sources="$(pactl --server="${PULSE_SERVER}" list short sources || true)"
echo "$sinks"   | cut -f2 | grep -qx virtual_speaker     || pactl --server="${PULSE_SERVER}" load-module module-null-sink     sink_name=virtual_speaker     sink_properties=device.description=Virtual_Marketing_Speaker >/dev/null
echo "$sinks"   | cut -f2 | grep -qx virtual_microphone  || pactl --server="${PULSE_SERVER}" load-module module-null-sink     sink_name=virtual_microphone  sink_properties=device.description=Virtual_Marketing_Microphone >/dev/null
echo "$sources" | cut -f2 | grep -qx virtual_mic_source  || pactl --server="${PULSE_SERVER}" load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor >/dev/null
pactl --server="${PULSE_SERVER}" set-default-sink   virtual_speaker    || true
pactl --server="${PULSE_SERVER}" set-default-source virtual_mic_source || true

# Convenience: unmute & set volume
pactl --server="${PULSE_SERVER}" set-sink-mute virtual_speaker 0 || true
pactl --server="${PULSE_SERVER}" set-sink-volume virtual_speaker 100% || true
ENSURE
chmod +x /usr/local/bin/pulse-ensure.sh
EOS_HOST
rin "sed -i 's#__PULSE_TCP__#${PULSE_TCP}#g' /usr/local/bin/pulse-ensure.sh"
rin "/usr/local/bin/pulse-ensure.sh ${DESKTOP_USER}"

# ---------- 2) Install/update audio-bridge-wrapper.sh (runs node as DESKTOP_USER) ----------
log "2) Install/update audio-bridge-wrapper.sh"
rin_stdin <<'EOS_HOST'
set -euo pipefail
cat >/usr/local/bin/audio-bridge-wrapper.sh <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
export PULSE_SERVER='__PULSE_TCP__'
export PULSE_LATENCY_MSEC='60'

echo "[wrapper] waiting for PulseAudio on ${PULSE_SERVER}"
for i in {1..90}; do
  if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    echo "[wrapper] pulse detected"; break
  fi
  (( i % 15 == 0 )) && echo "[wrapper] still waiting (${i}s)..."
  sleep 1
done

uid=""
if command -v getent >/dev/null 2>&1; then uid="$(getent passwd __DESK_USER__ | cut -d: -f3 || true)"; fi
[ -n "${uid}" ] && export XDG_RUNTIME_DIR="/run/user/${uid}"

echo "[wrapper] starting AudioBridge with PULSE_SERVER=${PULSE_SERVER} (as __DESK_USER__)"
exec su -s /bin/bash __DESK_USER__ -c "env PULSE_SERVER=\"${PULSE_SERVER}\" XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-}\" node __BRIDGE_PATH__/server.js"
WRAP
chmod +x /usr/local/bin/audio-bridge-wrapper.sh
EOS_HOST
rin "sed -i 's#__PULSE_TCP__#${PULSE_TCP}#g' /usr/local/bin/audio-bridge-wrapper.sh"
rin "sed -i 's#__DESK_USER__#${DESKTOP_USER//\//\\/}#g' /usr/local/bin/audio-bridge-wrapper.sh"
rin "sed -i 's#__BRIDGE_PATH__#${BRIDGE_PATH//\//\\/}#g' /usr/local/bin/audio-bridge-wrapper.sh"

# ---------- 3) Patch supervisor [program:AudioBridge] to use the wrapper ----------
log "3) Patch supervisor [program:AudioBridge] block to use wrapper"
rin "python3 - <<'PY'
import io,os,sys
conf='/etc/supervisor/conf.d/supervisord.conf'
with io.open(conf,'r',encoding='utf-8',errors='ignore') as f: L=f.readlines()
start=None; end=len(L)
for i,l in enumerate(L):
    if l.strip().lower()=='[program:audiobridge]':
        start=i; break
if start is None:
    sys.exit(0)
for j in range(start+1,len(L)):
    if L[j].strip().lower().startswith('[program:'):
        end=j; break
new_block=[
    '[program:AudioBridge]\\n',
    'command=/usr/local/bin/audio-bridge-wrapper.sh\\n',
    'priority=25\\n',
    'autostart=true\\n',
    'autorestart=true\\n',
    'stopsignal=TERM\\n',
    'user=root\\n',
    'startsecs=3\\n',
    'stdout_logfile=/var/log/supervisor/audio-bridge.log\\n',
    'stderr_logfile=/var/log/supervisor/audio-bridge.log\\n',
]
bak=conf+'.bak'
if not os.path.exists(bak):
    with io.open(bak,'w',encoding='utf-8') as f: f.writelines(L)
L = L[:start] + new_block + L[end:]
with io.open(conf,'w',encoding='utf-8') as f: f.writelines(L)
print('patched',conf)
PY"

# ---------- 4) Ensure static /health exists ----------
log "4) Ensure static /health file exists"
rin "[ -d '${BRIDGE_PATH}/public' ] && echo OK > '${BRIDGE_PATH}/public/health' || true"

# ---------- 5) Reread/update & restart AudioBridge via supervisorctl (handle auth) ----------
log "5) Reread & restart AudioBridge via supervisorctl"
SUP_USER="$(rin "grep -RinE '^[[:space:]]*username=' /etc/supervisor 2>/dev/null | tail -n1 | sed -E 's/.*username=([^[:space:]]+).*/\1/' || true")"
SUP_PASS="$(rin "grep -RinE '^[[:space:]]*password=' /etc/supervisor 2>/dev/null | tail -n1 | sed -E 's/.*password=([^[:space:]]+).*/\1/' || true")"
if [[ -n "$SUP_USER" && -n "$SUP_PASS" ]]; then
  SUPCTL="supervisorctl -u $SUP_USER -p $SUP_PASS"
  log "   using auth ($SUP_USER)"
else
  SUPCTL="supervisorctl"
fi
rin "$SUPCTL reread || true; $SUPCTL update || true; \
     $SUPCTL status | awk '{print \$1}' | grep -i 'AudioBridge' | while read -r ID; do [ -n \"\$ID\" ] && $SUPCTL restart \"\$ID\" || true; done; \
     $SUPCTL status | egrep -i 'AudioBridge|pulseaudio|KDE' || true"

# ---------- 6) Wait & verify ----------
log "6) Wait for Pulse TCP and AudioBridge health"
rin "for i in \$(seq 1 ${WAIT_MAX}); do pactl --server='${PULSE_TCP}' info >/dev/null 2>&1 && break; sleep 1; done; pactl --server='${PULSE_TCP}' info | sed -n '1,14p' || true"
rin "for i in \$(seq 1 ${WAIT_MAX}); do curl -fsS 'http://127.0.0.1:${BRIDGE_PORT}/health' >/dev/null 2>&1 && { echo 'health OK'; break; }; sleep 1; done || true"
rin "ss -ltnp | grep -E ':${BRIDGE_PORT}\\b' || true"

# ---------- 7) Diagnostics: move streams, probe monitor, optional tone ----------
log "7) Diagnostics: move active streams to virtual_speaker and probe monitor"
rin "export PULSE_SERVER='${PULSE_TCP}'; \
    pactl list short sink-inputs | awk '{print \$1}' | xargs -r -I{} pactl move-sink-input {} virtual_speaker; \
    pactl set-sink-mute virtual_speaker 0; pactl set-sink-volume virtual_speaker 100%"

rin "export PULSE_SERVER='${PULSE_TCP}'; TMP=/tmp/_mon.raw; rm -f \"\$TMP\"; \
    timeout 3 parecord --server=\$PULSE_SERVER --device=virtual_speaker.monitor --format=s16le --rate=44100 --channels=2 --raw \"\$TMP\" || true; \
    if [ -f \"\$TMP\" ]; then BYTES=\$(wc -c <\"\$TMP\"); echo 'captured-bytes=' \$BYTES; rm -f \"\$TMP\"; else echo 'capture-file-missing'; fi"

if [[ "$DO_TONE_TEST" == "1" ]]; then
  log "playing short test tone via paplay"
  rin "export PULSE_SERVER='${PULSE_TCP}'; paplay /usr/share/sounds/alsa/Front_Center.wav || true; sleep 1; pactl list short sink-inputs || true"
fi

log "DONE. Open the noVNC page and click the audio Connect/Play button (if needed)."

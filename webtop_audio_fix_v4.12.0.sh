#!/usr/bin/env bash
# webtop_audio_fix_v4.12.0.sh
# Purpose: Cleaner desktop audio over WebSocket by:
# - Forcing PulseAudio over IPv4 TCP and running AudioBridge as the desktop user
# - Capturing directly from virtual_speaker.monitor (no AEC by default)
# - Larger buffers (fragments/latency) + null-sink latency_msec to smooth jitter
# - Disabling suspend-on-idle and aggressive resampling artifacts
# Idempotent and safe to re-run.

set -Eeuo pipefail
IFS=$'\n\t'

# ---------- Config ----------
CONTAINER="${1:-webtop-kde}"
DESKTOP_USER="${DESKTOP_USER:-devuser}"

# Force IPv4 to avoid ::1 issues
PULSE_TCP="${PULSE_SERVER_OVERRIDE:-tcp:127.0.0.1:4713}"

# Unified audio spec (keep consistent everywhere)
PULSE_RATE="${PULSE_RATE:-48000}"
PULSE_FORMAT="${PULSE_FORMAT:-s16le}"
PULSE_CHANNELS="${PULSE_CHANNELS:-2}"

# Buffers/latency (raise if crackle persists)
PULSE_LATENCY_MSEC_ENV="${PULSE_LATENCY_MSEC_ENV:-180}"
NULL_LATENCY_MSEC="${NULL_LATENCY_MSEC:-200}"

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

# ---------- 0) Persist Pulse client+daemon configs, env, and stop PipeWire ----------
log "0) Persist Pulse configs and env; ensure PipeWire is not hijacking audio"
rin_stdin <<'EOS_HOST'
set -euo pipefail
DESK_USER="${DESKTOP_USER:-devuser}"
PTCP='__PULSE_TCP__'
PRATE='__PULSE_RATE__'
PFORM='__PULSE_FORMAT__'
PCH='__PULSE_CHANNELS__'
PLAT='__PULSE_LATENCY__'

mkdir -p /etc/pulse "/home/${DESK_USER}/.config/pulse"

# /etc/pulse/client.conf
cat >/etc/pulse/client.conf <<EOF
autospawn = no
default-server = ${PTCP}
EOF

# User client.conf
cat >"/home/${DESK_USER}/.config/pulse/client.conf" <<EOF
autospawn = no
default-server = ${PTCP}
EOF
chown -R "${DESK_USER}:${DESK_USER}" "/home/${DESK_USER}/.config/pulse"

# /etc/pulse/daemon.conf — tuned for clean, stable timing (bigger buffers)
cat >/etc/pulse/daemon.conf <<EOF
default-sample-format = ${PFORM}
default-sample-rate = ${PRATE}
alternate-sample-rate = 44100
avoid-resampling = yes
resample-method = soxr-vhq
realtime-scheduling = yes
high-priority = yes
nice-level = -11
rlimit-rtprio = 9
rlimit-rttime = 200000
flat-volumes = no
disable-remixing = yes
enable-lfe-remixing = no
remixing-produce-lfe = no
remixing-consume-lfe = no
enable-deferred-volume = no
default-fragments = 8
default-fragment-size-msec = 40
exit-idle-time = -1
# log-level kept default; set to notice if needed
EOF

# Mirror daemon.conf into user dir
cp -f /etc/pulse/daemon.conf "/home/${DESK_USER}/.config/pulse/daemon.conf" || true
chown "${DESK_USER}:${DESK_USER}" "/home/${DESK_USER}/.config/pulse/daemon.conf" || true

# Login env
grep -q PULSE_SERVER= /etc/environment || echo "PULSE_SERVER=${PTCP}" >> /etc/environment
cat >/etc/profile.d/99-pulse.sh <<EOF
export PULSE_SERVER=${PTCP}
export PULSE_LATENCY_MSEC=${PLAT}
EOF
chmod +x /etc/profile.d/99-pulse.sh

# Stop PipeWire if present
pkill -u "${DESK_USER}" -f "pipewire|pipewire-pulse" 2>/dev/null || true
EOS_HOST
rin "sed -i -e 's#__PULSE_TCP__#${PULSE_TCP}#g' \
            -e 's#__PULSE_RATE__#${PULSE_RATE}#g' \
            -e 's#__PULSE_FORMAT__#${PULSE_FORMAT}#g' \
            -e 's#__PULSE_CHANNELS__#${PULSE_CHANNELS}#g' \
            -e 's#__PULSE_LATENCY__#${PULSE_LATENCY_MSEC_ENV}#g' \
            /etc/pulse/client.conf /etc/pulse/daemon.conf /etc/profile.d/99-pulse.sh /etc/environment /home/${DESKTOP_USER}/.config/pulse/client.conf /home/${DESKTOP_USER}/.config/pulse/daemon.conf || true"

# ---------- 1) Install/update pulse-ensure.sh (TCP + virtual devices, clean capture path) ----------
log "1) Install/update pulse-ensure.sh (TCP=$PULSE_TCP, ${PULSE_RATE}Hz ${PULSE_FORMAT} ${PULSE_CHANNELS}ch)"
rin_stdin <<'EOS_HOST'
set -euo pipefail
cat >/usr/local/bin/pulse-ensure.sh <<'ENSURE'
#!/usr/bin/env bash
set -euo pipefail
DESK_USER="${1:-devuser}"
export PULSE_SERVER='__PULSE_TCP__'
PRATE='__PULSE_RATE__'
PFORM='__PULSE_FORMAT__'
PCH='__PULSE_CHANNELS__'
NLAT='__NULL_LATENCY__'
say(){ printf '[pulse-ensure] %s\n' "$*"; }

# Fresh start for per-user Pulse with TCP
sudo -u "${DESK_USER}" pulseaudio --kill 2>/dev/null || true
if ! pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
  say "starting pulseaudio for ${DESK_USER} (TCP)"
  sudo -u "${DESK_USER}" pulseaudio --daemonize=yes \
    -L 'module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1' \
    --exit-idle-time=-1 --log-target=journal || true
  for i in {1..60}; do pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1 && { say 'tcp is up'; break; }; sleep 1; done
else
  say "tcp reachable"
fi

# Remove modules that can degrade music/program audio quality
mods="$(pactl --server="${PULSE_SERVER}" list short modules || true)"
echo "$mods" | awk '/module-suspend-on-idle/ {print $1}' | xargs -r -I{} pactl --server="${PULSE_SERVER}" unload-module {}
echo "$mods" | awk '/module-echo-cancel/ {print $1}'     | xargs -r -I{} pactl --server="${PULSE_SERVER}" unload-module {}

# Ensure a single virtual_speaker (null-sink) with explicit spec and latency
say "ensuring virtual_speaker (${PRATE}Hz ${PFORM} ${PCH}ch, latency_msec=${NLAT})"
sinks="$(pactl --server="${PULSE_SERVER}" list short sinks || true)"
if ! echo "$sinks" | cut -f2 | grep -qx virtual_speaker; then
  pactl --server="${PULSE_SERVER}" load-module module-null-sink \
    sink_name=virtual_speaker rate="${PRATE}" channels="${PCH}" format="${PFORM}" latency_msec="${NLAT}" \
    sink_properties=device.description=Virtual_Speaker >/dev/null
fi

# Default sink -> virtual_speaker
pactl --server="${PULSE_SERVER}" set-default-sink virtual_speaker || true

# Default source -> monitor of virtual_speaker (cleanest capture path)
# (No extra virtual_mic or echo-cancel in the chain)
if pactl --server="${PULSE_SERVER}" list short sources | awk '{print $2}' | grep -qx virtual_speaker.monitor; then
  pactl --server="${PULSE_SERVER}" set-default-source virtual_speaker.monitor || true
fi

# Unmute & conservative volume to avoid clipping at the source
pactl --server="${PULSE_SERVER}" set-sink-mute virtual_speaker 0 || true
pactl --server="${PULSE_SERVER}" set-sink-volume virtual_speaker 70% || true
ENSURE
chmod +x /usr/local/bin/pulse-ensure.sh
EOS_HOST
rin "sed -i -e 's#__PULSE_TCP__#${PULSE_TCP}#g' \
            -e 's#__PULSE_RATE__#${PULSE_RATE}#g' \
            -e 's#__PULSE_FORMAT__#${PULSE_FORMAT}#g' \
            -e 's#__PULSE_CHANNELS__#${PULSE_CHANNELS}#g' \
            -e 's#__NULL_LATENCY__#${NULL_LATENCY_MSEC}#g' \
            /usr/local/bin/pulse-ensure.sh"
rin "/usr/local/bin/pulse-ensure.sh ${DESKTOP_USER}"

# ---------- 2) Install/update audio-bridge-wrapper.sh ----------
log "2) Install/update audio-bridge-wrapper.sh"
rin_stdin <<'EOS_HOST'
set -euo pipefail
cat >/usr/local/bin/audio-bridge-wrapper.sh <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
export PULSE_SERVER='__PULSE_TCP__'
export PULSE_LATENCY_MSEC='__PULSE_LATENCY__'

echo "[wrapper] waiting for PulseAudio on ${PULSE_SERVER}"
for i in {1..120}; do
  if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    echo "[wrapper] pulse detected"; break
  fi
  (( i % 20 == 0 )) && echo "[wrapper] still waiting (${i}s)..."
  sleep 1
done

uid=""
if command -v getent >/dev/null 2>&1; then uid="$(getent passwd __DESK_USER__ | cut -d: -f3 || true)"; fi
[ -n "${uid}" ] && export XDG_RUNTIME_DIR="/run/user/${uid}"

echo "[wrapper] starting AudioBridge with PULSE_SERVER=${PULSE_SERVER} (as __DESK_USER__)"
exec su -s /bin/bash __DESK_USER__ -c "exec nice -n -5 env PULSE_SERVER=\"${PULSE_SERVER}\" PULSE_LATENCY_MSEC=\"${PULSE_LATENCY_MSEC}\" XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-}\" node __BRIDGE_PATH__/server.js"
WRAP
chmod +x /usr/local/bin/audio-bridge-wrapper.sh
EOS_HOST
rin "sed -i -e 's#__PULSE_TCP__#${PULSE_TCP}#g' \
            -e 's#__PULSE_LATENCY__#${PULSE_LATENCY_MSEC_ENV}#g' \
            /usr/local/bin/audio-bridge-wrapper.sh"
rin "sed -i 's#__DESK_USER__#${DESKTOP_USER//\//\\/}#g' /usr/local/bin/audio-bridge-wrapper.sh"
rin "sed -i 's#__BRIDGE_PATH__#${BRIDGE_PATH//\//\\/}#g' /usr/local/bin/audio-bridge-wrapper.sh"

# ---------- 3) Patch supervisor [program:AudioBridge] ----------
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

# ---------- 4) Ensure static /health ----------
log "4) Ensure static /health file exists"
rin "[ -d '${BRIDGE_PATH}/public' ] && echo OK > '${BRIDGE_PATH}/public/health' || true"

# ---------- 5) Restart via supervisorctl ----------
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
rin "for i in \$(seq 1 ${WAIT_MAX}); do pactl --server='${PULSE_TCP}' info >/dev/null 2>&1 && break; sleep 1; done; pactl --server='${PULSE_TCP}' info | sed -n '1,18p' || true"
rin "for i in \$(seq 1 ${WAIT_MAX}); do curl -fsS 'http://127.0.0.1:${BRIDGE_PORT}/health' >/dev/null 2>&1 && { echo 'health OK'; break; }; sleep 1; done || true"
rin "ss -ltnp | grep -E ':${BRIDGE_PORT}\\b' || true"

# ---------- 7) Diagnostics ----------
log "7) Move active streams to virtual_speaker and probe monitor"
rin "export PULSE_SERVER='${PULSE_TCP}'; \
    pactl list short sink-inputs | awk '{print \$1}' | xargs -r -I{} pactl move-sink-input {} virtual_speaker; \
    pactl set-sink-mute virtual_speaker 0; pactl set-sink-volume virtual_speaker 70%"

rin "export PULSE_SERVER='${PULSE_TCP}'; TMP=/tmp/_mon.raw; rm -f \"\$TMP\"; \
    timeout 3 parecord --server=\$PULSE_SERVER --device=virtual_speaker.monitor --format=${PULSE_FORMAT} --rate=${PULSE_RATE} --channels=${PULSE_CHANNELS} --raw \"\$TMP\" || true; \
    if [ -f \"\$TMP\" ]; then BYTES=\$(wc -c <\"\$TMP\"); echo 'captured-bytes=' \$BYTES; rm -f \"\$TMP\"; else echo 'capture-file-missing'; fi"

if [[ "$DO_TONE_TEST" == "1" ]]; then
  log "playing short test tone via paplay"
  rin "export PULSE_SERVER='${PULSE_TCP}'; paplay /usr/share/sounds/alsa/Front_Center.wav || true; sleep 1; pactl list short sink-inputs || true"
fi

log "DONE. Open the noVNC page and click the audio Connect/Play button if needed."

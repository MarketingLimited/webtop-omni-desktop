#!/usr/bin/env bash
# Purpose: converge Pulse topology without restarting Pulse.
# - Use the desktop user's unix socket (preferred)
# - Ensure exactly one virtual_speaker @ 48k s16le 2ch with latency_msec
# - Set defaults (sink=virtual_speaker, source=virtual_speaker.monitor)
# - Remove duplicate *.2 sinks safely
set -Eeuo pipefail
DESK_USER="${1:-devuser}"
TARGET_RATE="${PULSE_RATE:-48000}"
TARGET_FORMAT="${PULSE_FORMAT:-s16le}"
TARGET_CHANNELS="${PULSE_CHANNELS:-2}"
TARGET_NULL_LATENCY_MS="${NULL_LATENCY_MSEC:-200}"

uid="$(getent passwd "$DESK_USER" | cut -d: -f3)"
[ -n "${uid}" ] || { echo "[pulse-ensure] unknown user ${DESK_USER}"; exit 0; }
export XDG_RUNTIME_DIR="/run/user/${uid}"
export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"

# Wait for PulseAudio to become available for the target user
for i in {1..60}; do
  if su -s /bin/bash "$DESK_USER" -c "pactl info" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

su -s /bin/bash "$DESK_USER" -c "pactl info" >/dev/null 2>&1 || {
  echo "[pulse-ensure] Pulse not ready for ${DESK_USER}"; exit 0; }

# unload modules that degrade quality (non-fatal)
su -s /bin/bash "$DESK_USER" -c \
  "pactl list short modules | awk '/module-suspend-on-idle|module-echo-cancel/ {print \$1}' | xargs -r -I{} pactl unload-module {}" || true

# remove duplicate sinks named *.N for known bases
for base in virtual_speaker virtual_microphone fallback_speaker fallback_microphone; do
  su -s /bin/bash "$DESK_USER" -c \
    "pactl list short sinks | awk -v p=\"^${base}\\.[0-9]+$\" '\$2 ~ p {print \$2}'" \
  | while read -r dup; do
      mod="$(su -s /bin/bash "$DESK_USER" -c \
        "pactl list sinks | awk -v n=\"$dup\" 'BEGIN{hit=0} /^Name: /{hit=(\$2==n)} hit&&/Owner Module:/ {print \$3; exit}'" || true)"
      [ -n "$mod" ] && su -s /bin/bash "$DESK_USER" -c "pactl unload-module $mod" || true
    done
done

# (re)create virtual_speaker if missing or wrong spec
need_vs=0
if su -s /bin/bash "$DESK_USER" -c "pactl list short sinks | awk '\$2==\"virtual_speaker\"{found=1} END{exit(found?0:1)}'"; then
  spec="$(su -s /bin/bash "$DESK_USER" -c \
    "pactl list sinks | awk 'BEGIN{hit=0} /^Name: /{hit=(\$2==\"virtual_speaker\")} hit&&/Sample Specification:/ {for(i=3;i<=NF;i++) printf (i==3?\"\":\" \") \$i; print \"\"; exit}'" || true)"
  echo "$spec" | grep -qiE "^${TARGET_FORMAT}[[:space:]]+${TARGET_CHANNELS}ch[[:space:]]+${TARGET_RATE}Hz$" || need_vs=1
else
  need_vs=1
fi

if [ "$need_vs" -eq 1 ]; then
  # remove old one if present
  mod="$(su -s /bin/bash "$DESK_USER" -c \
    "pactl list sinks | awk 'BEGIN{hit=0;mod=\"\"} /^Name: /{hit=(\$2==\"virtual_speaker\")} hit&&/Owner Module:/ {print \$3; exit}'" || true)"
  [ -n "$mod" ] && su -s /bin/bash "$DESK_USER" -c "pactl unload-module $mod" || true

  su -s /bin/bash "$DESK_USER" -c "pactl load-module module-null-sink \
    sink_name=virtual_speaker rate=${TARGET_RATE} channels=${TARGET_CHANNELS} format=${TARGET_FORMAT} latency_msec=${TARGET_NULL_LATENCY_MS} \
    sink_properties=device.description=Virtual_Speaker >/dev/null"
fi

# defaults + sane volume
su -s /bin/bash "$DESK_USER" -c "pactl set-default-sink virtual_speaker" || true
if su -s /bin/bash "$DESK_USER" -c "pactl list short sources | awk '\$2==\"virtual_speaker.monitor\"{exit 0} END{exit 1}'"; then
  su -s /bin/bash "$DESK_USER" -c "pactl set-default-source virtual_speaker.monitor" || true
fi
su -s /bin/bash "$DESK_USER" -c "pactl set-sink-mute virtual_speaker 0" || true
su -s /bin/bash "$DESK_USER" -c "pactl set-sink-volume virtual_speaker 70%" || true

#!/usr/bin/env bash
# Per-user desktop egress + kill-switch.
#
# Makes the desktop's PUBLIC IP the user's chosen identity, never the host/server
# datacenter IP (which gets personal Google/Meta logins suspended). Invoked by the
# entrypoint as root, BEFORE the desktop is usable, only when EGRESS_MODE != off.
# Requires NET_ADMIN + /dev/net/tun (Rabeeb adds these only for tunnel modes).
#
# Config comes from /run/egress/config (a tmpfs file Rabeeb mounts, KEY=VALUE
# lines) so secrets never appear in `docker inspect`. Env vars are the fallback.
#
# Modes:
#   own_device        — Tailscale exit node = the user's own PC (DEFAULT, free).
#   byo_proxy         — user-supplied HTTP/SOCKS proxy (redsocks transparent).
#   residential_proxy — Rabeeb-assigned sticky proxy (same engine as byo).
#
# Kill-switch: OUTPUT defaults to DROP; only the tunnel/proxy path + loopback +
# established (inbound noVNC/audio/control) are allowed. If the tunnel dies the
# desktop simply loses internet — it NEVER falls back to the host IP.
set -u
CONF=/run/egress/config
[ -r "$CONF" ] && . "$CONF"
MODE="${EGRESS_MODE:-off}"
log(){ echo "[egress] $*"; }

if [ "$MODE" = "off" ] || [ -z "$MODE" ]; then
    log "mode=off — no egress tunnel, using host network"
    exit 0
fi

# Verify the tun device is present for tunnel modes.
if [ "$MODE" = "own_device" ] && [ ! -e /dev/net/tun ]; then
    log "ERROR: /dev/net/tun missing — cannot start tunnel; leaving internet BLOCKED (no host-IP leak)"
fi

# ---- kill-switch base: drop OUTPUT except loopback + established ----
killswitch_base(){
    iptables -F OUTPUT 2>/dev/null || true
    iptables -P OUTPUT DROP
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
}

case "$MODE" in
  own_device)
    : "${EGRESS_TS_AUTHKEY:?own_device needs EGRESS_TS_AUTHKEY}"
    : "${EGRESS_TS_EXIT_NODE:?own_device needs EGRESS_TS_EXIT_NODE}"
    mkdir -p /var/run/tailscale /var/lib/tailscale
    log "starting tailscaled…"
    tailscaled --tun=tailscale0 \
        --state=/var/lib/tailscale/tailscaled.state \
        --socket=/var/run/tailscale/tailscaled.sock \
        >/var/log/tailscaled.log 2>&1 &
    for i in $(seq 1 15); do [ -S /var/run/tailscale/tailscaled.sock ] && break; sleep 1; done
    log "tailscale up (exit-node=${EGRESS_TS_EXIT_NODE})…"
    tailscale up \
        --authkey="${EGRESS_TS_AUTHKEY}" \
        --exit-node="${EGRESS_TS_EXIT_NODE}" \
        --exit-node-allow-lan-access=false \
        --accept-dns=true \
        --hostname="${EGRESS_TS_HOSTNAME:-rabeeb-desktop}" \
        --reset || log "WARN: tailscale up returned non-zero"
    # Kill-switch: allow only the tailscale iface + tailscaled's own control-plane
    # traffic (DERP/coordination) so the exit-node tunnel can establish.
    killswitch_base
    iptables -A OUTPUT -o tailscale0 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 41641 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 3478  -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 443   -j ACCEPT
    log "own_device egress engaged."
    ;;

  byo_proxy|residential_proxy)
    : "${EGRESS_PROXY_HOST:?proxy mode needs EGRESS_PROXY_HOST}"
    : "${EGRESS_PROXY_PORT:?proxy mode needs EGRESS_PROXY_PORT}"
    PTYPE="${EGRESS_PROXY_TYPE:-http-connect}"   # http-connect | socks5 | socks4
    {
      echo "base { log_debug=off; log_info=on; daemon=on; redirector=iptables; }"
      echo "redsocks {"
      echo "  local_ip=127.0.0.1; local_port=12345;"
      echo "  ip=${EGRESS_PROXY_HOST}; port=${EGRESS_PROXY_PORT}; type=${PTYPE};"
      [ -n "${EGRESS_PROXY_USER:-}" ] && echo "  login=\"${EGRESS_PROXY_USER}\";"
      [ -n "${EGRESS_PROXY_PASS:-}" ] && echo "  password=\"${EGRESS_PROXY_PASS}\";"
      echo "}"
    } > /etc/redsocks.conf
    log "starting redsocks → ${EGRESS_PROXY_HOST}:${EGRESS_PROXY_PORT} (${PTYPE})…"
    redsocks -c /etc/redsocks.conf || log "WARN: redsocks failed to start"

    # Force DNS over TCP so it is redirected through the proxy too (no UDP leak).
    printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\noptions use-vc\n' > /etc/resolv.conf

    killswitch_base
    # Allow reaching the proxy endpoint itself, and redsocks' own upstream sockets.
    iptables -A OUTPUT -p tcp -d "${EGRESS_PROXY_HOST}" --dport "${EGRESS_PROXY_PORT}" -j ACCEPT
    # Transparent redirect of all remaining TCP into redsocks (skip private nets).
    iptables -t nat -N REDSOCKS 2>/dev/null || iptables -t nat -F REDSOCKS
    for net in 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16; do
        iptables -t nat -A REDSOCKS -d "$net" -j RETURN
    done
    iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
    iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
    # Redirected (redsocks-owned) traffic reaches the proxy via ESTABLISHED rule.
    iptables -A OUTPUT -p tcp --dport 12345 -d 127.0.0.1 -j ACCEPT
    log "${MODE} egress engaged (all TCP + TCP-DNS via proxy)."
    ;;

  *)
    log "unknown EGRESS_MODE='$MODE' — leaving internet BLOCKED (fail-closed, no host-IP leak)"
    killswitch_base
    exit 0
    ;;
esac

# Best-effort: log the resulting public IP (never fatal).
( sleep 6; ip=$(curl -fsS --max-time 12 https://api.ipify.org 2>/dev/null || echo "?"); \
  echo "[egress] public IP now: ${ip} (mode=${MODE})" ) &
exit 0

#!/usr/bin/env bash
# Per-user desktop egress + self-healing kill-switch.
#
# Makes the desktop's PUBLIC IP the user's chosen identity, never the host/server
# datacenter IP (which gets personal Google/Meta logins suspended). Run by
# supervisord LATE (after the desktop's own network setup) and kept alive, because
# Docker/desktop network init flushes iptables during boot — a one-shot apply gets
# wiped and the desktop would fall back to the host IP. This process brings the
# transport up once, applies the firewall, then RE-APPLIES it whenever it drifts.
#
# Config from /run/egress/config (a 0600 file Rabeeb bind-mounts, KEY=VALUE) so
# secrets never appear in `docker inspect`. Requires NET_ADMIN + /dev/net/tun.
#
# Modes: own_device (Tailscale exit node = user's PC, DEFAULT), byo_proxy /
# residential_proxy (redsocks transparent). Kill-switch = OUTPUT default-DROP;
# only the tunnel/proxy path + loopback + established (inbound noVNC/audio/control)
# are allowed. Tunnel down → no internet, NEVER the host IP.
set -u
CONF=/run/egress/config
[ -r "$CONF" ] && . "$CONF"
MODE="${EGRESS_MODE:-off}"
# --apply-only: called from the entrypoint at t0 to raise the kill-switch BEFORE any
# desktop service/app can run — EgressGuard (supervisord) may only start tens of
# seconds into boot, which would otherwise leave a boot-time leak window.
APPLY_ONLY=false
[ "${1:-}" = "--apply-only" ] && APPLY_ONLY=true
log(){ echo "[egress] $*"; }

if [ "$MODE" = "off" ] || [ -z "$MODE" ]; then
    $APPLY_ONLY && exit 0
    log "mode=off — no egress tunnel, using host network"
    exec sleep infinity
fi

# ---------- transport (brought up once) ----------
bring_up_transport() {
    case "$MODE" in
      own_device)
        : "${EGRESS_TS_AUTHKEY:?own_device needs EGRESS_TS_AUTHKEY}"
        : "${EGRESS_TS_EXIT_NODE:?own_device needs EGRESS_TS_EXIT_NODE}"
        mkdir -p /var/run/tailscale /var/lib/tailscale
        if ! pgrep -x tailscaled >/dev/null 2>&1; then
            log "starting tailscaled…"
            tailscaled --tun=tailscale0 \
                --state=/var/lib/tailscale/tailscaled.state \
                --socket=/var/run/tailscale/tailscaled.sock \
                >/var/log/tailscaled.log 2>&1 &
            for _ in $(seq 1 15); do [ -S /var/run/tailscale/tailscaled.sock ] && break; sleep 1; done
        fi
        # 1) Authenticate WITHOUT the exit node — at boot the exit-node peer may not
        #    be synced yet, and `up --exit-node=<unknown>` fails the whole command
        #    (leaves the node logged out). accept-dns=false: we manage resolv.conf
        #    ourselves (MagicDNS only resolves tailnet names unless the tailnet has
        #    a global nameserver; a public resolver routed through the exit node is
        #    simpler and reliable).
        if ! tailscale status 2>/dev/null | grep -q "^100\."; then
            log "tailscale up (auth)…"
            tailscale up --authkey="${EGRESS_TS_AUTHKEY}" --accept-dns=false \
                --hostname="${EGRESS_TS_HOSTNAME:-rabeeb-desktop}" --reset \
                || log "WARN: tailscale up returned non-zero"
        fi
        # 2) Wait for the exit-node peer to become reachable, then select it.
        for _ in $(seq 1 20); do
            tailscale status 2>/dev/null | grep -q "${EGRESS_TS_EXIT_NODE}" && break
            sleep 2
        done
        log "selecting exit node ${EGRESS_TS_EXIT_NODE}…"
        tailscale set --exit-node="${EGRESS_TS_EXIT_NODE}" \
            --exit-node-allow-lan-access=false --accept-dns=false \
            || log "WARN: tailscale set --exit-node returned non-zero"
        # 3) DNS via a public resolver — routed through the exit node by the default
        #    route, so queries exit at the user's IP too (no MagicDNS dependency).
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
        ;;
      byo_proxy|residential_proxy)
        : "${EGRESS_PROXY_HOST:?proxy mode needs EGRESS_PROXY_HOST}"
        : "${EGRESS_PROXY_PORT:?proxy mode needs EGRESS_PROXY_PORT}"
        local ptype="${EGRESS_PROXY_TYPE:-http-connect}"
        {
          echo "base { log_debug=off; log_info=on; daemon=on; redirector=iptables; }"
          echo "redsocks {"
          echo "  local_ip=127.0.0.1; local_port=12345;"
          echo "  ip=${EGRESS_PROXY_HOST}; port=${EGRESS_PROXY_PORT}; type=${ptype};"
          [ -n "${EGRESS_PROXY_USER:-}" ] && echo "  login=\"${EGRESS_PROXY_USER}\";"
          [ -n "${EGRESS_PROXY_PASS:-}" ] && echo "  password=\"${EGRESS_PROXY_PASS}\";"
          echo "}"
        } > /etc/redsocks.conf
        # Force DNS over TCP so it is redirected through the proxy too (no UDP leak).
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\noptions use-vc\n' > /etc/resolv.conf
        if ! ss -tlnH 2>/dev/null | grep -q '127.0.0.1:12345'; then
            log "starting redsocks → ${EGRESS_PROXY_HOST}:${EGRESS_PROXY_PORT} (${ptype})…"
            redsocks -c /etc/redsocks.conf || log "WARN: redsocks failed to start"
        fi
        ;;
    esac
}

# ---------- firewall / kill-switch (idempotent; re-applied on drift) ----------
apply_firewall() {
    iptables -F OUTPUT 2>/dev/null || true
    iptables -P OUTPUT DROP
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    case "$MODE" in
      own_device)
        # User traffic exits via tailscale0 (→ exit node). For the physical iface
        # allow ONLY Tailscale's own underlay: tailscaled sets fwmark 0x80000 on its
        # WireGuard/DERP/control sockets. This is the documented Tailscale
        # kill-switch — everything else on eth0 is dropped, so apps CANNOT leak via
        # the host IP when the tunnel is down (a broad "allow tcp 443" would let any
        # HTTPS out directly — the leak found in live testing).
        iptables -A OUTPUT -o tailscale0 -j ACCEPT
        iptables -A OUTPUT -m mark --mark 0x80000/0xff0000 -j ACCEPT
        ;;
      byo_proxy|residential_proxy)
        iptables -A OUTPUT -p tcp -d "${EGRESS_PROXY_HOST}" --dport "${EGRESS_PROXY_PORT}" -j ACCEPT
        iptables -A OUTPUT -p tcp --dport 12345 -d 127.0.0.1 -j ACCEPT
        iptables -t nat -N REDSOCKS 2>/dev/null || iptables -t nat -F REDSOCKS
        local net
        for net in 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16; do
            iptables -t nat -A REDSOCKS -d "$net" -j RETURN
        done
        iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
        # (Re)attach the nat OUTPUT jump only once.
        iptables -t nat -C OUTPUT -p tcp -j REDSOCKS 2>/dev/null \
            || iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
        ;;
    esac
}

firewall_intact() {
    # Cheap drift check: OUTPUT policy must still be DROP.
    iptables -S OUTPUT 2>/dev/null | grep -q -- '-P OUTPUT DROP'
}

# Is the tunnel actually carrying traffic yet?
transport_connected() {
    case "$MODE" in
      own_device) tailscale status 2>/dev/null | grep -q "exit node" ;;
      byo_proxy|residential_proxy) ss -tlnH 2>/dev/null | grep -q '127.0.0.1:12345' ;;
      *) return 1 ;;
    esac
}

# Entrypoint boot call: raise the kill-switch at t0 and return, so the desktop is
# fail-closed before any service starts. EgressGuard (below) then maintains it +
# brings the tunnel up.
if $APPLY_ONLY; then
    apply_firewall
    log "${MODE} kill-switch pre-applied at boot"
    exit 0
fi

# 1) Kill-switch FIRST — fail closed before ANYTHING can leak, and before the slow
#    transport bring-up. Applying it only after bring-up left a startup window where
#    the desktop reached the internet via the host IP (found in live testing).
apply_firewall
log "${MODE} kill-switch engaged (fail-closed); connecting transport…"

# 2) Bring the transport up in the BACKGROUND, retried until connected, so its
#    tens-of-seconds waits never block the firewall heal loop. tailscaled is a
#    daemon that then maintains/reconnects the tunnel itself.
(
    for _ in $(seq 1 30); do
        bring_up_transport
        transport_connected && { log "${MODE} transport connected"; break; }
        sleep 8
    done
    sleep 6; ip=$(curl -fsS --max-time 12 https://api.ipify.org 2>/dev/null || echo "?")
    echo "[egress] public IP now: ${ip} (mode=${MODE})"
) &

# 3) Self-heal: re-apply the firewall the instant the desktop's network stack
#    flushes it. Firewall only (fast) — the transport is handled above.
while true; do
    sleep 5
    if ! firewall_intact; then
        log "kill-switch drift detected — re-applying"
        apply_firewall
    fi
done

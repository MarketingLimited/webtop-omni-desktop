# WebRTC Configuration

Reliable WebRTC audio requires a reachable TURN server. STUN alone cannot traverse strict NAT or firewall rules. If `WEBRTC_TURN_SERVER` is not configured, connections may fail.

This project now ships with a lightweight [coturn](https://github.com/coturn/coturn) server that starts automatically inside the container.  By default it listens on port **3478** with credentials `webtop:webtop` and is exposed to clients as both STUN and TURN under `stun:localhost:3478` / `turn:localhost:3478`.

When these default `localhost` URLs are used, the client automatically rewrites them to use the page's current hostname. This allows browsers connecting to containerized environments to reach the TURN server without manual configuration.

The TURN server typically listens on UDP port **3478**. Ensure this port (and any additional ports your TURN server uses) is exposed so clients can reach it or override the environment variables to point to an external service.

## docker-compose example

```yaml
version: "3"
services:
  turn:
    image: coturn/coturn
    ports:
      - "3478:3478/udp"
      - "3478:3478/tcp"
    command: ["--no-cli", "--log-file=stdout"]
  webtop:
    image: your-webtop-image
    environment:
      WEBRTC_STUN_SERVER: stun:stun.l.google.com:19302
      WEBRTC_TURN_SERVER: turn:turn:3478
      WEBRTC_TURN_USERNAME: user
      WEBRTC_TURN_PASSWORD: pass
    depends_on:
      - turn
    ports:
      - "8080:8080"
```

Expose additional UDP ranges if your TURN server requires them for relayed traffic.

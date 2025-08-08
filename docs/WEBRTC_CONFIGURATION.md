# WebRTC Configuration

Reliable WebRTC audio requires a reachable TURN server. STUN alone cannot traverse strict NAT or firewall rules. If `WEBRTC_TURN_SERVER` is not configured, connections may fail.

The TURN server typically listens on UDP port **3478**. Ensure this port (and any additional ports your TURN server uses) is exposed so clients can reach it.

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

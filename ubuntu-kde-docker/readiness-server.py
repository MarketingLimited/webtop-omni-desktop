#!/usr/bin/env python3
"""Desktop readiness/liveness HTTP endpoint (Part B-P1).

Rabeeb polls GET /readyz after starting a container so "ready" means the desktop
is actually streamable — not merely that the container process started. The old
`curl localhost:80` healthcheck returned 200 as soon as websockify served the
static noVNC page, well before x11vnc/KDE were up.

  GET /livez  -> 200 while this process (and thus supervisord) is alive.
  GET /readyz -> 200 only when Xvfb :1 + x11vnc:5901 + noVNC:80 + plasmashell are up.

Bound on :8082, loopback-fronted by the Rabeeb proxy. No external deps (stdlib).
"""
import http.server
import socket
import subprocess

PORT = 8082


def _port_open(host: str, port: int, timeout: float = 0.5) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def _proc_running(pattern: str) -> bool:
    return subprocess.run(["pgrep", "-f", pattern],
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


def _ready() -> tuple[bool, dict]:
    checks = {
        "xvfb": _proc_running(r"Xvfb\s+:1") or _proc_running("Xtigervnc") or _proc_running("Xorg"),
        "x11vnc": _port_open("127.0.0.1", 5901),
        "novnc": _port_open("127.0.0.1", 80),
        # Gate on plasmashell (the actual shell) — NOT the `startplasma` wrapper,
        # which appears seconds before the desktop is painted (false-ready). openbox
        # is the fallback WM when KDE isn't used.
        "desktop": _proc_running("plasmashell") or _proc_running("openbox"),
    }
    return all(checks.values()), checks


class Handler(http.server.BaseHTTPRequestHandler):
    def _respond(self, code: int, body: bytes) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/livez"):
            self._respond(200, b'{"status":"alive"}')
            return
        if self.path.startswith("/readyz"):
            ok, checks = _ready()
            payload = ('{"ready":%s,"checks":%s}' % (
                "true" if ok else "false",
                "{" + ",".join('"%s":%s' % (k, "true" if v else "false") for k, v in checks.items()) + "}",
            )).encode()
            self._respond(200 if ok else 503, payload)
            return
        self._respond(404, b'{"error":"not_found"}')

    def log_message(self, *args) -> None:  # silence access logs
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()

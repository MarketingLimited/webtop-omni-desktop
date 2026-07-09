#!/usr/bin/env python3
"""Computer-use control service (Part B-P1).

The Rabeeb chat agent (DesktopControlExecutor / DesktopControlClient) drives the
desktop through this loopback HTTP service — it is the missing "AI can control
the desktop" surface. All actions target DISPLAY :1 via xdotool; screenshots via
`scrot`. Reachable only through Rabeeb's per-session authenticated proxy (the host
port is published on loopback), never directly.

  GET  /screenshot            -> image/png of the current desktop
  POST /click   {x,y,button}  -> move + click
  POST /move    {x,y}
  POST /type    {text}
  POST /key     {keys}        -> xdotool key spec, e.g. "Return" / "ctrl+c"
  POST /scroll  {amount}      -> button 4 (up) / 5 (down) repeated
  GET  /size                  -> {"width":W,"height":H}

Input is validated + every action is logged for auditability. Stdlib only.
"""
import json
import os
import subprocess
import tempfile
import http.server

PORT = 8081
DISPLAY = os.environ.get("DISPLAY", ":1")
ENV = {**os.environ, "DISPLAY": DISPLAY}
MAX_TEXT = 10000


def _xdotool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["xdotool", *args], env=ENV, capture_output=True, text=True, timeout=10)


def _as_int(value, lo: int = 0, hi: int = 100000) -> int | None:
    try:
        n = int(value)
    except (TypeError, ValueError):
        return None
    return n if lo <= n <= hi else None


def _screen_size() -> tuple[int, int]:
    out = _xdotool("getdisplaygeometry").stdout.strip()
    parts = out.split()
    if len(parts) == 2 and parts[0].isdigit():
        return int(parts[0]), int(parts[1])
    return 1920, 1080


class Handler(http.server.BaseHTTPRequestHandler):
    def _json(self, code: int, obj: dict) -> None:
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length <= 0:
            return {}
        try:
            return json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, TypeError):
            return {}

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/screenshot"):
            with tempfile.NamedTemporaryFile(suffix=".png", delete=True) as tmp:
                r = subprocess.run(["scrot", "-o", tmp.name], env=ENV, capture_output=True, timeout=10)
                if r.returncode != 0:
                    self._json(500, {"ok": False, "error": "screenshot_failed"})
                    return
                data = open(tmp.name, "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
            self._audit("screenshot", {})
            return
        if self.path.startswith("/size"):
            w, h = _screen_size()
            self._json(200, {"width": w, "height": h})
            return
        self._json(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        action = self.path.strip("/").split("/")[0]
        body = self._body()

        if action in ("click", "move"):
            x, y = _as_int(body.get("x")), _as_int(body.get("y"))
            if x is None or y is None:
                return self._json(400, {"ok": False, "error": "invalid_coordinates"})
            _xdotool("mousemove", str(x), str(y))
            if action == "click":
                button = str(_as_int(body.get("button"), 1, 5) or 1)
                _xdotool("click", button)
        elif action == "type":
            text = body.get("text")
            if not isinstance(text, str) or len(text) > MAX_TEXT:
                return self._json(400, {"ok": False, "error": "invalid_text"})
            _xdotool("type", "--clearmodifiers", "--", text)
        elif action == "key":
            keys = body.get("keys")
            if not isinstance(keys, str) or not keys or len(keys) > 100:
                return self._json(400, {"ok": False, "error": "invalid_keys"})
            _xdotool("key", "--clearmodifiers", keys)
        elif action == "scroll":
            amount = _as_int(body.get("amount"), -100, 100) or 0
            button = "4" if amount >= 0 else "5"
            for _ in range(min(abs(amount), 20) or 1):
                _xdotool("click", button)
        else:
            return self._json(404, {"ok": False, "error": "unsupported_action"})

        self._audit(action, body)
        self._json(200, {"ok": True, "action": action})

    def _audit(self, action: str, body: dict) -> None:
        # Log the action (never the full typed text) for auditability.
        safe = {k: v for k, v in body.items() if k != "text"}
        if "text" in body:
            safe["text_len"] = len(str(body.get("text", "")))
        print("desktop-control %s %s" % (action, json.dumps(safe)), flush=True)

    def log_message(self, *args) -> None:
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()

# User display and port mapping

Each user can run an isolated desktop session composed of **Xvfb**, **x11vnc** and
**websockify**.  The `add-user-session.sh` helper script assigns a free display
number and matching ports, writes the required supervisor snippet and records the
allocation.

Mappings are stored in `/var/log/webtop/user_ports.csv` using the format:

```
user,display,vnc_port,websocket_port
alice,:2,5902,6082
```

The supervisor snippets are written to `/etc/supervisor/conf.d/user-<user>.conf`
and are automatically picked up by `supervisord` on reread/update.

Use the mapping file to correlate a user with their allocated VNC (`5900+n`) and
websocket (`6080+n`) ports.


## Local NoVNC and Audio Bridge Setup

This project now includes:

- `novnc/index.html`: Modern homepage for NoVNC and audio bridge links.
- `vnc-audio.html`: Placeholder for the VNC audio bridge page.

### To serve these locally with nginx:

1. Ensure your nginx config includes:
    ```nginx
    location /novnc/ {
        alias /absolute/path/to/your/project/novnc/;
        index index.html;
        try_files $uri $uri/ =404;
    }
    location = /vnc-audio.html {
        alias /absolute/path/to/your/project/vnc-audio.html;
    }
    ```
2. Restart nginx after updating the config.
3. Visit `http://localhost/novnc/` for the homepage and `http://localhost/vnc-audio.html` for the audio bridge test.

For production, copy these files to your web root or adjust the alias paths accordingly.

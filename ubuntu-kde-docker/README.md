# Unified KDE Webtop

This project provides a Dockerized, all-in-one, web-accessible Ubuntu KDE desktop environment. It supports Linux, Android (via Waydroid), and Windows (via Wine) applications, with graphics and audio streamed to the browser.

## Features

- **Ubuntu 24.04 + KDE Plasma Desktop:** A full-featured, modern desktop environment.
- **Multi-Platform App Support:**
  - **Linux:** Native support for thousands of applications.
  - **Windows:** Run `.exe` applications using Wine.
  - **Android:** Run APKs in a containerized Android environment with Waydroid.
- **Web-Based Access:** Access the desktop, terminal, and applications from any modern web browser.
- **Zero-Dependency Server:** No host-side configuration or dependencies required (apart from Docker).
- **Software Rendering:** Uses Mesa with `llvmpipe` for OpenGL rendering, requiring no GPU on the host.
- **Audio Redirection:** Audio from applications is routed to the browser via PulseAudio and Xpra.

## Getting Started

1. **Prerequisites:**
   - [Docker](https://docs.docker.com/get-docker/)
   - [Docker Compose](https://docs.docker.com/compose/install/)

2. **Configuration:**
   - Create a `.env` file in the project root directory. You can copy the provided `.env.example` as a template:
     ```bash
     cp .env.example .env
     ```
   - Edit the `.env` file to set your desired usernames, passwords, and other configuration options.

3. **Build and Run:**
   ```bash
   docker compose up -d
   ```
   This will build the Docker image and start the webtop container in the background.

## Accessing Services

| Service               | URL                                      | Credentials        |
| --------------------- | ---------------------------------------- | ------------------ |
| KDE Desktop (noVNC)   | `http://<your-server-ip>:32768`          | -                  |
| KDE Desktop (Xpra)    | `http://<your-server-ip>:14500`          | -                  |
| Terminal (ttyd)       | `http://<your-server-ip>:7681`           | `TTYD_USER` / `TTYD_PASSWORD` |
| SSH                   | `ssh <ADMIN_USERNAME>@<your-server-ip> -p 2222` | `ADMIN_PASSWORD`   |

- **`your-server-ip`**: The IP address of the machine running the Docker container.
- **Credentials**: The values you set in your `.env` file.

## Usage

- **Desktop:** Access the full KDE Plasma desktop through your web browser using either noVNC or the Xpra HTML5 client.
- **Applications:** Launch applications from the desktop, application menu, or via the terminal.
- **Waydroid:** Launch the Waydroid application from the desktop to start the Android container. You can then install and run Android APKs.
- **Wine:** Windows applications can be installed and run using the provided PlayOnLinux utility or by running the installer directly from the terminal (e.g., `wine setup.exe`).
- **File Management:** Use the Dolphin file manager to manage your files. The `/config` directory is mounted as a volume, so you can easily share files between the container and your host machine.

## Customization

- **Dockerfile:** You can customize the installed packages and system configuration by editing the `Dockerfile`.
- **Setup Scripts:** The `setup-desktop.sh` and `setup-flatpak-apps.sh` scripts can be modified to change the desktop shortcuts and Flatpak applications that are installed.
- **Supervisord:** The `supervisord.conf` file controls the services that are run within the container. You can add, remove, or modify services as needed.

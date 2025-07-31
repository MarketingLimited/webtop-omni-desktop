FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install all required packages and lightweight fallback WM
RUN apt-get update && apt-get install -y \
    sudo wget curl gnupg2 apt-transport-https software-properties-common \
    ca-certificates lsb-release htop net-tools unzip locales netcat-openbsd \
    kde-plasma-desktop dolphin kate okular konsole \
    openbox tint2 xterm \
    libreoffice vlc gimp inkscape plank \
    flatpak gnome-software-plugin-flatpak \
    flameshot kdeconnect timeshift syncthing syncthing-gtk \
    krita blender darktable obs-studio calibre \
    git neofetch btop gnome-tweaks stacer \
    # Development Tools - Complete Stack (VS Code will be installed later)
    nodejs npm yarn \
    python3 python3-pip python3-venv python3-dev jupyter-notebook \
    php php-cli php-fpm composer \
    ruby ruby-dev bundler golang-go \
    build-essential cmake \
    # Database clients
    postgresql-client mysql-client redis-tools \
    # Docker and Container Tools
    docker.io docker-compose \
    # Wine for Windows applications
    wine winetricks playonlinux winbind \
    # Android/Waydroid support
    python3-requests-unixsocket \
    lxc-utils dbus-user-session systemd-container \
    # Video Production Professional Suite
    vlc mpv ffmpeg x264 x265 libavcodec-extra \
    audacity kdenlive openshot-qt shotcut \
    handbrake-cli \
    # Advanced Audio Tools
    jackd2 qjackctl ardour \
    # Screen recording and streaming
    simplescreenrecorder kazam \
    v4l2loopback-dkms \
    # Graphics and Design Professional
    frei0r-plugins \
    # File managers and utilities
    mc ranger fzf ripgrep fd-find \
    # Network and security tools
    nmap wireshark \
    # Virtualization
    qemu-system-x86 virt-manager \
    nextcloud-desktop \
    fonts-noto-core fonts-noto-ui-core fonts-noto-color-emoji fonts-noto-extra \
    fonts-dejavu fonts-crosextra-carlito fonts-crosextra-caladea fonts-hosny-amiri fonts-kacst qttranslations5-l10n libqt5script5 fonts-freefont-ttf \
    supervisor novnc websockify x11vnc xvfb \
    dbus-x11 x11-xserver-utils xfonts-base snapd kmod \
    mesa-utils libgl1-mesa-dri libglx-mesa0 libosmesa6 libglu1-mesa \
    gnome-terminal lxterminal terminator accountsservice policykit-1 \
    openssh-server ttyd libcap2-bin polkit-kde-agent-1 \
    alsa-utils alsa-oss pulseaudio pulseaudio-utils pavucontrol paprefs \
    sox ffmpeg gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add repositories for Chrome, Opera, Brave, VS Code
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
    && curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list \
    && wget -qO- https://deb.opera.com/archive.key | gpg --dearmor > /usr/share/keyrings/opera.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/opera.gpg] https://deb.opera.com/opera-stable/ stable non-free" > /etc/apt/sources.list.d/opera.list \
    && apt-get update

# Install Node.js 22 from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install dbeaver
RUN wget -O /usr/share/keyrings/dbeaver.gpg.key https://dbeaver.io/debs/dbeaver.gpg.key \
    && echo "deb [signed-by=/usr/share/keyrings/dbeaver.gpg.key] https://dbeaver.io/debs/dbeaver-ce /" > /etc/apt/sources.list.d/dbeaver.list \
    && apt-get update && apt-get install -y dbeaver-ce && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install wire-desktop
RUN wget -qO- https://wire-app.wire.com/linux/releases.key | gpg --dearmor > /usr/share/keyrings/wire-desktop.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/wire-desktop.gpg] https://wire-app.wire.com/linux/debian stable main" > /etc/apt/sources.list.d/wire-desktop.list \
    && apt-get update && apt-get install -y wire-desktop && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install element-desktop
RUN wget -O /usr/share/keyrings/element-io-archive-keyring.gpg https://packages.element.io/debian/element-io-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" > /etc/apt/sources.list.d/element-io.list \
    && apt-get update && apt-get install -y element-desktop && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install signal-desktop
RUN wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg \
    && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' > /etc/apt/sources.list.d/signal-xenial.list \
    && apt-get update && apt-get install -y signal-desktop && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install browsers and editors
RUN mkdir -p /etc/apt/keyrings \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | tee /etc/apt/keyrings/google-chrome.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y \
        google-chrome-stable brave-browser opera-stable code \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Allow running Chromium-based browsers as root
RUN for f in google-chrome.desktop brave-browser.desktop opera.desktop code.desktop element-desktop.desktop signal-desktop.desktop wire-desktop.desktop; do \
        if [ -f "/usr/share/applications/$f" ]; then \
            sed -i '/^Exec=/ s@ %U@ --no-sandbox %U@; /^Exec=/ s@ %F@ --no-sandbox %F@; /^Exec=/ {/--no-sandbox/! s@$@ --no-sandbox@}' "/usr/share/applications/$f"; \
        fi; \
    done

# Install Waydroid repository and package
RUN curl -fsSL https://repo.waydro.id | bash \
    && apt-get install -y waydroid && apt-get clean && rm -rf /var/lib/apt/lists/*
# Clone WinApps for Linux
RUN git clone --depth 1 https://github.com/Fmstrat/winapps.git /opt/winapps

# Install additional packages that may need separate handling
RUN apt-get update && apt-get install -y \
    handbrake \
    && apt-get clean && rm -rf /var/lib/apt/lists/* || true

# Install Google Ads Editor using Wine
RUN apt-get update && apt-get install -y winetricks \
    && wget -qO /tmp/GoogleAdsEditorSetup.exe https://dl.google.com/adwords_editor/GoogleAdsEditorSetup.exe \
    && winetricks -q win7 || true \
    && wine /tmp/GoogleAdsEditorSetup.exe /silent || true \
    && rm -f /tmp/GoogleAdsEditorSetup.exe

# Setup Flathub remote
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install WordPress and other web development tools
RUN apt-get update && apt-get install -y \
    wordpress \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# Locales
RUN locale-gen en_US.UTF-8 ar_EG.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && fc-cache -f -v
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TTYD_USER=terminal
ENV TTYD_PASSWORD=terminal
# Create directories and VNC setup for x11vnc
RUN mkdir -p /var/run/sshd /root/.vnc /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix


# Desktop and Flatpak setup scripts
COPY setup-flatpak-apps.sh /usr/local/bin/setup-flatpak-apps.sh
COPY setup-desktop.sh /usr/local/bin/setup-desktop.sh
COPY setup-audio.sh /usr/local/bin/setup-audio.sh
COPY setup-marketing-shortcuts.sh /usr/local/bin/setup-marketing-shortcuts.sh
COPY setup-development.sh /usr/local/bin/setup-development.sh
COPY setup-wine.sh /usr/local/bin/setup-wine.sh
COPY setup-waydroid.sh /usr/local/bin/setup-waydroid.sh
COPY setup-video-editing.sh /usr/local/bin/setup-video-editing.sh
COPY setup-ttyd.sh /usr/local/bin/setup-ttyd.sh
COPY service-health.sh /usr/local/bin/service-health.sh
COPY test-desktop-audio.sh /usr/local/bin/test-desktop-audio.sh
COPY audio-validation.sh /usr/local/bin/audio-validation.sh
COPY system-validation.sh /usr/local/bin/system-validation.sh
COPY audio-monitor.sh /usr/local/bin/audio-monitor.sh
COPY health-check.sh /usr/local/bin/health-check.sh
COPY fix-permissions.sh /usr/local/bin/fix-permissions.sh
COPY test-polkit.sh /usr/local/bin/test-polkit.sh
RUN chmod +x /usr/local/bin/setup-*.sh \
    /usr/local/bin/service-health.sh \
    /usr/local/bin/test-desktop-audio.sh \
    /usr/local/bin/audio-monitor.sh \
    /usr/local/bin/audio-validation.sh \
    /usr/local/bin/health-check.sh \
    /usr/local/bin/fix-permissions.sh \
    /usr/local/bin/test-polkit.sh

# Run TTYD setup to create wrapper script
RUN /usr/local/bin/setup-ttyd.sh

# Validate all scripts are present and executable
RUN echo "Validating script dependencies..." && \
    ls -la /usr/local/bin/setup-*.sh \
    /usr/local/bin/service-health.sh \
    /usr/local/bin/test-desktop-audio.sh \
    /usr/local/bin/audio-monitor.sh \
    /usr/local/bin/audio-validation.sh

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy PolicyKit configuration files for Ubuntu 24.04 bug fix
COPY polkit-localauthority.conf /tmp/polkit-localauthority.conf
COPY polkit-dbus.conf /tmp/polkit-dbus.conf

# Ensure updated accountsservice
RUN apt-get update && apt-get install -y accountsservice policykit-1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create default PolicyKit configuration directories and files for Ubuntu 24.04
# Copy PolicyKit configurations to address Ubuntu 24.04 issues
COPY polkit-localauthority.conf /etc/polkit-1/localauthority.conf.d/50-localauthority.conf
COPY 50-localauthority.conf /etc/polkit-1/localauthority.conf.d/51-localauthority.conf  
COPY polkit-dbus.conf /usr/share/dbus-1/system-services/org.freedesktop.PolicyKit1.conf
COPY org.freedesktop.PolicyKit1.service /usr/share/dbus-1/system-services/org.freedesktop.PolicyKit1.service
COPY devuser-all.rules /etc/polkit-1/rules.d/49-nopasswd_global.rules
COPY 10-vendor.d-admin.rules /etc/polkit-1/rules.d/10-vendor.d-admin.rules
COPY monitor-services.sh /usr/local/bin/monitor-services.sh

# Create missing system directories and disable PolicyKit for container environment
RUN mkdir -p /etc/polkit-1/localauthority.conf.d /etc/polkit-1/rules.d /var/lib/polkit-1 \
    /var/log/supervisor /run/user/1000 && \
    chown -R polkitd:polkitd /var/lib/polkit-1 && \
    chown 1000:1000 /run/user/1000 && \
    chmod 700 /run/user/1000 && \
    chmod 755 /etc/polkit-1/rules.d && \
    chmod 644 /etc/polkit-1/rules.d/* /etc/polkit-1/localauthority.conf.d/* && \
    chmod +x /usr/local/bin/monitor-services.sh

# Ensure KDE polkit agent starts correctly
RUN ln -sf /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 /usr/lib/polkit-kde-authentication-agent-1 && \
    sed -i 's@^Exec=.*@Exec=/usr/lib/polkit-kde-authentication-agent-1@' /etc/xdg/autostart/polkit-kde-authentication-agent-1.desktop

COPY xstartup /tmp/xstartup
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /tmp/xstartup

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 22 80 5901 7681

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]

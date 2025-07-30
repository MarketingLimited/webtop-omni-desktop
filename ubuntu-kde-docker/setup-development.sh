#!/bin/bash
set -euxo pipefail

# Setup Development Environment for Marketing Agency
echo "Setting up development environment..."

DEV_USERNAME=${DEV_USERNAME:-devuser}
HOME_DIR="/home/${DEV_USERNAME}"

# Ensure directories exist
mkdir -p "${HOME_DIR}/.local/share/applications"
mkdir -p "${HOME_DIR}/Desktop"
mkdir -p "${HOME_DIR}/Documents/Projects"
mkdir -p "${HOME_DIR}/Documents/Templates"

# Install Node.js Latest LTS (if not already installed)
if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

# Install global npm packages for development
npm install -g \
    @vue/cli \
    @angular/cli \
    create-react-app \
    vite \
    typescript \
    eslint \
    prettier \
    nodemon \
    pm2 \
    serve \
    http-server \
    live-server || true

# Install Python development packages
pip3 install --break-system-packages \
    django \
    flask \
    fastapi \
    jupyter \
    pandas \
    numpy \
    requests \
    beautifulsoup4 \
    selenium \
    pytest \
    black \
    flake8 || true

# Install Ruby gems for development
gem install \
    rails \
    sinatra \
    bundler \
    rubocop \
    rspec || true

# Install PHP Composer globally
if [ ! -f /usr/local/bin/composer ]; then
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
fi

# Setup VS Code settings for marketing development
mkdir -p "${HOME_DIR}/.config/Code/User"
cat > "${HOME_DIR}/.config/Code/User/settings.json" << 'EOF'
{
    "workbench.colorTheme": "Default Dark+",
    "editor.fontSize": 14,
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.formatOnSave": true,
    "files.autoSave": "afterDelay",
    "terminal.integrated.shell.linux": "/bin/bash",
    "git.enableSmartCommit": true,
    "extensions.autoUpdate": true,
    "workbench.startupEditor": "welcomePage"
}
EOF

# Install VS Code extensions for marketing/web development
code --install-extension ms-vscode.vscode-typescript-next
code --install-extension bradlc.vscode-tailwindcss
code --install-extension esbenp.prettier-vscode
code --install-extension ms-python.python
code --install-extension ms-vscode.live-server
code --install-extension ritwickdey.LiveServer
code --install-extension formulahendry.auto-rename-tag
code --install-extension christian-kohler.path-intellisense
code --install-extension ms-vscode.vscode-json || true

# Create development project templates
mkdir -p "${HOME_DIR}/Documents/Templates/React-Project"
mkdir -p "${HOME_DIR}/Documents/Templates/Vue-Project"
mkdir -p "${HOME_DIR}/Documents/Templates/Marketing-Landing"
mkdir -p "${HOME_DIR}/Documents/Templates/Email-Campaign"

# Create desktop shortcuts for development tools
cat > "${HOME_DIR}/.local/share/applications/vscode.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Visual Studio Code
Comment=Code Editing. Redefined.
Exec=code
Icon=code
StartupNotify=true
StartupWMClass=Code
Categories=Development;IDE;
MimeType=text/plain;inode/directory;
EOF

cat > "${HOME_DIR}/.local/share/applications/terminal-dev.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Development Terminal
Comment=Terminal optimized for development
Exec=konsole --workdir ${HOME_DIR}/Documents/Projects
Icon=utilities-terminal
StartupNotify=true
Categories=Development;System;
EOF

# Copy development shortcuts to desktop
cp "${HOME_DIR}/.local/share/applications/vscode.desktop" "${HOME_DIR}/Desktop/"
cp "${HOME_DIR}/.local/share/applications/terminal-dev.desktop" "${HOME_DIR}/Desktop/"
chmod +x "${HOME_DIR}/Desktop"/*.desktop

# Create development folder structure
mkdir -p "${HOME_DIR}/Documents/Projects/Web-Projects"
mkdir -p "${HOME_DIR}/Documents/Projects/Mobile-Apps"
mkdir -p "${HOME_DIR}/Documents/Projects/Marketing-Campaigns"
mkdir -p "${HOME_DIR}/Documents/Projects/Client-Work"

# Set ownership
chown -R ${DEV_USERNAME}:${DEV_USERNAME} "${HOME_DIR}"

echo "Development environment setup completed!"
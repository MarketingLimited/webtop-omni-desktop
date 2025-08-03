#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "💻 Setting up development environment..."

# Create development directories
mkdir -p \
    "${DEV_HOME}/.local/share/applications" \
    "${DEV_HOME}/Desktop" \
    "${DEV_HOME}/Documents/Projects" \
    "${DEV_HOME}/Documents/Projects/React" \
    "${DEV_HOME}/Documents/Projects/Vue" \
    "${DEV_HOME}/Documents/Projects/Angular" \
    "${DEV_HOME}/Documents/Projects/Node" \
    "${DEV_HOME}/Documents/Projects/Python" \
    "${DEV_HOME}/Documents/Projects/PHP" \
    "${DEV_HOME}/Documents/Projects/Landing-Pages" \
    "${DEV_HOME}/Documents/Projects/Email-Campaigns"

# Install global npm packages for marketing development
echo "📦 Installing development tools..."
npm install -g \
    @vue/cli \
    @angular/cli \
    create-react-app \
    vite \
    tailwindcss \
    @tailwindcss/cli \
    typescript \
    prettier \
    eslint \
    live-server \
    http-server \
    serve \
    nodemon \
    pm2 \
    vercel \
    netlify-cli || true

# Install Python development packages
echo "🐍 Setting up Python development..."
pip3 install --user \
    django \
    flask \
    fastapi \
    uvicorn \
    requests \
    beautifulsoup4 \
    selenium \
    pandas \
    matplotlib \
    jupyter \
    black \
    flake8 \
    pytest || true

# Install Ruby gems
echo "💎 Setting up Ruby development..."
gem install \
    rails \
    sinatra \
    bundler \
    rubocop \
    rspec || true

# Install Composer globally for PHP
if [ ! -f /usr/local/bin/composer ]; then
    echo "🎼 Installing Composer..."
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
fi

# VS Code configuration
echo "⚙️ Configuring VS Code..."
mkdir -p "${DEV_HOME}/.config/Code/User"

cat > "${DEV_HOME}/.config/Code/User/settings.json" << 'EOF'
{
    "workbench.colorTheme": "Default Dark+",
    "editor.fontSize": 14,
    "editor.fontFamily": "Fira Code, Consolas, 'Courier New', monospace",
    "editor.fontLigatures": true,
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.wordWrap": "on",
    "editor.minimap.enabled": true,
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.fixAll.eslint": true
    },
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "emmet.includeLanguages": {
        "javascript": "javascriptreact",
        "vue-html": "html",
        "razor": "html",
        "plaintext": "jade"
    },
    "tailwindCSS.includeLanguages": {
        "javascript": "javascript",
        "html": "HTML"
    },
    "liveServer.settings.donotShowInfoMsg": true,
    "git.enableSmartCommit": true,
    "git.confirmSync": false,
    "terminal.integrated.defaultProfile.linux": "bash",
    "workbench.startupEditor": "welcomePage"
}
EOF

# Install VS Code extensions
echo "🔌 Installing VS Code extensions..."
code --install-extension ms-vscode.vscode-typescript-next || true
code --install-extension bradlc.vscode-tailwindcss || true
code --install-extension esbenp.prettier-vscode || true
code --install-extension ms-python.python || true
code --install-extension ms-python.flake8 || true
code --install-extension ritwickdey.liveserver || true
code --install-extension formulahendry.auto-rename-tag || true
code --install-extension christian-kohler.path-intellisense || true
code --install-extension ms-vscode.vscode-json || true
code --install-extension octref.vetur || true
code --install-extension angular.ng-template || true
code --install-extension ms-vscode.sublime-keybindings || true

# Create desktop shortcuts
cat > "${DEV_HOME}/.local/share/applications/vscode.desktop" << 'EOF'
[Desktop Entry]
Name=VS Code
Comment=Code editor for development
Exec=code
Icon=com.visualstudio.code
Terminal=false
Type=Application
Categories=Development;IDE;
EOF

cat > "${DEV_HOME}/.local/share/applications/dev-terminal.desktop" << 'EOF'
[Desktop Entry]
Name=Development Terminal
Comment=Terminal for development tasks
Exec=konsole --workdir /home/devuser/Documents/Projects
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Development;System;
EOF

# Copy shortcuts to desktop
cp "${DEV_HOME}/.local/share/applications/vscode.desktop" "${DEV_HOME}/Desktop/"
cp "${DEV_HOME}/.local/share/applications/dev-terminal.desktop" "${DEV_HOME}/Desktop/"
chmod +x "${DEV_HOME}/Desktop/"*.desktop

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Development environment setup complete"
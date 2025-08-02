#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

echo "💻 Setting up development environment..."

# Create development directories
project_dirs=(
    "${DEV_HOME}/.local/share/applications"
    "${DEV_HOME}/Desktop"
    "${DEV_HOME}/Documents/Projects"
)
for lang in React Vue Angular Node Python PHP "Landing-Pages" "Email-Campaigns"; do
    project_dirs+=("${DEV_HOME}/Documents/Projects/${lang}")
done
mkdir -p "${project_dirs[@]}"

# Install global npm packages for marketing development
if command -v npm >/dev/null 2>&1; then
    echo "📦 Installing development tools..."
    npm_packages=(
        "@vue/cli"
        "@angular/cli"
        "create-react-app"
        "vite"
        "tailwindcss"
        "typescript"
        "prettier"
        "eslint"
        "live-server"
        "http-server"
        "serve"
        "nodemon"
        "pm2"
        "vercel"
        "netlify-cli"
    )
    npm install -g "${npm_packages[@]}" || true
else
    echo "⚠️ npm not found, skipping Node.js tooling installation"
fi

# Install Python development packages
if command -v pip3 >/dev/null 2>&1; then
    echo "🐍 Setting up Python development..."
    python_packages=(
        "django"
        "flask"
        "fastapi"
        "uvicorn"
        "requests"
        "beautifulsoup4"
        "selenium"
        "pandas"
        "matplotlib"
        "jupyter"
        "black"
        "flake8"
        "pytest"
    )
    pip3 install --user "${python_packages[@]}" || true
else
    echo "⚠️ pip3 not found, skipping Python tooling installation"
fi

# Install Ruby gems
if command -v gem >/dev/null 2>&1; then
    echo "💎 Setting up Ruby development..."
    ruby_gems=(
        "rails"
        "sinatra"
        "bundler"
        "rubocop"
        "rspec"
    )
    gem install --no-document "${ruby_gems[@]}" || true
else
    echo "⚠️ Ruby gem command not found, skipping Ruby tooling installation"
fi

# Install Composer globally for PHP
if [ ! -x /usr/local/bin/composer ] && command -v php >/dev/null 2>&1; then
    echo "🎼 Installing Composer..."
    (php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
        && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
        && rm composer-setup.php) || true
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
if command -v code >/dev/null 2>&1; then
    echo "🔌 Installing VS Code extensions..."
    code_extensions=(
        "ms-vscode.vscode-typescript-next"
        "bradlc.vscode-tailwindcss"
        "esbenp.prettier-vscode"
        "ms-python.python"
        "ms-python.flake8"
        "ritwickdey.liveserver"
        "formulahendry.auto-rename-tag"
        "christian-kohler.path-intellisense"
        "ms-vscode.vscode-json"
        "octref.vetur"
        "angular.ng-template"
        "ms-vscode.sublime-keybindings"
    )
    for ext in "${code_extensions[@]}"; do
        code --install-extension "$ext" || true
    done
else
    echo "⚠️ VS Code not found, skipping extension installation"
fi

# Create desktop shortcuts
cat > "${DEV_HOME}/.local/share/applications/vscode.desktop" <<'EOF'
[Desktop Entry]
Name=VS Code
Comment=Code editor for development
Exec=code
Icon=com.visualstudio.code
Terminal=false
Type=Application
Categories=Development;IDE;
EOF

cat > "${DEV_HOME}/.local/share/applications/dev-terminal.desktop" <<EOF
[Desktop Entry]
Name=Development Terminal
Comment=Terminal for development tasks
Exec=konsole --workdir ${DEV_HOME}/Documents/Projects
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Development;System;
EOF

# Copy shortcuts to desktop
cp "${DEV_HOME}/.local/share/applications/"{vscode,dev-terminal}.desktop "${DEV_HOME}/Desktop/"
chmod +x "${DEV_HOME}/Desktop/"*.desktop

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}"

echo "✅ Development environment setup complete"


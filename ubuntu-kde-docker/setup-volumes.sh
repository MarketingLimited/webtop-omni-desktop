#!/bin/bash
set -euo pipefail

# Volume Setup Script for Enhanced Container Management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BACKUP_DIR="$SCRIPT_DIR/backups"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

echo "🔧 Setting up enhanced volume management..."

# Ensure base directories and shared volume exist using webtop initialization
./webtop.sh volumes list >/dev/null 2>&1 || true

# Populate shared resources volume if empty
if ! docker run --rm -v shared_resources:/shared alpine test -f /shared/README.txt >/dev/null 2>&1; then
    echo "📦 Populating shared resources volume..."
    docker run --rm -v shared_resources:/shared alpine sh -c "\
        mkdir -p /shared/fonts /shared/tools /shared/resources /shared/templates\n\
        echo 'Shared resources initialized' > /shared/README.txt\n\
    "
fi

# Create basic template if missing
if [ ! -f "$TEMPLATE_DIR/basic/template.json" ]; then
    echo "📝 Creating basic template..."
    mkdir -p "$TEMPLATE_DIR/basic"
    cat > "$TEMPLATE_DIR/basic/template.json" <<'TEMPLATE'
{
    "name": "basic",
    "source_container": "base",
    "created": "2024-01-31T00:00:00Z",
    "description": "Basic KDE desktop environment",
    "volumes": ["config", "home"]
}
TEMPLATE
fi

echo "📁 Directory structure:"
echo "  📦 Backups: $BACKUP_DIR"
echo "  📝 Templates: $TEMPLATE_DIR"
echo "  🌐 Shared Volume: shared_resources"

echo "✅ Volume management setup complete!"
echo
echo "💡 Usage Examples:"
echo "  ./webtop.sh up --name client1                    # Create container"
echo "  ./webtop.sh backup client1                       # Backup container"
echo "  ./webtop.sh clone client1 client2                # Clone container"
echo "  ./webtop.sh template save client1 my-template    # Save as template"
echo "  ./webtop.sh template create client3 my-template  # Create from template"
echo "  ./webtop.sh volumes list                         # List all volumes"
echo "  ./webtop.sh volumes backup-all                   # Backup all containers"
echo

#!/bin/bash
set -euo pipefail

# Volume Setup Script for Enhanced Container Management

BACKUP_DIR="./backups"
TEMPLATE_DIR="./templates"
SHARED_DIR="./shared"

echo "🔧 Setting up enhanced volume management..."

# Create directories
mkdir -p "$BACKUP_DIR" "$TEMPLATE_DIR" "$SHARED_DIR"

# Create shared resources structure
mkdir -p "$SHARED_DIR/resources" "$SHARED_DIR/fonts" "$SHARED_DIR/tools"

# Create shared resources volume if it doesn't exist
if ! docker volume ls | grep -q "shared_resources"; then
    echo "📦 Creating shared resources volume..."
    docker volume create shared_resources
    
    # Populate shared resources with basic items
    echo "📁 Setting up shared resources..."
    docker run --rm -v shared_resources:/shared alpine sh -c "
        mkdir -p /shared/fonts /shared/tools /shared/resources /shared/templates
        echo 'Shared resources initialized' > /shared/README.txt
    "
fi

# Create basic templates directory structure
mkdir -p "$TEMPLATE_DIR/basic" "$TEMPLATE_DIR/marketing" "$TEMPLATE_DIR/developer"

# Create template metadata for basic template
cat > "$TEMPLATE_DIR/basic/template.json" << 'EOF'
{
    "name": "basic",
    "source_container": "base",
    "created": "2024-01-31T00:00:00Z",
    "description": "Basic KDE desktop environment",
    "volumes": ["config", "home"]
}
EOF

echo "📁 Directory structure:"
echo "  📦 Backups: $BACKUP_DIR"
echo "  📝 Templates: $TEMPLATE_DIR" 
echo "  🔗 Shared: $SHARED_DIR"
echo "  🌐 Shared Volume: shared_resources"

echo "✅ Volume management setup complete!"
echo ""
echo "💡 Usage Examples:"
echo "  ./webtop.sh up --name client1                    # Create container"
echo "  ./webtop.sh backup client1                       # Backup container"
echo "  ./webtop.sh clone client1 client2                # Clone container"
echo "  ./webtop.sh template save client1 my-template    # Save as template"
echo "  ./webtop.sh template create client3 my-template  # Create from template"
echo "  ./webtop.sh volumes list                         # List all volumes"
echo "  ./webtop.sh volumes backup-all                   # Backup all containers"
echo ""
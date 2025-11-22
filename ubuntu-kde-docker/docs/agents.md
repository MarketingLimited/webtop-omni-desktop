# Documentation Module - Technical Documentation

## 1. Purpose (الغرض)

هذا الـ module يحتوي على **الوثائق التقنية الشاملة** لمشروع webtop-omni-desktop، يشمل أدلة الإعداد، استكشاف الأخطاء، والبنية المعمارية.

**الوثائق الرئيسية**:
- ✅ Setup & configuration guides
- ✅ Authentication & security documentation
- ✅ Multi-container deployment guides
- ✅ Audio system diagnostics
- ✅ Troubleshooting guides
- ✅ Architecture documentation

**الجمهور المستهدف**:
- Developers يعملون على المشروع
- System administrators يقومون بـ deployment
- DevOps teams يديرون multiple containers
- End users يحتاجون troubleshooting help

---

## 2. Owned Scope (النطاق المملوك)

### Documentation Files:

**Main Documentation**:
- `README.md` - Documentation index و overview
  - Project structure
  - Available documentation
  - Quick links
  - Getting started

**Setup & Configuration**:
- `AUTHENTICATION.md` - Authentication & security setup (11,943 bytes)
  - User account management
  - HTTP authentication
  - SSH configuration
  - Security best practices
  - Password management
  - Multi-user scenarios

**Deployment**:
- `MULTI_CONTAINER.md` - Multi-container deployment guide (9,176 bytes)
  - Multi-tenant architecture
  - Container orchestration
  - Port management
  - Resource allocation
  - Client isolation
  - Backup/restore strategies

**Troubleshooting**:
- `AUDIO_DIAGNOSTICS.md` - Audio system diagnostics (2,911 bytes)
  - PulseAudio troubleshooting
  - WebSocket connection issues
  - Audio device validation
  - Common audio problems
  - Debugging commands

**Archive**:
- `archive/` - Old or deprecated documentation
  - Preserved for reference
  - May contain outdated info

---

## 3. Key Files & Entry Points

### Documentation Structure:

```
docs/
├── README.md                   # 📋 Start here - Documentation index
│   ├── Overview of all docs
│   ├── Navigation guide
│   └── Quick reference links
│
├── AUTHENTICATION.md           # 🔐 Security & access control
│   ├── User management
│   ├── SSH setup
│   ├── HTTP auth
│   └── Security hardening
│
├── MULTI_CONTAINER.md          # 🐳 Multi-tenant deployment
│   ├── Architecture overview
│   ├── Container creation
│   ├── Port assignment
│   ├── Resource limits
│   └── Client isolation
│
├── AUDIO_DIAGNOSTICS.md        # 🔊 Audio troubleshooting
│   ├── PulseAudio checks
│   ├── WebSocket debugging
│   ├── Device validation
│   └── Common fixes
│
└── archive/                    # 📦 Deprecated docs
    └── [old files]
```

### Reading Path للمستخدمين الجدد:

```
1. START → README.md
   ↓
   Understand project structure & available docs

2. SETUP → ../agents.md (root)
   ↓
   Initial project setup & environment

3. CONTAINER → AUTHENTICATION.md
   ↓
   Configure users & security

4. DEPLOY → MULTI_CONTAINER.md (if needed)
   ↓
   Multi-client deployment

5. TROUBLESHOOT → AUDIO_DIAGNOSTICS.md (when issues occur)
   ↓
   Debug audio problems
```

---

## 4. Dependencies & Interfaces

### Documentation Dependencies:

**Source of Truth**:
- Source code في `/ubuntu-kde-docker/`
- Scripts: `setup-*.sh`, `*-health*.sh`, `webtop.sh`
- Configs: `Dockerfile`, `docker-compose*.yml`, `supervisord.conf`, `.env.example`

**Documentation يعكس**:
- Environment variables من `.env.example`
- Service configurations من `supervisord.conf`
- Port mappings من `docker-compose.yml`
- CLI commands من `webtop.sh`
- Script behaviors من setup scripts

### External References:

**Technologies Documented**:
- **Docker**: Container concepts, commands, compose syntax
- **Supervisord**: Process management, configuration format
- **PulseAudio**: Audio server, pactl commands, module system
- **KDE Plasma**: Desktop environment, configuration
- **noVNC**: Browser VNC client usage
- **SSH**: OpenSSH server configuration
- **WebSocket**: Protocol for audio streaming

**External Links** (assumed - should be verified):
- Docker documentation: https://docs.docker.com
- KDE documentation: https://docs.kde.org
- PulseAudio wiki: https://www.freedesktop.org/wiki/Software/PulseAudio/
- Supervisord docs: http://supervisord.org/

---

## 5. Local Rules / Patterns

### Documentation Standards:

#### 1. File Naming:
```
Pattern: UPPERCASE_WITH_UNDERSCORES.md
Examples:
  ✓ AUTHENTICATION.md
  ✓ MULTI_CONTAINER.md
  ✓ AUDIO_DIAGNOSTICS.md
  ✗ authentication.md (wrong)
  ✗ Multi-Container.md (wrong)
```

#### 2. Markdown Structure:
```markdown
# Main Title (H1 - one per file)

## Section (H2)

### Subsection (H3)

#### Detail (H4 - use sparingly)

**Bold** for emphasis
*Italic* for terms
`code` for commands/paths
```code blocks``` for multi-line
[Links](./other-doc.md) for cross-references
```

#### 3. Code Examples:
```bash
# Always include context comments
# Bad:
docker-compose up

# Good:
# Start the desktop container
docker-compose up -d

# Check container status
docker-compose ps
```

#### 4. Command Documentation:
```markdown
### Command Name

**Purpose**: Brief description

**Syntax**:
```bash
command [options] <required> [optional]
```

**Examples**:
```bash
# Example 1: Common use case
command arg1 arg2

# Example 2: Advanced use case
command --flag arg1 --option=value
```

**Options**:
- `--flag`: Description
- `-o, --option`: Description with short form

**Output**:
```
Expected output here
```

**Troubleshooting**:
- **Error**: "Error message"
  - **Cause**: Why it happens
  - **Fix**: How to resolve
```

#### 5. Cross-References:
```markdown
<!-- Internal links (relative) -->
See [Authentication Guide](./AUTHENTICATION.md) for details.
Refer to [Multi-Container Setup](./MULTI_CONTAINER.md#port-assignment).

<!-- Parent directory -->
See [Main README](../README.md).

<!-- Code references -->
Configuration in `../docker-compose.yml`.
Script located at `../webtop.sh`.
```

#### 6. Warning & Note Boxes:
```markdown
⚠️ **Warning**: Critical information about potential issues.

⚡ **Important**: Significant detail requiring attention.

💡 **Tip**: Helpful suggestion or best practice.

📝 **Note**: Additional context or clarification.

✅ **Success**: Indicator of correct state or completion.

❌ **Error**: Problem indicator or incorrect approach.
```

#### 7. Version Information:
```markdown
**Last Updated**: YYYY-MM-DD
**Applies to**: webtop-omni-desktop v1.x
**Prerequisites**: List required setup
```

---

### Content Organization:

#### Documentation Sections (Standard Order):

```markdown
# Document Title

## Overview
Brief introduction (2-3 paragraphs)

## Prerequisites
- Required knowledge
- Required tools
- Required setup

## Quick Start
Minimal steps to get started (for impatient users)

## Detailed Guide
Step-by-step instructions with explanations

### Step 1: [Action]
Detailed instructions...

### Step 2: [Action]
Detailed instructions...

## Advanced Topics
Complex scenarios, edge cases

## Troubleshooting
Common problems and solutions

### Problem: [Description]
- **Symptoms**: What you see
- **Cause**: Why it happens
- **Solution**: How to fix

## Reference
Quick reference tables, command lists

## Related Documentation
Links to other docs
```

---

### Troubleshooting Documentation Pattern:

```markdown
## Problem: [User-Facing Description]

**Symptoms**:
- Symptom 1: What the user observes
- Symptom 2: Error messages
- Symptom 3: Unexpected behavior

**Diagnosis**:
```bash
# Commands to verify the problem
docker-compose exec webtop command-to-diagnose
```

**Cause**:
Technical explanation of root cause

**Solution**:
```bash
# Step 1: Stop service if needed
docker-compose exec webtop supervisorctl stop service

# Step 2: Fix the issue
docker-compose exec webtop fix-command

# Step 3: Restart service
docker-compose exec webtop supervisorctl start service

# Step 4: Verify fix
docker-compose exec webtop verify-command
```

**Prevention**:
How to avoid this problem in the future

**Related Issues**:
- [Link to similar problem](#other-problem)
```

---

## 6. How to Run / Test

### Documentation Validation:

#### 1. Link Checking:
```bash
cd ubuntu-kde-docker/docs

# Find all markdown files
find . -name "*.md"

# Check for broken internal links (manual)
# For each .md file:
# 1. Open in editor
# 2. Check all [link](path) references
# 3. Verify files exist at relative paths

# Example check
ls ./AUTHENTICATION.md  # Should exist
ls ../README.md         # Should exist
ls ../docker-compose.yml  # Should exist
```

#### 2. Code Example Testing:
```bash
cd ubuntu-kde-docker

# Test each command/script referenced in docs
# Example from AUTHENTICATION.md:

# Test user creation
docker-compose exec webtop id devuser

# Test SSH
ssh -p 2222 devuser@localhost echo "SSH works"

# If command fails, documentation needs update
```

#### 3. Markdown Linting:
```bash
# Install markdownlint-cli
npm install -g markdownlint-cli

# Lint all docs
cd ubuntu-kde-docker/docs
markdownlint *.md

# Fix common issues
markdownlint --fix *.md
```

#### 4. Spelling Check:
```bash
# Install aspell
apt-get install aspell

# Check spelling (ignore code blocks)
cd ubuntu-kde-docker/docs
aspell check AUTHENTICATION.md
# (Interactive - press 'i' to ignore, 'r' to replace)
```

#### 5. Readability Test:
```bash
# Manual review checklist:
# □ Can a new user follow the instructions?
# □ Are code examples accurate?
# □ Are prerequisites clearly listed?
# □ Are error messages helpful?
# □ Are links working?
# □ Is terminology consistent?
```

---

### Documentation Preview:

#### Local Preview (GitHub-style):
```bash
# Install grip (GitHub markdown renderer)
pip install grip

# Serve documentation
cd ubuntu-kde-docker/docs
grip README.md 8000

# Open: http://localhost:8000
# Navigate between docs via links
```

#### VS Code Preview:
```bash
# Open in VS Code
code ubuntu-kde-docker/docs/

# Use built-in markdown preview
# Ctrl+Shift+V (or Cmd+Shift+V on Mac)
```

---

## 7. Common Tasks for Agents

### Task 1: إنشاء مستند جديد

```bash
cd ubuntu-kde-docker/docs

# 1. Create file with standard naming
touch NEW_FEATURE_GUIDE.md

# 2. Add boilerplate structure
cat > NEW_FEATURE_GUIDE.md << 'EOF'
# New Feature Guide

## Overview

Brief introduction to the new feature.

## Prerequisites

- Prerequisite 1
- Prerequisite 2

## Setup

### Step 1: First Step

Detailed instructions...

```bash
# Example commands
command --example
```

### Step 2: Second Step

More instructions...

## Verification

How to verify the feature works:

```bash
# Test command
docker-compose exec webtop test-command
```

## Troubleshooting

### Problem: Feature Not Working

**Symptoms**: What you see

**Solution**:
```bash
# Fix command
docker-compose exec webtop fix-command
```

## Related Documentation

- [Main README](./README.md)
- [Authentication](./AUTHENTICATION.md)

---

**Last Updated**: YYYY-MM-DD
**Applies to**: webtop-omni-desktop v1.x
EOF

# 3. Update docs/README.md to include link
nano README.md
# Add link to new doc in appropriate section

# 4. Update root README.md if needed
nano ../README.md
```

---

### Task 2: تحديث مستند موجود

```bash
cd ubuntu-kde-docker/docs

# 1. Open document
nano AUTHENTICATION.md

# 2. Make changes
# - Update commands if scripts changed
# - Update examples if syntax changed
# - Update paths if files moved
# - Add new sections for new features

# 3. Update "Last Updated" timestamp at bottom
# Last Updated: 2025-11-22

# 4. Test commands in document
# Run each example to verify accuracy

# 5. Check for broken links
# Verify all [link](path) references

# 6. Commit changes
git add AUTHENTICATION.md
git commit -m "docs: update authentication guide with new SSH config"
```

---

### Task 3: إضافة Troubleshooting Entry

```bash
cd ubuntu-kde-docker/docs

# 1. Open appropriate doc (or create dedicated troubleshooting doc)
nano AUDIO_DIAGNOSTICS.md

# 2. Add new troubleshooting section
cat >> AUDIO_DIAGNOSTICS.md << 'EOF'

## Problem: Audio Crackling/Distortion

**Symptoms**:
- Audio plays but sounds distorted
- Crackling or popping noises
- Intermittent audio dropouts

**Diagnosis**:
```bash
# Check PulseAudio sample rate
docker-compose exec webtop pactl info | grep "Default Sample Specification"

# Check system load
docker-compose exec webtop top -bn1 | head -20
```

**Cause**:
Buffer size too small or CPU overload causing audio underruns.

**Solution**:
```bash
# Increase buffer size
# Edit setup-audio-bridge.sh
nano ../setup-audio-bridge.sh

# Find buffer settings and increase:
# bufferSize: 4096 -> 8192

# Rebuild container
docker-compose build
docker-compose down
docker-compose up -d
```

**Prevention**:
- Allocate sufficient CPU resources to container
- Use lower resolution display (less CPU usage)
- Disable KDE visual effects

**Related Issues**:
- [Audio Not Streaming](#problem-audio-not-streaming)

EOF

# 3. Update table of contents if present
```

---

### Task 4: إضافة Command Reference

```bash
cd ubuntu-kde-docker/docs

# 1. Create or update command reference section
# In relevant doc (e.g., MULTI_CONTAINER.md)

# 2. Add command documentation
cat >> MULTI_CONTAINER.md << 'EOF'

## Command Reference

### webtop.sh create-container

**Purpose**: Create a new isolated container for a client

**Syntax**:
```bash
./webtop.sh create-container <container-name> [options]
```

**Arguments**:
- `<container-name>`: Unique name for the container (required)

**Options**:
- `--ports <base-port>`: Specify base port number (default: auto-increment)
- `--cpu <cores>`: CPU limit (default: unlimited)
- `--memory <size>`: Memory limit (e.g., 4g) (default: unlimited)

**Examples**:
```bash
# Create container with default settings
./webtop.sh create-container client1

# Create with custom port base
./webtop.sh create-container client2 --ports 33000

# Create with resource limits
./webtop.sh create-container client3 --cpu 2 --memory 4g
```

**Output**:
```
Creating container: client1
Base ports: noVNC=32769, SSH=2223, TTYD=7682, Audio=8081
Container created successfully
Access URL: http://localhost:32769
```

**Notes**:
- Container name must be unique
- Ports auto-increment from base port
- Use `webtop.sh list` to see all containers

**Related Commands**:
- [`webtop.sh start`](#webtopsh-start)
- [`webtop.sh stop`](#webtopsh-stop)
- [`webtop.sh remove`](#webtopsh-remove)

EOF
```

---

### Task 5: Document Breaking Change

```bash
cd ubuntu-kde-docker/docs

# 1. Add warning to affected documentation
nano AUTHENTICATION.md

# 2. Add prominent warning at top
cat > temp.md << 'EOF'
# Authentication & Security Setup

⚠️ **BREAKING CHANGE (v2.0)**:
Default password format changed. If upgrading from v1.x:
1. Update `.env` file with new password format
2. Rebuild container: `docker-compose build`
3. Reset user passwords inside container
See [Migration Guide](#migration-from-v1x) for details.

---

EOF

# Prepend to existing content
cat AUTHENTICATION.md >> temp.md
mv temp.md AUTHENTICATION.md

# 3. Add migration section at end
cat >> AUTHENTICATION.md << 'EOF'

## Migration from v1.x

### Password Format Change

**Old Format** (v1.x):
```bash
DEV_PASSWORD=simple
```

**New Format** (v2.0):
```bash
DEV_PASSWORD=Complex_P@ssw0rd123!
```

**Migration Steps**:
```bash
# 1. Backup existing container
./webtop.sh backup webtop /backups/pre-migration.tar.gz

# 2. Update .env with new passwords
nano .env
# Change all password variables to new format

# 3. Rebuild container
docker-compose build

# 4. Restart
docker-compose down
docker-compose up -d

# 5. Verify login
ssh -p 2222 devuser@localhost
```

**Rollback**:
If issues occur, restore from backup:
```bash
./webtop.sh restore webtop /backups/pre-migration.tar.gz
```

EOF
```

---

### Task 6: Create Quick Reference

```bash
cd ubuntu-kde-docker/docs

# 1. Create quick reference file
cat > QUICK_REFERENCE.md << 'EOF'
# Quick Reference Guide

## Common Commands

### Container Management
```bash
docker-compose up -d           # Start container
docker-compose down            # Stop container
docker-compose restart         # Restart container
docker-compose ps              # Status
docker-compose logs -f         # View logs
```

### Access Points
| Service | URL / Command | Default Port |
|---------|---------------|--------------|
| noVNC | http://localhost:32768 | 32768 |
| SSH | `ssh devuser@localhost -p 2222` | 2222 |
| TTYD | http://localhost:7681 | 7681 |
| Audio WS | ws://localhost:8080 | 8080 |

### Default Credentials
| Account | Username | Password |
|---------|----------|----------|
| Dev User | devuser | DevPassw0rd! |
| Admin | adminuser | AdminPassw0rd! |
| Root | root | ComplexP@ssw0rd! |

⚠️ **Change these in production!**

### Service Management
```bash
# View all services
docker-compose exec webtop supervisorctl status

# Restart specific service
docker-compose exec webtop supervisorctl restart KDE

# View service logs
docker-compose exec webtop tail -f /var/log/supervisor/kde.log
```

### Health Checks
```bash
# Full diagnostic
docker-compose exec webtop /opt/diagnostic-script.sh

# Audio validation
docker-compose exec webtop /usr/local/bin/audio-validation.sh

# Service health
docker-compose exec webtop /usr/local/bin/service-health.sh check-all
```

### Multi-Container
```bash
./webtop.sh create-container <name>    # Create
./webtop.sh list                       # List all
./webtop.sh start <name>               # Start
./webtop.sh stop <name>                # Stop
./webtop.sh remove <name>              # Remove
./webtop.sh status                     # Status of all
```

### Backup & Restore
```bash
# Backup
./webtop.sh backup <name> /path/to/backup.tar.gz

# Restore
./webtop.sh restore <name> /path/to/backup.tar.gz
```

## Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs

# Check ports
netstat -tuln | grep -E "(32768|2222|7681)"

# Rebuild
docker-compose build --no-cache
docker-compose up -d
```

### Can't connect to noVNC
```bash
# Check VNC service
docker-compose exec webtop supervisorctl status X11VNC noVNC

# Restart VNC
docker-compose exec webtop supervisorctl restart X11VNC noVNC
```

### No audio
```bash
# Validate audio system
docker-compose exec webtop /usr/local/bin/audio-validation.sh

# Check PulseAudio
docker-compose exec webtop pactl info
docker-compose exec webtop pactl list sinks

# Restart audio
docker-compose exec webtop supervisorctl restart PulseAudioDaemon
```

### KDE desktop blank/frozen
```bash
# Check Xvfb
docker-compose exec webtop supervisorctl status Xvfb

# Restart KDE
docker-compose exec webtop supervisorctl restart KDE

# Check logs
docker-compose exec webtop tail -100 /var/log/supervisor/kde.log
```

## File Locations

```
Container:
/opt/diagnostic-script.sh              # Diagnostics
/usr/local/bin/                        # Custom scripts
/var/log/supervisor/                   # Logs
/home/${DEV_USERNAME}/                 # User data

Host:
/data/ubuntu-kde-docker_webtop/config/              # Persisted data
/data/ubuntu-kde-docker_webtop/var/log/supervisor/  # Persisted logs
```

## Environment Variables

See `.env.example` for full list. Key variables:
```bash
DEV_USERNAME=devuser
DEV_PASSWORD=DevPassw0rd!
DEV_UID=1000
DEV_GID=1000
DISPLAY=:1
```

## Related Documentation

- [Full README](./README.md)
- [Authentication Guide](./AUTHENTICATION.md)
- [Multi-Container Setup](./MULTI_CONTAINER.md)
- [Audio Diagnostics](./AUDIO_DIAGNOSTICS.md)

---

**Last Updated**: 2025-11-22
EOF

# 2. Link from main README
nano README.md
# Add: - [Quick Reference](./QUICK_REFERENCE.md) - Common commands and troubleshooting
```

---

### Task 7: Update Documentation Index

```bash
cd ubuntu-kde-docker/docs

# 1. Edit README.md
nano README.md

# 2. Ensure all docs are listed
# Structure:
# - Overview
# - Available Documentation (list all .md files)
# - Quick Links (frequently accessed sections)
# - Getting Started (link to setup guide)

# 3. Example structure:
cat > README.md << 'EOF'
# Webtop Omni Desktop - Documentation

## Overview

Complete technical documentation for the webtop-omni-desktop project.

## Available Documentation

### Setup & Configuration
- **[Quick Reference](./QUICK_REFERENCE.md)** - Common commands and quick troubleshooting
- **[Authentication Guide](./AUTHENTICATION.md)** - User management and security setup

### Deployment
- **[Multi-Container Guide](./MULTI_CONTAINER.md)** - Deploy multiple isolated environments

### Troubleshooting
- **[Audio Diagnostics](./AUDIO_DIAGNOSTICS.md)** - Debug audio system issues

### Archive
- **[archive/](./archive/)** - Deprecated documentation (historical reference)

## Quick Links

### First Time Setup
1. [Project README](../../README.md) - Start here
2. [Authentication Setup](./AUTHENTICATION.md#initial-setup) - Configure users
3. [Quick Reference](./QUICK_REFERENCE.md) - Common commands

### Common Tasks
- [Create Container](./MULTI_CONTAINER.md#creating-containers)
- [Backup Container](./QUICK_REFERENCE.md#backup--restore)
- [Troubleshoot Audio](./AUDIO_DIAGNOSTICS.md)
- [Reset Password](./AUTHENTICATION.md#password-management)

### Reference
- [Environment Variables](./QUICK_REFERENCE.md#environment-variables)
- [Service Ports](./QUICK_REFERENCE.md#access-points)
- [File Locations](./QUICK_REFERENCE.md#file-locations)

## Getting Started

New to the project? Follow this path:

```
1. Read: Project README (../../README.md)
   ↓
2. Setup: Initial configuration
   ↓
3. Configure: Authentication (AUTHENTICATION.md)
   ↓
4. Deploy: Start container
   ↓
5. Reference: Quick Reference (QUICK_REFERENCE.md)
```

## Contributing to Documentation

When adding or updating documentation:

1. **Naming**: Use `UPPERCASE_WITH_UNDERSCORES.md`
2. **Structure**: Follow standard sections (Overview, Setup, Troubleshooting, Reference)
3. **Examples**: Include working code examples
4. **Testing**: Verify all commands work
5. **Links**: Use relative links for internal references
6. **Update**: Add entry to this README.md

See [Documentation Standards](../agents.md#local-rules--patterns) for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/MarketingLimited/webtop-omni-desktop/issues)
- **Questions**: Check existing documentation first
- **Contributions**: Pull requests welcome

---

**Last Updated**: 2025-11-22
**Version**: 1.0.0
EOF
```

---

## 8. Notes / Gotchas

### ⚠️ Documentation Maintenance:

#### 1. **Keep Documentation in Sync with Code**
```bash
# When changing code, update docs immediately
# Example: Changed port in docker-compose.yml

# 1. Update code
nano ../docker-compose.yml
# Change: "32768:80" -> "33000:80"

# 2. Update docs
nano QUICK_REFERENCE.md
# Change: default port 32768 -> 33000

nano MULTI_CONTAINER.md
# Update port examples

nano README.md
# Update quick links if needed
```

#### 2. **Command Examples Must Work**
```bash
# Before documenting a command:
# 1. Test it works
docker-compose exec webtop test-command

# 2. Copy EXACT output
# 3. Paste into documentation
# 4. Don't paraphrase - accuracy critical
```

#### 3. **Version-Specific Documentation**
```markdown
<!-- Add version indicators for features -->
**Available in**: v1.0+
**Deprecated in**: v2.0
**Removed in**: v3.0

<!-- Mark breaking changes prominently -->
⚠️ **BREAKING CHANGE (v2.0)**: Description
```

#### 4. **Avoid Duplicating Information**
```markdown
<!-- Bad: Repeat setup steps in multiple docs -->

<!-- Good: Cross-reference -->
For setup instructions, see [Authentication Guide](./AUTHENTICATION.md#setup).
```

#### 5. **External Links Can Break**
```markdown
<!-- Avoid external links when possible -->

<!-- If necessary, add backup info -->
See [Docker Documentation](https://docs.docker.com/compose/)
(Note: As of 2025-11, describes Docker Compose v2)

<!-- Better: Include essential info inline -->
Docker Compose uses YAML format. Example:
```yaml
services:
  web:
    image: nginx
```
```

#### 6. **Screenshots & Diagrams**
```markdown
<!-- This project uses text-only documentation currently -->
<!-- If adding images: -->
1. Create images/ subdirectory
2. Use descriptive filenames: audio-architecture.png
3. Reference: ![Audio Architecture](./images/audio-architecture.png)
4. Always include alt text for accessibility
5. Keep image files small (< 500KB)
```

#### 7. **Code Blocks Must Specify Language**
```markdown
<!-- Bad -->
```
docker-compose up
```

<!-- Good -->
```bash
docker-compose up
```

<!-- Enables syntax highlighting -->
```

#### 8. **Troubleshooting Order**
```markdown
<!-- Structure troubleshooting from simple to complex -->

1. Quick checks (verify service running)
2. Log inspection
3. Configuration validation
4. Restart services
5. Rebuild container (last resort)

<!-- Don't start with "rebuild container" -->
```

#### 9. **Security Sensitive Information**
```markdown
<!-- Never include real passwords -->
❌ DEV_PASSWORD=MyReal_Password123!

<!-- Use obvious placeholders -->
✅ DEV_PASSWORD=DevPassw0rd!  # Example - CHANGE IN PRODUCTION

<!-- Warn about security -->
⚠️ **Security Warning**: Change default passwords before deployment
```

#### 10. **Archive Old Documentation**
```bash
# Don't delete old docs - archive them
cd ubuntu-kde-docker/docs

# Create archive directory if needed
mkdir -p archive

# Move old doc
mv OLD_FEATURE.md archive/OLD_FEATURE.md

# Add note to archived doc
cat > archive/OLD_FEATURE.md.prepend << 'EOF'
⚠️ **ARCHIVED**: This documentation is for webtop-omni-desktop v1.x
This feature was removed in v2.0. Kept for historical reference only.

---

EOF

cat archive/OLD_FEATURE.md >> temp
cat archive/OLD_FEATURE.md.prepend temp > archive/OLD_FEATURE.md
rm temp archive/OLD_FEATURE.md.prepend
```

---

### 📋 Documentation Checklist:

قبل committing documentation changes:

- [ ] **Accuracy**: All commands tested and working
- [ ] **Links**: All internal links verified
- [ ] **Spelling**: No typos (use spellchecker)
- [ ] **Grammar**: Clear and concise language
- [ ] **Formatting**: Consistent markdown style
- [ ] **Examples**: Include working code examples
- [ ] **Timestamps**: "Last Updated" date current
- [ ] **Cross-refs**: Related docs linked
- [ ] **Index**: README.md updated if new doc
- [ ] **Security**: No sensitive info included
- [ ] **Version**: Version-specific info marked

---

## Quick Reference

### Documentation Files:

| File | Purpose | Size |
|------|---------|------|
| `README.md` | Documentation index | ~6KB |
| `AUTHENTICATION.md` | Security & user management | ~12KB |
| `MULTI_CONTAINER.md` | Multi-tenant deployment | ~9KB |
| `AUDIO_DIAGNOSTICS.md` | Audio troubleshooting | ~3KB |
| `archive/` | Deprecated docs | Varies |

### Common Patterns:

```markdown
# File Header
# Title

## Overview
Brief intro

# Command Documentation
### command-name

**Purpose**: What it does

**Syntax**:
```bash
command [options] <arg>
```

**Examples**:
```bash
command example
```

# Troubleshooting Entry
## Problem: Description

**Symptoms**: What you see

**Solution**:
```bash
# Fix steps
command
```

# Cross Reference
See [Other Doc](./OTHER_DOC.md#section).
```

### File Locations:

```
Repository:
/home/user/webtop-omni-desktop/ubuntu-kde-docker/docs/

Access via web:
https://github.com/MarketingLimited/webtop-omni-desktop/tree/main/ubuntu-kde-docker/docs
```

---

**Module Type**: Documentation
**Format**: Markdown (GitHub Flavored)
**Audience**: Developers, DevOps, System Administrators
**Last Updated**: 2025-11-22

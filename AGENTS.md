# AI Agent Guidelines for Project Development

This document provides guidelines for AI agents (like Claude, GitHub Copilot, etc.) working on this project to ensure consistent and high-quality contributions.

## Instruction Prompt Guidelines

- **Character Limit:** Instruction prompts must not exceed 8000 characters
- **Compression:** If a prompt exceeds 8000 characters, compress it and move non-essential commands to separate files
- **Modularity:** Break down complex instructions into focused, single-purpose files

## Project Understanding

### Architecture Overview
- **Frontend:** React + TypeScript + Vite + Tailwind CSS (modern SPA)
- **Backend:** Ubuntu 24.04 Docker container with KDE Plasma desktop
- **Services:** Supervisord-managed service hierarchy
- **Audio:** Web-based audio streaming via WebSocket bridge

### Key Technologies
- Docker & Docker Compose for containerization
- KDE Plasma for desktop environment
- PulseAudio for audio routing
- noVNC for browser-based desktop access
- Node.js for audio bridge
- React for frontend interface

## Documentation Standards

### When Writing Documentation

1. **Be Specific:** Use exact file paths, port numbers, and command syntax
2. **Test Commands:** Ensure all code examples work in the actual environment
3. **Cross-Reference:** Link related documentation with relative paths
4. **Update Index:** Add new docs to `/ubuntu-kde-docker/docs/README.md`

### Documentation Structure

```
/
├── README.md                          # Project overview
├── AGENTS.md                          # This file
└── ubuntu-kde-docker/
    ├── README.md                      # Docker environment guide
    ├── README_AUDIO.md                # Audio system overview
    ├── SERVICES.md                    # Service architecture
    ├── TROUBLESHOOTING.md             # Problem solving
    ├── VALIDATION.md                  # System validation
    └── docs/
        ├── README.md                  # Documentation index
        ├── AUDIO_DIAGNOSTICS.md       # Client-side audio debugging
        ├── AUTHENTICATION.md          # Security guide
        └── MULTI_CONTAINER.md         # Multi-container setup
```

## Code Contribution Guidelines

### Docker & Scripts

- **Bash Scripts:** Follow existing patterns in `/ubuntu-kde-docker/*.sh`
- **Error Handling:** Always include error checking and meaningful messages
- **Permissions:** Ensure scripts are executable (`chmod +x`)
- **Documentation:** Add inline comments for complex logic

### Frontend Development

- **Components:** Use shadcn/ui patterns in `/src/components/`
- **TypeScript:** Maintain strict type safety
- **Styling:** Use Tailwind CSS classes, avoid inline styles
- **State Management:** Use TanStack Query for server state

### Service Configuration

- **Supervisord:** Maintain priority ordering in `supervisord.conf`
- **Dependencies:** Ensure proper service startup sequence
- **Validation:** Add health checks for new services
- **Logging:** Configure appropriate log levels

## Common Patterns

### Multi-Container Support

When adding features that support multi-container deployment:

```bash
# Support both named and traditional containers
CONTAINER_NAME="${1:-webtop-kde}"

# Use registry for tracking
if [ -f ".container-registry.json" ]; then
    # Read from registry
    jq -r ".containers[] | select(.name==\"$CONTAINER_NAME\")" .container-registry.json
fi
```

### Audio System Integration

When working with audio:

- **Use virtual devices:** `virtual_speaker` and `virtual_microphone`
- **Test with validation:** Run `/usr/local/bin/audio-validation.sh`
- **Monitor health:** Integrate with `/usr/local/bin/audio-monitor.sh`
- **Document browser side:** Update `docs/AUDIO_DIAGNOSTICS.md`

### Port Management

When adding services that require ports:

- **Development:** Use ports in 7680+ range for web services
- **SSH:** Use 2222+ range for SSH services
- **VNC:** Use 32768+ range for VNC services
- **Document:** Update port tables in documentation

## Testing Requirements

### Before Committing

1. **Test Builds:** Verify Docker build succeeds
   ```bash
   ./webtop.sh build --dev
   ```

2. **Validate Services:** Ensure all services start
   ```bash
   docker exec webtop-kde /usr/local/bin/system-validation.sh
   ```

3. **Check Documentation:** Verify links work and examples run
   ```bash
   # Test command examples from docs
   ```

4. **Lint Code:** Run appropriate linters
   ```bash
   npm run lint  # For frontend
   shellcheck *.sh  # For shell scripts
   ```

## AI-Specific Guidelines

### For Code Generation

- **Context First:** Review related files before generating code
- **Consistency:** Match existing code style and patterns
- **Dependencies:** Check if required packages/tools are installed
- **Error Cases:** Always handle potential errors gracefully

### For Documentation

- **Accuracy:** Verify technical details against actual implementation
- **Completeness:** Include all parameters, options, and edge cases
- **Examples:** Provide working examples, not pseudocode
- **Links:** Use relative paths for cross-references

### For Troubleshooting

- **Reproduce:** Verify issues exist in current codebase
- **Root Cause:** Identify underlying cause, not just symptoms
- **Test Fix:** Ensure solution works in actual environment
- **Document:** Add solution to TROUBLESHOOTING.md if applicable

## Service Priority Reference

When adding or modifying services in `supervisord.conf`:

| Priority Range | Service Type | Examples |
|----------------|--------------|----------|
| 10-20 | Core Infrastructure | Xvfb, D-Bus |
| 22-30 | Audio System | PulseAudio, AudioValidation |
| 35 | Desktop Environment | KDE Plasma |
| 40-50 | Remote Access | X11VNC, noVNC, SSH, TTYD |
| 52-60 | Monitoring | ServiceHealth, SystemValidation |

## Environment-Specific Behavior

### Development vs Production

```bash
# Check environment
if [ -f ".env" ]; then
    source .env
    if [ "$ENVIRONMENT" = "production" ]; then
        # Production-specific behavior
    else
        # Development-specific behavior
    fi
fi
```

### Feature Flags

- Use environment variables for optional features
- Document in `.env.example`
- Provide sensible defaults
- Test both enabled and disabled states

## Version Control

### Commit Messages

Follow conventional commits format:

```
feat: add multi-container backup functionality
fix: resolve audio routing issue on container restart
docs: update authentication guide with SSL examples
chore: update dependencies to latest stable versions
```

### Branch Naming

- `feature/short-description` - New features
- `fix/issue-description` - Bug fixes
- `docs/what-changed` - Documentation updates
- `chore/maintenance-task` - Maintenance tasks

## Resources

### Documentation
- [Docker Docs](https://docs.docker.com/)
- [KDE Plasma](https://kde.org/plasma-desktop/)
- [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/)
- [Supervisord](http://supervisord.org/)

### Project-Specific
- [Main README](README.md) - Project overview
- [Service Architecture](ubuntu-kde-docker/SERVICES.md) - Service details
- [Documentation Index](ubuntu-kde-docker/docs/README.md) - All documentation

---

## Summary for AI Agents

1. ✅ **Keep prompts under 8000 characters**
2. ✅ **Test all code and documentation examples**
3. ✅ **Follow existing patterns and conventions**
4. ✅ **Update documentation index when adding docs**
5. ✅ **Validate changes with system-validation.sh**
6. ✅ **Use relative paths for cross-references**
7. ✅ **Support both single and multi-container modes**
8. ✅ **Document environment-specific behavior**

---

**Last Updated:** 2025-11-22
**Version:** 2.0 (Expanded from minimal guidelines)

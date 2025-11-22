# webtop-omni-desktop - Root Agent Guide

## 1. Purpose (الغرض)

**webtop-omni-desktop** هو مشروع hybrid يوفر بيئة desktop كاملة (Ubuntu 24.04 + KDE Plasma) قابلة للوصول عبر المتصفح، مع صفحة landing توثيقية مبنية بـ React. المشروع مصمم لـ marketing agencies لتوفير بيئات عمل معزولة لعدة clients.

**المكونات الرئيسية**:
- **Frontend**: React landing page (static documentation)
- **Backend**: Full KDE desktop في Docker container مع 50+ أداة مثبتة مسبقاً
- **Audio System**: Real-time audio streaming عبر WebSocket
- **Management Tools**: CLI لإدارة multiple containers

---

## 2. Owned Scope (النطاق المملوك)

### Root-level Files & Configs:
- `package.json` - Frontend dependencies و build scripts
- `vite.config.ts` - Vite build configuration
- `tailwind.config.ts` - Tailwind CSS styling
- `tsconfig.json` - TypeScript compiler settings
- `eslint.config.js` - Code linting rules
- `components.json` - Shadcn UI configuration
- `index.html` - HTML entry point
- `.gitignore`, `.npmrc` - Git & NPM configs

### Documentation:
- `README.md` - Main project documentation
- `AGENTS.md` - AI agent development guidelines
- `DOCUMENTATION_AUDIT_REPORT.md` - Documentation audit
- `DOCUMENTATION_RESTRUCTURE_SUMMARY.md` - Restructure notes

### Build Artifacts (لا تُعدَّل):
- `dist/` - Production build output
- `node_modules/` - NPM dependencies

---

## 3. Key Files & Entry Points

### Frontend Entry Points:
```
index.html                    # HTML entry
  ↓
src/main.tsx                 # JavaScript entry (React root)
  ↓
src/App.tsx                  # Application root (routing + providers)
  ↓
src/pages/Index.tsx          # Landing page
```

### Container Entry Point:
```
ubuntu-kde-docker/docker-compose.yml    # Container definition
  ↓
ubuntu-kde-docker/Dockerfile           # Image build
  ↓
ubuntu-kde-docker/entrypoint.sh        # Container startup
  ↓
ubuntu-kde-docker/supervisord.conf     # Process management
```

### Build Commands:
```bash
# Frontend development
npm run dev              # Start Vite dev server (port 8080)
npm run build            # Production build → dist/
npm run preview          # Preview production build
npm run lint             # Run ESLint

# Container operations
cd ubuntu-kde-docker
docker-compose up -d     # Start container
docker-compose down      # Stop container
./webtop.sh status       # Check container status
```

---

## 4. Dependencies & Interfaces

### Frontend Dependencies:
- **Runtime**: Node.js 22+ (للـ development)
- **Browser**: Modern browsers (Chrome, Firefox, Safari)
- **Build**: Vite 5.4.1
- **Framework**: React 18.3.1 + TypeScript 5.5.3

### Container Dependencies:
- **Docker**: Docker Engine 20.10+
- **Docker Compose**: v2.0+
- **Ports**: 32768 (noVNC), 2222 (SSH), 7681 (TTYD), 8080 (Audio), 4713 (PulseAudio)
- **Storage**: `/data/` directory للـ volumes

### Module Interfaces:
```
┌─────────────┐
│   Frontend  │  Static HTML/CSS/JS → Hosted on Lovable
│  (src/)     │  No API calls to container
└─────────────┘

┌─────────────┐
│  Container  │  Browser → noVNC (HTTP) → VNC Server → Desktop
│ (ubuntu-    │  Browser → WebSocket → Audio Bridge → PulseAudio
│  kde-docker)│  SSH → Port 2222 → OpenSSH Server
└─────────────┘
```

**ملاحظة**: Frontend و Container منفصلان تماماً - لا يوجد API communication بينهما.

---

## 5. Local Rules / Patterns

### Project Structure Rules:
1. **Frontend code** يجب أن يكون في `/src/` فقط
2. **Container code** يجب أن يكون في `/ubuntu-kde-docker/` فقط
3. **Shared documentation** في الـ root
4. **Technical docs** في `/ubuntu-kde-docker/docs/`

### Development Workflow:
```bash
# 1. Frontend development
npm install              # Install dependencies
npm run dev              # Start dev server
# Edit files in src/
npm run build            # Build for production

# 2. Container development
cd ubuntu-kde-docker
# Edit Dockerfile or scripts
docker-compose build     # Rebuild image
docker-compose up -d     # Start container
# Test via browser: http://localhost:32768
```

### Git Workflow:
- **Branch naming**: `claude/<task-name>-<session-id>`
- **Commits**: واضحة ومفصلة
- **Push**: `git push -u origin <branch-name>` (retry على network errors)

---

## 6. How to Run / Test

### Quick Start:

#### Frontend:
```bash
# Development
npm install
npm run dev
# Open: http://localhost:8080

# Production build
npm run build
npm run preview
```

#### Container:
```bash
cd ubuntu-kde-docker

# Copy environment template
cp .env.example .env
# Edit .env with your passwords

# Start container
docker-compose up -d

# Check status
docker-compose ps
./webtop.sh status

# Access:
# - noVNC: http://localhost:32768
# - SSH: ssh devuser@localhost -p 2222
# - TTYD: http://localhost:7681

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Testing:
```bash
# Frontend linting
npm run lint

# Container health check
cd ubuntu-kde-docker
docker-compose exec webtop /opt/diagnostic-script.sh
```

---

## 7. Common Tasks for Agents

### Task 1: تعديل Frontend Design
```bash
# 1. Edit components in src/components/
# 2. Test changes
npm run dev
# 3. Build
npm run build
```

### Task 2: إضافة أداة جديدة للـ Container
```bash
cd ubuntu-kde-docker
# 1. Create setup script: setup-<tool-name>.sh
# 2. Add to Dockerfile (RUN statement)
# 3. Rebuild
docker-compose build
docker-compose up -d
```

### Task 3: تعديل Audio Configuration
```bash
cd ubuntu-kde-docker
# 1. Edit setup-audio-bridge.sh
# 2. Rebuild container
docker-compose build
# 3. Test audio
# Browser console: Check WebSocket connection
```

### Task 4: إضافة Environment Variable جديدة
```bash
cd ubuntu-kde-docker
# 1. Add to .env.example with comment
# 2. Add to docker-compose.yml (environment section)
# 3. Add to entrypoint.sh (if needed for startup logic)
# 4. Document in docs/
```

### Task 5: Multi-Container Setup
```bash
cd ubuntu-kde-docker
# 1. Use management CLI
./webtop.sh create-container client-name
# 2. Configure ports
# 3. Start
./webtop.sh start client-name
```

### Task 6: Backup/Restore
```bash
cd ubuntu-kde-docker
# Backup
./webtop.sh backup container-name /path/to/backup.tar.gz

# Restore
./webtop.sh restore container-name /path/to/backup.tar.gz
```

---

## 8. Notes / Gotchas

### ⚠️ Important Notes:

1. **Frontend لا يتصل بـ Container**:
   - الـ landing page هي static documentation فقط
   - لا توجد API calls بين Frontend و Container
   - كل واحد يُنشر بشكل مستقل

2. **Port Conflicts**:
   - Default ports (32768, 2222, etc.) قد تكون مستخدمة
   - لـ multiple containers: استخدم `./webtop.sh` لإدارة الـ ports تلقائياً

3. **Container Size**:
   - الـ image كبير جداً (~several GB)
   - أول build يأخذ 20-30 دقيقة
   - استخدم Docker layer caching

4. **Audio System**:
   - يحتاج WebSocket connection من Browser
   - PulseAudio يجب أن يعمل قبل Audio Bridge
   - راجع supervisord priorities (20-26 للـ audio)

5. **Development vs Production**:
   - `docker-compose.dev.yml` يحتوي على Redis + PostgreSQL
   - `docker-compose.yml` (default) بدون database
   - Use: `docker-compose -f docker-compose.dev.yml up -d`

6. **Permissions Issues**:
   - Container يحتاج `SYS_ADMIN` و `NET_ADMIN` capabilities
   - User IDs (DEV_UID/DEV_GID) يجب أن تتطابق مع host للـ volume permissions

7. **Authentication**:
   - غيّر الـ passwords في `.env` قبل production!
   - Default passwords في `.env.example` للـ development فقط

8. **Security**:
   - Container يعمل بـ `seccomp:unconfined`
   - لا تعرض الـ ports مباشرة للإنترنت
   - استخدم reverse proxy (nginx) مع SSL

---

## Agent Map (خريطة الـ Agents)

```
agents.md (ROOT)
├── Purpose: Project overview & orchestration
├── Agents للمهام الشاملة التي تشمل multiple modules
└── References:
    │
    ├── src/agents.md (FRONTEND)
    │   ├── Purpose: React landing page development
    │   ├── Tasks: UI/UX, components, styling, routing
    │   └── Independent من Container
    │
    ├── ubuntu-kde-docker/agents.md (CONTAINER)
    │   ├── Purpose: Desktop environment, audio, scripts, CLI
    │   ├── Tasks: Container setup, tool installation, audio config
    │   └── Sub-systems: Supervisord, Audio Bridge, Management CLI
    │
    └── ubuntu-kde-docker/docs/agents.md (DOCUMENTATION)
        ├── Purpose: Technical documentation maintenance
        └── Tasks: Update guides, troubleshooting, architecture docs
```

### متى تستخدم أي agent:

- **Root Agent** (هذا الملف): للمهام التي تشمل coordination بين modules أو setup أولي
- **Frontend Agent**: لأي شيء في `src/` - UI, components, styling, routing
- **Container Agent**: لأي شيء في `ubuntu-kde-docker/` - Docker, scripts, audio, tools
- **Docs Agent**: لتحديث أو إضافة documentation

---

## Quick Reference Card

| Task | Command | Location |
|------|---------|----------|
| Start frontend dev | `npm run dev` | Root |
| Build frontend | `npm run build` | Root |
| Start container | `docker-compose up -d` | ubuntu-kde-docker/ |
| Container logs | `docker-compose logs -f` | ubuntu-kde-docker/ |
| Health check | `./webtop.sh status` | ubuntu-kde-docker/ |
| Access desktop | Browser: `http://localhost:32768` | - |
| SSH access | `ssh devuser@localhost -p 2222` | - |
| Multi-container | `./webtop.sh create-container <name>` | ubuntu-kde-docker/ |

---

## External Resources

- **GitHub**: Current repository
- **Lovable Platform**: https://lovable.dev (deployment)
- **Documentation**: `/ubuntu-kde-docker/docs/` directory
- **Issue Tracking**: GitHub Issues

---

**Last Updated**: 2025-11-22
**Version**: 1.0.0
**Maintained By**: AI Agents following this guide

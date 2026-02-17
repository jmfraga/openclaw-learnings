# Memory Management System

## 🎯 Problem

OpenClaw agents accumulate large memory files (MEMORY.md, daily logs) that eventually exceed LLM context windows, causing:
- Read tool errors and truncation
- Session startup failures
- Performance degradation
- Memory bloat over time

## 💡 Solution

Automated memory lifecycle management system using Git hooks and scheduled audits:

### Components

1. **Pre-commit hook** - Validates memory size before each commit
2. **Memory audit** - Daily scheduled check of memory health
3. **Incident rotation** - Archives old incidents to prevent accumulation
4. **Documentation** - Deployment guides and quick references

### Key Features

- ✅ Prevents commits when MEMORY.md > 30KB
- ✅ Daily automated audits via cron
- ✅ Automatic incident archival (>30 days old)
- ✅ Detailed logging and notifications
- ✅ Graceful degradation (warnings vs hard blocks)

## 📦 Installation

See [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) for step-by-step setup.

**Quick install:**

```bash
# 1. Copy hooks to workspace
cp scripts/*.sh ~/.openclaw/workspace-<agent>/.openclaw/hooks/
chmod +x ~/.openclaw/workspace-<agent>/.openclaw/hooks/*.sh

# 2. Test pre-commit hook
cd ~/.openclaw/workspace-<agent>
./.openclaw/hooks/pre-commit-memory-check.sh

# 3. Schedule daily audit (add to crontab)
0 8 * * * ~/.openclaw/workspace-<agent>/.openclaw/hooks/audit-memory-size.sh
```

## 🚀 Usage

### Pre-commit Check
Runs automatically on `git commit`. Validates:
- MEMORY.md size (hard limit: 30KB)
- Daily log accumulation
- Memory directory structure

### Daily Audit
Runs via cron, checks:
- All memory files in workspace
- Sends Telegram alerts for violations
- Logs detailed metrics

### Incident Rotation
Archives incidents older than 30 days to:
```
workspace/memory/incidents/archive/YYYY-MM/
```

## 📚 Documentation

- **[DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md)** - Complete installation and configuration
- **[QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)** - Command reference and troubleshooting
- **[TASK-027-COMPLETION-REPORT.md](docs/TASK-027-COMPLETION-REPORT.md)** - Original implementation report
- **[memory/](docs/memory/)** - Design docs and historical context

## 🔧 Configuration

Edit thresholds in scripts:
- `MAX_SIZE_KB=30` - MEMORY.md hard limit
- `MAX_DAILY_FILES=60` - Daily log retention
- `INCIDENT_RETENTION_DAYS=30` - Incident archive threshold

## 🎓 Lessons Learned

1. **Proactive > Reactive** - Catch memory bloat before it breaks sessions
2. **Graceful limits** - Warnings for daily logs, hard blocks for MEMORY.md
3. **Transparency** - Detailed logging helps debug edge cases
4. **Automation** - Git hooks + cron = zero-touch maintenance

## 📊 Metrics

Average impact after deployment:
- 🔽 MEMORY.md size reduced by ~40%
- ✅ Zero read tool errors from memory files
- ⚡ Session startup time improved
- 🗂️ Incidents properly archived

## 🔗 Related

- Update Dashboard (../update-dashboard) - Visualizes system health
- QA Dashboard (../qa-dashboard-kanban) - Monitors agent quality metrics

---

**Status:** ✅ Production-ready  
**Last Updated:** 2026-02-17  
**Maintainer:** CHAPPiE

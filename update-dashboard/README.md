# Update Dashboard

## 🎯 Problem

Updating OpenClaw on a production system is risky — a bad config key or failed npm update can crash-loop the gateway. Need a safe, controlled update workflow with guardrails.

## 💡 Solution

Web dashboard with PIN authentication, pre-flight checks, full backups, dry-run simulation, and rollback — all from a single page.

### Features

- 🔐 **PIN Authentication** — 4-digit PIN required for all destructive operations
- 🔒 **Operation Mutex** — Prevents simultaneous updates/backups/rollbacks (10min auto-timeout)
- 📦 **Full Backup** — Tarballs with config, credentials, SOULs, IDENTITYs, MEMORYs, USERs, TOOLs
- ✅ **8 Pre-flight Checks** — Disk, permissions, git, gateway, active sessions, recent backup, memory, CPU
- 🧪 **Dry-run Mode** — Simulate update without executing
- ↩️ **One-click Rollback** — Restore from latest backup (supports both .json and .tar.gz)
- 📜 **Log Viewer** — Per-operation logs (backup, update, verify)
- 🎨 **Clean UI** — Responsive, dark theme, no external dependencies

## 📦 Installation

### Prerequisites
- OpenClaw Gateway running
- Hub server (Node.js) serving static files

### Setup

1. Copy files to your hub:
```bash
mkdir -p ~/.openclaw/workspace-pm/hub/update
cp index.html ~/.openclaw/workspace-pm/hub/update/
```

2. Add server handlers to your hub's `server.js`:
   - See `server-handlers.js` for the backend functions
   - Set your PIN: `const UPDATE_PIN = '1234';` (change this!)
   - Wire up routes for `/api/update/*`

3. Access at: `http://your-host:8080/update/`

## 🔒 Security Model

### PIN Authentication
- All `/api/update/*` endpoints (except `/status`) require `X-Update-Pin` header
- PIN stored server-side in `server.js` (not in frontend)
- Frontend stores PIN in `sessionStorage` (cleared on tab close)
- "Cerrar sesión" button clears PIN manually
- Default example PIN: `1234` — **change it!**

### Operation Locking
- Only one destructive operation at a time (backup/update/verify/rollback)
- Lock auto-releases after 10 minutes (safety timeout)
- Returns 409 if another operation is in progress

### What's NOT protected
- `/api/update/status` is read-only, no PIN required
- The dashboard itself (HTML) has no auth — consider network-level protection (Tailscale, etc.)

## ✅ Pre-flight Checks (8 total)

| Check | Pass | Warning | Fail |
|-------|------|---------|------|
| Disk Space | <90% | 90-95% | >95% |
| Write Permissions | Can write to .openclaw | — | Can't write |
| Git Status | Clean or not a repo | Uncommitted changes | — |
| Gateway Running | Active (systemctl) | Not running | — |
| Active Sessions | 0 sessions | >0 sessions | — |
| Recent Backup | <1 hour old | >1 hour or none | — |
| Memory | >500MB free | — | <500MB |
| CPU Load | Load < CPU count | Load > CPU count | — |

## 📦 Backup Contents

The backup creates a tarball (`openclaw-backup-TIMESTAMP.tar.gz`) containing:

```
openclaw.json          # Main config
credentials/           # API keys, tokens
workspace-*/SOUL.md    # Agent personalities
workspace-*/IDENTITY.md # Agent metadata
workspace-*/MEMORY.md  # Long-term memory
workspace-*/USER.md    # User context
workspace-*/TOOLS.md   # Tool notes
```

## 🧪 Dry-run Mode

Check "🧪 Dry Run (simular)" in the update confirmation modal to:
- Check current vs latest version
- **NOT** run `npm update`
- **NOT** restart the gateway
- See what would happen without risk

## 🔧 Configuration

In `server.js`:
```javascript
const UPDATE_PIN = '1234';          // Change this!
const LOCK_TIMEOUT = 10 * 60 * 1000; // 10 min auto-release
```

## 🎓 Lessons Learned

1. **Zod .strict() kills** — OpenClaw's gateway validates config with Zod strict mode. Unknown keys = crash loop. Never add keys without checking the schema first.
2. **Backup everything** — Config-only backups are insufficient. SOULs, credentials, and memory files are equally critical.
3. **Lock destructive ops** — Users click buttons twice. Concurrent updates = chaos.
4. **PIN > no auth** — Even on a private network, accidental clicks happen. A simple PIN prevents disasters.
5. **Dry-run saves lives** — Always test before applying.

## 🐛 Troubleshooting

**Dashboard shows "PIN requerido" on every action:**
- Enter your PIN in the modal, or check `UPDATE_PIN` in server.js

**Backup is only 8KB:**
- You're creating .json backups (old behavior). The new tarball should be ~2MB+.

**Lock stuck / 409 errors:**
- Lock auto-releases after 10 minutes. Or restart the hub server.

**Update crash-loops the gateway:**
- Use the Rollback button, or manually: `systemctl --user restart oc-gw.service`
- If config is broken, restore from backup tarball: `tar xzf backup.tar.gz -C ~/.openclaw`

## 📈 Future Ideas

- [ ] Changelog viewer (show what's new before updating)
- [ ] Scheduled updates (cron integration)
- [ ] Multi-step update wizard
- [ ] Email/Telegram notification on update completion
- [ ] Config schema validation before restart

---

**Status:** ✅ Production-ready  
**Last Updated:** 2026-02-23  
**Maintainers:** CHAPPiE (original), Odin (security hardening)

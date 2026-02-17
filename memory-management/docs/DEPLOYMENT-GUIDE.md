# MEMORY.md Maintenance System - Deployment Guide

**Version:** 1.0  
**Created:** 2026-02-16  
**Status:** ✅ Ready for deployment

## Executive Summary

This system prevents MEMORY.md from exceeding 4KB (which causes read tool truncation errors) through a hybrid approach:

1. **Documentation** - Clear guidelines for what goes in MEMORY.md vs memory/
2. **Automation** - Monthly rotation of incidents section
3. **Monitoring** - Weekly size audits with Kanban task creation
4. **Enforcement** - Optional pre-commit hook for git validation

**Expected Outcome:** MEMORY.md stays <3.5KB indefinitely with minimal manual intervention.

## What's Been Delivered

### 📄 Documentation
- ✅ `memory/memory-maintenance-system.md` - System overview
- ✅ `memory/AGENTS.md-additions.md` - Guidelines for AGENTS.md
- ✅ `memory/MEMORY.md-template.md` - Structured template with size targets

### 🤖 Automation Scripts
- ✅ `.openclaw/hooks/rotate-incidents.sh` - Monthly rotation (cron: 1st of month)
- ✅ `.openclaw/hooks/audit-memory-size.sh` - Weekly audit (cron: Sundays 8 AM)
- ✅ `.openclaw/hooks/pre-commit-memory-check.sh` - Git hook (optional)

### 📁 Directory Structure
```
workspace-chappie/
├── MEMORY.md                          # Main memory file (keep <3.5KB)
├── DEPLOYMENT-GUIDE.md                # This file
├── memory/
│   ├── incidents/                     # ← NEW: Archived incidents
│   ├── projects/                      # ← RECOMMENDED: Project-specific details
│   ├── AGENTS.md-additions.md         # Documentation to merge
│   ├── MEMORY.md-template.md          # Template for reference
│   └── memory-maintenance-system.md   # System design doc
└── .openclaw/
    └── hooks/                         # ← NEW: Automation scripts
        ├── rotate-incidents.sh
        ├── audit-memory-size.sh
        └── pre-commit-memory-check.sh
```

## Deployment Steps

### Phase 1: Documentation (Immediate - 5 min)

**1.1. Update AGENTS.md**

```bash
# Review the additions
cat memory/AGENTS.md-additions.md

# Manually merge the "MEMORY.md Size Management" section into AGENTS.md
# Insert after the existing "Memory" section
nano AGENTS.md  # or your preferred editor
```

**1.2. Create MEMORY.md (if it doesn't exist)**

```bash
# Option A: Use the template
cp memory/MEMORY.md-template.md MEMORY.md
# Then customize with actual content

# Option B: Create from scratch following template structure
nano MEMORY.md
```

**1.3. Commit documentation**

```bash
git add AGENTS.md MEMORY.md memory/*.md .openclaw/
git commit -m "docs: add MEMORY.md maintenance system"
git push
```

### Phase 2: Automation Setup (Week 2 - 10 min)

**2.1. Test rotation script**

```bash
# Dry run to verify it works
.openclaw/hooks/rotate-incidents.sh

# Check outputs
ls -lh memory/incidents/
cat memory/.rotation.log
```

**2.2. Test audit script**

```bash
# Run audit manually
.openclaw/hooks/audit-memory-size.sh

# Check outputs
cat memory/.audit.log
cat memory/.size-alert.txt  # If threshold exceeded
```

**2.3. Install cron jobs**

For **Argus** (runs on host, has cron access):

```bash
# Edit crontab
crontab -e

# Add these lines:
# Monthly incident rotation - 2 AM on 1st of month
0 2 1 * * /home/jmfraga/.openclaw/workspace-chappie/.openclaw/hooks/rotate-incidents.sh

# Weekly size audit - 8 AM every Sunday
0 8 * * 0 /home/jmfraga/.openclaw/workspace-chappie/.openclaw/hooks/audit-memory-size.sh

# Save and exit
```

**Alternative:** Use OpenClaw's built-in cron (if available):

```bash
# Check if OpenClaw has cron support
openclaw cron --help

# Add jobs via OpenClaw (adjust syntax as needed)
openclaw cron add "0 2 1 * *" ".openclaw/hooks/rotate-incidents.sh" --label "memory-rotation"
openclaw cron add "0 8 * * 0" ".openclaw/hooks/audit-memory-size.sh" --label "memory-audit"
```

**2.4. Verify cron setup**

```bash
# List cron jobs
crontab -l

# Wait for next run, or force manually:
.openclaw/hooks/rotate-incidents.sh  # Test rotation
.openclaw/hooks/audit-memory-size.sh  # Test audit
```

### Phase 3: Git Hook (Week 3 - Optional - 2 min)

**3.1. Install pre-commit hook**

```bash
# Navigate to workspace
cd /home/jmfraga/.openclaw/workspace-chappie

# Link the script
ln -sf ../../.openclaw/hooks/pre-commit-memory-check.sh .git/hooks/pre-commit

# Verify
ls -lh .git/hooks/pre-commit
```

**3.2. Test the hook**

```bash
# Make a test commit with oversized MEMORY.md
echo "# Test bloat" >> MEMORY.md
git add MEMORY.md
git commit -m "test: verify pre-commit hook"

# If MEMORY.md >3.5KB, you should see a warning
# If >4KB, commit will be blocked
```

**3.3. Remove hook if not wanted**

```bash
rm .git/hooks/pre-commit
```

## Verification Checklist

After deployment, verify:

- [ ] AGENTS.md has new "MEMORY.md Size Management" section
- [ ] MEMORY.md exists and is <3.5KB
- [ ] `memory/incidents/` directory created
- [ ] Rotation script runs without errors
- [ ] Audit script runs without errors
- [ ] Cron jobs installed (check `crontab -l`)
- [ ] Optional: Pre-commit hook linked (check `.git/hooks/`)
- [ ] Scripts have execute permissions (`ls -l .openclaw/hooks/`)

## Usage Guide

### For Agents (Chappie, PM, etc.)

**When writing to MEMORY.md:**

1. Check current size: `wc -c MEMORY.md` (should be <3584 bytes)
2. Follow guidelines in AGENTS.md → "MEMORY.md Size Management"
3. Use one-liners with links to `memory/` subdirectories
4. Update existing entries instead of appending
5. Let automation handle incidents rotation

**When MEMORY.md grows >3.5KB:**

- You'll receive a Kanban task from audit script
- Review section breakdown in task description
- Move content to appropriate `memory/` subdirectories:
  - Incidents → `memory/incidents/`
  - Projects → `memory/projects/`
  - Old learnings → Distill to Core Identity or archive
- Update MEMORY.md with links to moved content

### For PM (Manual Cleanup)

When you receive a cleanup task:

```bash
# 1. Check current state
wc -c MEMORY.md
cat memory/.size-alert.txt  # See section breakdown

# 2. Review sections
nano MEMORY.md

# 3. Move content to archives
# Example: Move project details
mkdir -p memory/projects
mv [content] memory/projects/dashboard-v3.md
# Update MEMORY.md with link

# 4. Verify size
wc -c MEMORY.md  # Target: <3000 bytes

# 5. Commit
git add MEMORY.md memory/projects/
git commit -m "chore: prune MEMORY.md (3.8KB → 2.9KB)"
git push
```

## Monitoring

### Logs to Check

```bash
# Rotation logs
tail -f memory/.rotation.log

# Audit logs
tail -f memory/.audit.log

# Size alerts
cat memory/.size-alert.txt
```

### Monthly Review (1st of month)

```bash
# After rotation runs, verify:
ls -lh memory/incidents/  # New archive created
wc -c MEMORY.md            # Size should drop
git log --oneline -1       # Auto-commit present
```

### Weekly Review (Sundays)

```bash
# After audit runs:
cat memory/.audit.log      # Check last audit
cat memory/.size-alert.txt # Any alerts?
```

## Troubleshooting

### Script fails with "MEMORY.md not found"
**Solution:** Create MEMORY.md using template (Phase 1)

### Cron jobs not running
**Check:**
```bash
# Is cron running?
systemctl status cron  # or "crond" on some systems

# Are paths absolute?
crontab -l  # Verify paths are correct

# Check cron logs
grep CRON /var/log/syslog
```

### Rotation doesn't find "## Incidents" section
**Solution:** Ensure MEMORY.md has `## Incidents` header (case-sensitive)

### Pre-commit hook doesn't trigger
**Check:**
```bash
# Is it executable?
chmod +x .git/hooks/pre-commit

# Is it linked correctly?
ls -lh .git/hooks/pre-commit
```

### Kanban task not created
**Check:**
```bash
# Is openclaw CLI available?
which openclaw

# Test message manually:
openclaw message agent:pm:telegram:default:direct:1074136117 "Test message"
```

## Maintenance

### Quarterly Tasks (Manual)

1. **Distill learnings:** Review "Recent Learnings" in MEMORY.md, consolidate to "Core Identity"
2. **Archive review:** Check `memory/incidents/` archives, consolidate if needed
3. **Size check:** Verify MEMORY.md trend (should stay <3KB)

### Annual Tasks

1. **Archive consolidation:** Merge old incident archives into yearly files
2. **System review:** Update automation scripts if needed
3. **Documentation update:** Refresh AGENTS.md guidelines based on learnings

## Success Metrics

Track these over time:

- **MEMORY.md size:** Should stay <3.5KB consistently
- **Truncation errors:** Should be zero
- **Cleanup tasks:** <1 per quarter (ideally zero)
- **Archive growth:** Steady, manageable growth in `memory/incidents/`

## Rollback Plan

If the system causes issues:

```bash
# 1. Disable cron jobs
crontab -e  # Comment out or remove lines

# 2. Remove pre-commit hook
rm .git/hooks/pre-commit

# 3. Keep manual control
# Continue using MEMORY.md manually, reference memory/ as needed
```

## Next Steps

1. **This week:** Deploy Phase 1 (documentation)
2. **Next week:** Deploy Phase 2 (automation + cron)
3. **Week 3:** Optional Phase 3 (git hook)
4. **Month 1:** Monitor, tune thresholds if needed
5. **Month 3:** First quarterly review

## Support

For issues or improvements:
- Check logs: `memory/.rotation.log`, `memory/.audit.log`
- Review design: `memory/memory-maintenance-system.md`
- Update scripts: `.openclaw/hooks/`

---

**Status:** ✅ System ready for deployment  
**Next Action:** PM to deploy Phase 1 (update AGENTS.md, create MEMORY.md)

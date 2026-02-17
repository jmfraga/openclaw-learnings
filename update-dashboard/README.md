# Update Dashboard

## 🎯 Problem

Need real-time visibility of OpenClaw system updates and agent status across multiple workspaces:
- Which agents are running latest code?
- When was each workspace last synced?
- Are there pending updates or conflicts?

## 💡 Solution

Single-page dashboard that aggregates update status from all OpenClaw workspaces.

### Features

- 📊 **System Overview** - Git status for all agents
- 🔄 **Update Timeline** - Last sync timestamps
- ⚠️ **Conflict Detection** - Highlights repos needing attention
- 🎨 **Clean UI** - Responsive, no external dependencies
- 🔒 **Local-only** - No external API calls, privacy-first

## 📦 Installation

### Prerequisites
- OpenClaw Gateway running
- Agent workspaces in `~/.openclaw/workspace-*`

### Setup

1. Copy dashboard to hub directory:
```bash
mkdir -p ~/.openclaw/hub/update
cp index.html ~/.openclaw/hub/update/
```

2. Serve via Gateway (auto-detected) or local HTTP server:
```bash
# Option A: Gateway serves it automatically
# Access at: http://localhost:3000/hub/update/

# Option B: Standalone server
cd ~/.openclaw/hub/update
python3 -m http.server 8080
# Access at: http://localhost:8080
```

## 🚀 Usage

### Access Dashboard
Open in browser:
- **Via Gateway:** `http://localhost:3000/hub/update/`
- **Standalone:** `http://localhost:8080`

### Understand Status Icons

| Icon | Meaning |
|------|---------|
| ✅ | Up to date, clean working tree |
| 🔄 | Updates available (can pull) |
| ⚠️ | Conflicts or uncommitted changes |
| ❌ | Git error or repo not initialized |

### Manual Refresh
Dashboard auto-refreshes every 30 seconds. Click **Refresh Now** for immediate update.

## 🔧 Customization

Edit `index.html` to adjust:

```javascript
// Refresh interval (milliseconds)
const REFRESH_INTERVAL = 30000; // 30 seconds

// Workspaces to monitor (auto-detected by default)
const WORKSPACES = [
  'workspace-chappie',
  'workspace-pm',
  'workspace-argus',
  // ... add more
];
```

## 📊 Data Sources

Dashboard reads from:
```bash
~/.openclaw/workspace-*/
  ├── .git/         # Git status
  └── .openclaw/    # Agent metadata
```

Executes commands:
- `git status --porcelain`
- `git log -1 --format=%ct`
- `git rev-list --count HEAD ^origin/main`

## 🎓 Lessons Learned

1. **Keep it simple** - Single HTML file = easy deployment
2. **No backend needed** - Client-side git checks via Gateway API
3. **Fail gracefully** - Show partial data if some repos error
4. **Visual clarity** - Color-coded status beats text logs

## 🔗 Integration

Works with:
- **Memory Management** (../memory-management) - Shows if memory hooks are active
- **QA Dashboard** (../qa-dashboard-kanban) - Links to quality metrics

Can trigger:
- Automated update scripts
- Slack/Telegram notifications
- CI/CD pipelines

## 🐛 Troubleshooting

**Dashboard shows all ❌:**
- Check Gateway is running: `openclaw gateway status`
- Verify workspaces exist: `ls ~/.openclaw/workspace-*`

**Status stuck on 🔄:**
- Pull updates manually: `cd workspace-X && git pull`
- Check for merge conflicts

**Auto-refresh not working:**
- Check browser console for errors
- Ensure Gateway API is accessible

## 📈 Future Ideas

- [ ] Add "Pull All" button
- [ ] Show diff preview for pending updates
- [ ] Notification badge in browser tab
- [ ] Export status as JSON for automation

---

**Status:** ✅ Production-ready  
**Last Updated:** 2026-02-17  
**Maintainer:** PM Agent  
**Live Demo:** Coming soon

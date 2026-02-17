# QA Dashboard + Kanban

## 🎯 Problem

Managing agent quality and task tracking requires:
- Real-time quality metrics (token usage, error rates, audit stats)
- Visual task management across agents
- Integration between quality monitoring and workflow
- Historical trend analysis

## 💡 Solution

Integrated system combining:
1. **QA Dashboard** - Real-time quality metrics visualization
2. **Kanban Board** - Visual task management for agents
3. **Data Collection Scripts** - Automated metric gathering

### Architecture

```
qa-dashboard-kanban/
├── dashboard/          # QA metrics visualization
│   ├── index.html     # Main dashboard UI
│   ├── server.py      # Python HTTP server with CORS
│   └── server.sh      # Launcher script
├── kanban/            # Task management interface
│   ├── dashboard/     # Kanban UI
│   ├── data/          # Task and metrics storage
│   └── scripts/       # Data management utilities
└── scripts/           # Metric collection
    ├── update-audit-stats.sh
    └── update-token-usage.sh
```

## 📦 Installation

### Prerequisites
- Python 3.x
- Bash
- OpenClaw Gateway running
- Agent workspaces with logs

### Setup QA Dashboard

```bash
# 1. Copy dashboard files
mkdir -p ~/.openclaw/hub/qa
cp dashboard/* ~/.openclaw/hub/qa/

# 2. Start server
cd ~/.openclaw/hub/qa
./server.sh
# Accessible at: http://localhost:8001
```

### Setup Kanban

```bash
# 1. Copy kanban files
mkdir -p ~/.openclaw/kanban-qa
cp -r kanban/* ~/.openclaw/kanban-qa/

# 2. Initialize data structure
cd ~/.openclaw/kanban-qa
mkdir -p data/{backups,chappie-tasks,pm-tasks,samples}

# 3. Serve kanban (via Gateway or standalone)
# Access at: http://localhost:3000/kanban-qa/
```

### Setup Metric Collection

```bash
# 1. Copy collection scripts
cp scripts/*.sh ~/.openclaw/workspace-argus/qa/

# 2. Schedule automated collection (add to crontab)
*/15 * * * * ~/.openclaw/workspace-argus/qa/update-audit-stats.sh
*/30 * * * * ~/.openclaw/workspace-argus/qa/update-token-usage.sh
```

## 🚀 Usage

### QA Dashboard

**Metrics displayed:**
- 📊 **Token Usage** - Daily/total consumption per agent
- ⚠️ **Error Rates** - Tool failures, timeouts, crashes
- 🔍 **Audit Stats** - Session counts, thinking mode usage
- 📈 **Trends** - Historical comparison

**Filters:**
- By agent (CHAPPiE, PM, Argus, etc.)
- By time range (24h, 7d, 30d)
- By severity (warnings, errors, critical)

### Kanban Board

**Features:**
- 🎯 Drag-and-drop task management
- 🏷️ Tags and priority levels
- 👥 Agent assignment
- 📝 Task descriptions with markdown
- 🔔 Alerts and notifications
- 📊 Progress tracking

**Columns:**
- **Backlog** - Queued tasks
- **In Progress** - Active work
- **Review** - Pending validation
- **Done** - Completed tasks

**Task Format:**
```json
{
  "id": "task-001",
  "title": "Fix memory leak in CHAPPiE",
  "description": "MEMORY.md exceeding 30KB",
  "agent": "chappie",
  "priority": "high",
  "tags": ["bug", "memory"],
  "created": "2026-02-17T07:00:00Z",
  "updated": "2026-02-17T08:30:00Z"
}
```

### Metric Collection Scripts

**update-audit-stats.sh**
- Parses agent logs for session metrics
- Extracts thinking mode usage
- Calculates error rates
- Outputs to `audit-stats.json`

**update-token-usage.sh**
- Reads token consumption from logs
- Aggregates by agent and timeframe
- Tracks cost estimates
- Outputs to `token-usage.json`

**Run manually:**
```bash
cd ~/.openclaw/workspace-argus/qa
./update-audit-stats.sh
./update-token-usage.sh
```

## 🔧 Configuration

### Dashboard Settings (dashboard/index.html)
```javascript
// Auto-refresh interval
const REFRESH_INTERVAL = 30000; // 30 seconds

// Data endpoints
const DATA_SOURCES = {
  audit: '/data/audit-stats.json',
  tokens: '/data/token-usage.json',
  alerts: '/data/alerts.json'
};
```

### Kanban Settings (kanban/dashboard/index.html)
```javascript
// Agents to track
const AGENTS = ['chappie', 'pm', 'argus', 'atlas'];

// Auto-save interval
const AUTOSAVE_INTERVAL = 60000; // 1 minute

// Backup frequency
const BACKUP_INTERVAL = 3600000; // 1 hour
```

## 🎓 Lessons Learned

1. **Separate concerns** - Dashboard (view) + Scripts (data collection) + Kanban (workflow)
2. **Real-time matters** - Auto-refresh keeps metrics current
3. **Visual > Text** - Charts and boards beat log files
4. **Automation** - Cron + Git hooks = self-maintaining system
5. **Integration** - QA metrics inform task priorities

## 📊 Example Metrics

**Typical daily stats:**
- 🔢 Token usage: 50K-150K per agent
- ⚠️ Error rate: <5% (healthy)
- 🧠 Thinking mode: 20-30% of sessions
- 📝 Tasks completed: 5-10 per agent

**Alert thresholds:**
- Token usage >200K/day → Warning
- Error rate >10% → Critical
- Session failures >3/hour → Investigation needed

## 🔗 Integration Points

**Works with:**
- **Memory Management** (../memory-management) - Monitors memory-related errors
- **Update Dashboard** (../update-dashboard) - Shows deployment status

**Feeds into:**
- Telegram alerts (via send-telegram-alert.sh)
- Prometheus/Grafana (export metrics)
- Incident tracking (links to memory/incidents/)

## 🐛 Troubleshooting

**Dashboard shows no data:**
- Check scripts ran: `ls -lh ~/.openclaw/workspace-argus/qa/*.json`
- Verify CORS: Server should allow localhost origins
- Check browser console for fetch errors

**Kanban not saving:**
- Verify data directory permissions: `chmod 755 ~/.openclaw/kanban-qa/data`
- Check disk space: `df -h`
- Review browser localStorage quota

**Metrics outdated:**
- Confirm cron jobs running: `crontab -l`
- Check script logs: `~/.openclaw/workspace-argus/qa/*.log`
- Run manually to test

## 📈 Future Ideas

- [ ] Add agent performance comparison
- [ ] Export reports to PDF/CSV
- [ ] Slack/Discord integration
- [ ] Predictive alerts (ML-based)
- [ ] Time tracking per task
- [ ] Burndown charts

## 🔐 Security Notes

- All data stored locally (no external APIs)
- Sanitize task descriptions before committing
- Don't include credentials in task notes
- Review kanban.json before sharing

---

**Status:** ✅ Production-ready  
**Last Updated:** 2026-02-17  
**Maintainer:** Argus + PM  
**Live Demo:** Internal only

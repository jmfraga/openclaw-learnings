# Cost Tracker 💰

Passive Claude API usage tracker with local classification, cost projection, and M4 Pro savings estimate.

## What It Does

The Cost Tracker is a comprehensive system for monitoring and analyzing Claude API usage across your OpenClaw ecosystem. It:

- **Passively tracks** Claude API requests from agent session logs
- **Classifies requests** using heuristic rules:
  - **LOCAL_VIABLE** (✅): Suitable for M4 Pro or local models (simple tasks, <4k tokens, no tools)
  - **NEEDS_CLAUDE** (🔴): Requires Claude API (complex reasoning, 3+ tools, thinking tokens)
  - **EDGE_CASE** (⚠️): Ambiguous cases requiring manual review
- **Projects savings** based on M4 Pro subscription costs vs. current Claude API spend
- **Generates weekly reports** with recommendations for cost optimization
- **Exports daily metrics** to Google Sheets for long-term trend analysis
- **Visualizes** cost breakdown by agent, model, and classification via interactive dashboard

## Prerequisites

- **Node.js** 18+ (for running tracker, report generator, and export scripts)
- **OpenClaw Hub** running on same Raspberry Pi or accessible network
- **Session logs**: Agent session JSONL files in `${OPENCLAW_PATH}/agents/*/sessions/`
- **Google Sheets** (optional): For daily export, need `mcporter` configured with Google Workspace

## Installation

1. **Copy component to OpenClaw Hub**:
```bash
cp -r cost-tracker/ /path/to/openclaw/hub/
```

2. **Install dependencies** (if needed):
```bash
cd /path/to/openclaw/hub/cost-tracker
npm install  # Usually not needed — components are vanilla JS + Node stdlib
```

3. **Create data directory**:
```bash
mkdir -p /path/to/openclaw/hub/cost-tracker/data
```

## Configuration

### Environment Variables

Edit your environment or create `.env` in the cost-tracker directory:

```bash
# Sessions directory (where agent logs are stored)
OPENCLAW_SESSIONS_DIR=/path/to/openclaw/agents

# Data directory (for cache and reports)
OPENCLAW_DATA_DIR=/path/to/openclaw/hub/cost-tracker/data

# Google Sheets (for daily export)
GOOGLE_SHEETS_ID=YOUR_SHEET_ID
MCPORTER_BIN=~/.npm-global/bin/mcporter
```

### Direct Configuration

Edit `lib/api-cost-tracker.js` and adjust:
- `SESSIONS_DIR`: Path to OpenClaw agents sessions directory
- `DATA_DIR`: Where to store request cache and metrics JSON

Edit `lib/daily-sheets-export.js`:
- `SHEET_ID`: Your Google Sheet ID (get from URL: `docs.google.com/spreadsheets/d/{ID}`)
- `SHEET_NAME`: Name of the sheet tab (default: "Daily Metrics")

## Usage

### 1. Dashboard (Real-time Visualization)

Serve the HTML dashboard via OpenClaw Hub:

```bash
# Access at: http://YOUR_PI_IP:8080/cost-tracker/cost-tracker-dashboard.html
```

The dashboard:
- Shows key metrics (total cost, request count, avg cost/request, local viable %)
- Displays classification breakdown with progress bars
- Projects M4 Pro monthly costs and potential savings
- Includes interactive charts (requests by classification, cost by model, top agents, trends)
- Filterable table of recent requests with pagination

**Auto-refresh**: Dashboard fetches latest data every 30 seconds from API endpoint.

### 2. API Endpoints

The dashboard calls `/api/cost-tracker` endpoints. You need to wire these up in your Hub's Express server:

```javascript
// In your Hub's server.js or similar
const costTracker = require('./cost-tracker/lib/api-cost-tracker');

app.get('/api/cost-tracker', async (req, res) => {
  try {
    const metrics = await costTracker.getMetrics();
    res.json(metrics);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/cost-tracker/requests', async (req, res) => {
  try {
    const { days = 7, page = 1, limit = 50, classification } = req.query;
    const requests = await costTracker.getRequests({
      days: parseInt(days),
      page: parseInt(page),
      limit: parseInt(limit),
      classification: classification !== 'all' ? classification : undefined
    });
    res.json(requests);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

### 3. Weekly Reports

Generate a comprehensive weekly summary:

```bash
node lib/weekly-cost-report.js
```

Output:
- `data/weekly-reports/{WEEK_ID}.json` — Structured data
- `data/weekly-reports/{WEEK_ID}.txt` — Readable text report
- `data/weekly-reports/latest.json` — Latest report for quick access

**Schedule via cron** (runs Sundays at 08:00 CST):
```bash
# Add to crontab -e
0 8 * * 0 cd /path/to/cost-tracker && node lib/weekly-cost-report.js
```

**Schedule via systemd timer** (create `/etc/systemd/system/cost-tracker-weekly.timer`):
```ini
[Unit]
Description=Weekly Cost Tracker Report
After=network.target

[Timer]
OnCalendar=Sun *-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

### 4. Daily Google Sheets Export

Export daily metrics to Google Sheets for trend tracking:

```bash
node lib/daily-sheets-export.js
```

**Prerequisites**:
- mcporter installed: `/usr/local/bin/mcporter` or `~/.npm-global/bin/mcporter`
- Google Workspace credentials configured in mcporter
- Google Sheet created with columns:
  - A: Date
  - B: Total Requests
  - C: Total Cost
  - D: % Local Viable
  - E: % Needs Claude
  - F: % Edge Case
  - G: Top Agent (+ Cost)
  - H: Monthly Projection

**Schedule daily** (e.g., 09:00 CST):
```bash
# crontab
0 9 * * * cd /path/to/cost-tracker && node lib/daily-sheets-export.js
```

## How It Works

### Classification Algorithm

The tracker uses heuristics to classify requests:

**LOCAL_VIABLE** ✅
- Input tokens < 4,000 AND no tools AND local keywords present
- OR: Input < 4,000 AND no tools AND no thinking tokens
- Examples: Transcription, image extraction, simple categorization, format conversion

**NEEDS_CLAUDE** 🔴
- 3+ tools used OR complex keywords (debug, architecture, reasoning, agentic loops)
- OR: Has thinking tokens (extended reasoning required)
- Examples: Code debugging, system architecture design, multi-step agentic tasks

**EDGE_CASE** ⚠️
- 4,000-8,000 input tokens AND 0-2 tools (ambiguous)
- OR: Doesn't fit other categories
- Requires manual review to improve classification

### Cost Calculation

Based on 2026 Claude API pricing (per 1M tokens):

| Model | Input | Output |
|-------|-------|--------|
| claude-opus-4-6 | $15.00 | $45.00 |
| claude-sonnet-4-6 | $3.00 | $15.00 |
| claude-haiku-4-5 | $0.80 | $4.00 |

Cost = (input_tokens / 1,000,000) × input_price + (output_tokens / 1,000,000) × output_price

### Projection: M4 Pro vs Claude API

M4 Pro assumption: ~$20/month local subscription (pro-rated MacBook cost)

**Potential Savings** = LOCAL_VIABLE requests monthly cost - M4 Pro subscription

If LOCAL_VIABLE traffic = 50% of requests, potential savings = 50% of monthly cost - $20.

## Metrics Dashboard Overview

### Key Metrics
- **Total Cost**: Sum of all Claude API calls in the period
- **Total Requests**: Count of all API requests
- **Avg Cost/Request**: Average cost per single request
- **Local Viable %**: Percentage of requests that could run locally

### Classification Breakdown
- Count and cost per classification
- Progress bars showing percentage distribution
- Potential savings from LOCAL_VIABLE requests

### Charts
1. **Requests by Classification** — Doughnut chart (LOCAL_VIABLE, NEEDS_CLAUDE, EDGE_CASE)
2. **Cost by Model** — Bar chart (Opus, Sonnet, Haiku usage)
3. **Top 5 Agents by Cost** — Bar chart (which agents are most expensive)
4. **Cost Trend** — Line chart (daily cost over 7 days, mock data)

### Recent Requests Table
- Filterable by classification
- Shows agent, model, token count, cost, timestamp
- Paginated (50 per page)

## Troubleshooting

### No Data Appearing
1. Verify `OPENCLAW_SESSIONS_DIR` points to correct agent logs
2. Check that agents have generated session logs: `/agents/{AGENT}/sessions/*.jsonl`
3. Run: `node -e "const ct = require('./lib/api-cost-tracker'); ct.getMetrics().then(m => console.log(m))"`

### Google Sheets Export Fails
1. Verify `GOOGLE_SHEETS_ID` is correct (from Sheet URL)
2. Check mcporter is installed: `which mcporter`
3. Test mcporter: `mcporter list google-workspace --schema`
4. Verify Google Workspace credentials are valid

### Dashboard Shows Old Data
1. Check API endpoint is wired correctly in Hub's server
2. Verify `data/api-cost-metrics.json` is being generated
3. Dashboard auto-refreshes every 30s — wait and check browser console for errors

## Performance Notes

- Request cache limited to 50,000 recent requests (prevent memory exhaustion)
- JSONL parsing is incremental (doesn't load all files at once)
- Weekly reports run once per week (Sunday 08:00 CST)
- Daily export runs daily (09:00 CST)

## Future Enhancements

- [ ] Filter requests by date range in dashboard
- [ ] Export daily/weekly reports as CSV
- [ ] Custom classification rules per agent
- [ ] Webhook notifications (Telegram, Slack) for budget alerts
- [ ] Multi-month trend analysis
- [ ] Historical comparison (week-over-week, month-over-month)

## License

Part of the OpenClaw ecosystem. Use freely within your OpenClaw installation.

## Support

Issues? Questions?
- Check logs in `data/` directory
- Review weekly reports for patterns
- Adjust classification keywords in `api-cost-tracker.js` based on your use cases

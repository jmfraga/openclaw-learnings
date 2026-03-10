# Agents Config — Web Panel for Agent Configuration

## Overview

**Agents Config** is a web dashboard panel within the main OpenClaw Hub that displays and manages agent configurations for a multi-agent system.

**Purpose:** Centralized view of all active agents, their properties, capabilities, and integrations.

---

## Features

### Agent List Display
- Table or card layout showing:
  - **Agent name** (e.g., `chappie`, `phoenix`, `iris-med`)
  - **Emoji** (visual identifier)
  - **Primary model** (e.g., `claude-sonnet-4.6`)
  - **Status** (active, idle, disabled)
  - **Integrations** (which tools/APIs each agent can access)

### Example Agent Entries
```
Name           | Emoji | Model              | Status | Integrations
---------------|-------|-------------------|--------|-------------------------------------
chappie        | 🤖    | claude-sonnet-4.6 | active | github, mcp-google, nodeenv
phoenix        | 🔥    | claude-opus-4      | active | web, email, marketing-tools
iris-med       | 💊    | claude-sonnet-3.5 | active | medical-api, hospital-network
iris-assistant | 🗣️    | claude-haiku-4.5   | active | voice, scheduling
atlas          | 🗺️    | claude-sonnet-3.5  | active | email, calendar, contacts
argus          | 👁️    | claude-haiku-4.5   | active | logs, monitoring
quill          | ✍️    | claude-opus-4      | active | docs, markdown, office-suite
echo           | 🔈    | claude-haiku-4.5   | active | memory, context-store
odin           | ⚡    | claude-sonnet-4.6  | active | system, cron, automation
pm             | 📋    | claude-sonnet-4.6  | active | discord, task-management
```

### Edit Capabilities (Optional)
- Forms to update agent properties:
  - Rename
  - Change assigned model
  - Toggle status (active/disabled)
  - Add/remove integrations

### Sync with Config File
- Reads from `openclaw.json` (or equivalent config source)
- Displays **exactly what's in the config**, no guessing
- Highlights **mismatches** (e.g., agent in HTML but not in config file)

---

## Architecture

### File Structure
```
agents-config/
├── agents-config.html      # UI + embedded JS
├── server.js               # Optional Express wrapper
└── README.md               # This file
```

### Data Source

**Primary:** `openclaw.json`
```json
{
  "agents": [
    {
      "name": "chappie",
      "emoji": "🤖",
      "model": "claude-sonnet-4.6",
      "integrations": ["github", "mcp-google", "nodeenv"],
      "status": "active"
    },
    {
      "name": "iris-med",
      "emoji": "💊",
      "model": "claude-sonnet-3.5",
      "integrations": ["medical-api", "hospital-network"],
      "status": "active"
    }
    // ... more agents
  ]
}
```

**Fallback:** Hardcoded agent map in HTML (if API unavailable)
```javascript
const AGENTS = {
  chappie: { emoji: '🤖', model: 'claude-sonnet-4.6', status: 'active' },
  phoenix: { emoji: '🔥', model: 'claude-opus-4', status: 'active' },
  iris_med: { emoji: '💊', model: 'claude-sonnet-3.5', status: 'active' },
  // ...
};
```

---

## Deployment

### Static HTML Only
```bash
# Copy agents-config.html to Hub directory
cp agents-config.html /path/to/hub/
# Access at: http://YOUR_PI_IP:8080/agents-config.html
```

### With Express Backend
```bash
cd agents-config
npm install express
node server.js
# Access at: http://YOUR_PI_IP:8080/api/agents
```

**server.js example:**
```javascript
const express = require('express');
const fs = require('fs');
const app = express();

app.get('/api/agents', (req, res) => {
  const config = JSON.parse(fs.readFileSync('~/.openclaw/openclaw.json', 'utf8'));
  res.json(config.agents);
});

app.listen(3000);
```

---

## Key Learnings

### 1. Keep Hardcoded Maps Synced with Config

**Problem Discovered:**
- HTML had a hardcoded `AGENTS` map with outdated agents
- New agents (`argus`, `quill`, `echo`, `odin`) were missing
- Removed agent (`iris-docs`) was still listed
- Result: Dashboard showed stale data even though config was updated

**Root Cause:**
- Agent list was duplicated: both in `openclaw.json` AND in HTML `<script>`
- Changes to config weren't reflected in the dashboard

**Solution:**
```javascript
// ❌ WRONG: Maintain two separate lists
const AGENTS_IN_HTML = { /* hardcoded */ };
// AND separately in openclaw.json

// ✅ CORRECT: Fetch from source of truth
async function loadAgents() {
  const response = await fetch('/api/agents');
  return response.json(); // Single source
}
```

**Best Practice:**
- **Define agents in `openclaw.json` only**
- Dashboard fetches via API or loads from file
- No duplication = no sync errors

### 2. Quick Validation: Agent Count Check

**Simple but effective:**
```javascript
// After loading agents, verify count
console.log(`Loaded ${agents.length} agents`);

// If this number changes unexpectedly, it's a signal to check config
// Example: went from 9 to 10 agents → new agent added, verify it was intentional
```

### 3. Remove Missing Agents Immediately

**When an agent is deprecated:**
1. Remove from `openclaw.json`
2. Remove from hardcoded HTML map
3. Verify dashboard shows updated count
4. Commit and push immediately (don't leave "dead" agent entries)

**Why:** Dead entries in config → UI clutter → confusion about actual system state

---

## Example Use Case

**Scenario:** You add a new agent `helix` (🧬) running `claude-sonnet-4.6` with GitHub integration.

1. **Update `openclaw.json`:**
```json
{
  "name": "helix",
  "emoji": "🧬",
  "model": "claude-sonnet-4.6",
  "integrations": ["github"],
  "status": "active"
}
```

2. **Refresh dashboard** — `helix` automatically appears (no HTML edits needed)

3. **Verify in UI:**
   - Agent count increases by 1
   - `helix` card is visible
   - Emoji and model are correct

4. **If using hardcoded fallback:**
   - Also add to HTML map for offline mode
   - Keep in sync via code review checklist

---

## Troubleshooting

### Agents show outdated information
- **Check 1:** Is the API endpoint hitting the right config file?
  ```bash
  curl http://YOUR_PI_IP:8080/api/agents | jq '.[] | .name'
  ```
- **Check 2:** Is config file being cached?
  - Add `?nocache=1` to URLs
  - Check server response headers for `Cache-Control`

### Agent appears in config but not on dashboard
- **Check 1:** Verify agent entry is valid JSON
  ```bash
  jq '.agents | map(.name)' ~/.openclaw/openclaw.json
  ```
- **Check 2:** Is the agent missing required fields (name, emoji, model)?
  - Add defaults in dashboard code if field missing

### Hardcoded map out of sync with config
- **Prevention:** Use API-first approach (never hardcode)
- **Recovery:** Re-generate hardcoded map from config
  ```bash
  jq '.agents | map("\(.name): { emoji: '\''\\(.emoji)'\'', model: '\''\\(.model)'\'' }") | join(", ")' openclaw.json
  ```

---

## Future Enhancements

- [ ] Real-time agent status (online/offline/error)
- [ ] Per-agent cost tracking (see cost-tracker integration)
- [ ] Deploy new agents directly from UI
- [ ] Agent capability matrix (which agents can do what)
- [ ] Audit log (who changed what, when)


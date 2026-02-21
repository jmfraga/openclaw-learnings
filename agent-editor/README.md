# Agent Editor

A web-based editor for OpenClaw agent configuration files (SOUL.md, USER.md, MEMORY.md, etc.).

## Overview

The Agent Editor provides a modern, dark-themed web UI for editing OpenClaw agent configuration and memory files directly from the Hub dashboard. It features:

- **Agent browser** — List all configured agents and quickly switch between them
- **File navigator** — Browse configuration files (SOUL.md, USER.md, MEMORY.md, etc.) with visual indicators
- **Live editor** — Edit files with a code editor interface, with syntax awareness
- **Auto-refresh** — Agent list auto-refreshes every 30 seconds to stay in sync
- **Safety confirmations** — Confirm before saving SOUL.md (critical agent behavior definition)
- **Status indicators** — Shows file existence, modification times, and agent status

## Architecture

```
agent-editor/
├── agent-editor.html       # Frontend UI (browser-based)
├── lib/
│   ├── agent-parser.js     # Node.js backend for agent discovery & session parsing
│   └── agent_parser.py     # Python backend for agent discovery & session parsing
└── README.md               # This file
```

### Technologies

- **Frontend**: Vanilla HTML/CSS/JS (no frameworks), dark theme, responsive design
- **Backend**: Node.js or Python (agent discovery from openclaw.json)
- **Communication**: Fetch API (modern REST calls)

## Requirements

### System

- **OpenClaw** installed and configured
- **Node.js** (v14+) to run the Hub server and agent-parser backend
- **Python** (v3.7+) if using the Python parser variant

### Environment

The parsers expect the following directory structure:

```
~/.openclaw/
├── openclaw.json          # Agent configuration (read by parsers)
├── agents/
│   ├── agent-id-1/
│   │   └── sessions/      # Agent session logs
│   ├── agent-id-2/
│   │   └── sessions/
│   └── ...
```

## Configuration

### 1. Set OpenClaw Directory

By default, both parsers look for `~/.openclaw`. To override, set the `OPENCLAW_DIR` environment variable:

```bash
export OPENCLAW_DIR=/path/to/your/openclaw
```

### 2. Integration with OpenClaw Hub

The Agent Editor is served as part of the Hub server. Copy the files to your Hub directory:

```bash
# Copy files to your Hub's public directory
cp agent-editor.html /home/YOUR_USERNAME/.openclaw/workspace-pm/hub/

# Copy libraries
cp lib/agent-parser.js /home/YOUR_USERNAME/.openclaw/workspace-pm/hub/lib/
cp lib/agent_parser.py /home/YOUR_USERNAME/.openclaw/workspace-pm/hub/lib/
```

### 3. Hub Server Configuration

The Hub server must expose the `/api/agent-editor/*` endpoints. Ensure your Hub's API implementation includes:

**Endpoints required:**
- `GET /api/agent-editor/agents` — Returns list of agents
- `GET /api/agent-editor/{agent-id}/files` — Returns list of editable files for an agent
- `GET /api/agent-editor/{agent-id}/file?name=FILENAME` — Get file content
- `PUT /api/agent-editor/{agent-id}/file?name=FILENAME` — Save file content

### 4. Configure Editable Files

Edit the file list in your Hub's agent-editor API backend to include desired files:

Common files to configure:
- `SOUL.md` — Agent personality & behavior (⚠️ critical)
- `USER.md` — User information & context
- `MEMORY.md` — Long-term memory
- `memory/YYYY-MM-DD.md` — Daily logs
- Any custom configuration files

## Usage

### Launching the Editor

1. Open your Hub dashboard (default: `http://localhost:8080` or `http://YOUR_PI_IP:8080`)
2. Navigate to `/agent-editor.html`
3. The interface loads automatically

### Editing a File

1. **Select Agent** — Click an agent in the left panel
2. **Select File** — Choose a file from the files panel (green ✓ = exists, gray ✗ = new)
3. **Edit Content** — Modify the text in the editor pane
4. **Save** — Click "💾 Guardar" to save to disk
5. **Reload** — Click "↻ Recargar" to discard changes and reload from disk

### Safety Features

- **SOUL.md protection** — Saving changes to SOUL.md requires confirmation
- **File status** — Visual indicators show whether files exist on disk
- **Auto-refresh** — Agent list refreshes every 30 seconds

## Data Privacy & Sanitization

This distribution includes **sanitized versions** of the components:

- **Absolute paths** — `/home/USERNAME/` references replaced with configurable `OPENCLAW_DIR`
- **IPs & hostnames** — Sanitized; configure for your environment
- **Tokens & credentials** — Removed; use env vars or secure config files
- **Agent names** — Left generic (PM, Phoenix, etc. are common naming conventions)

### Customization Notes

- Edit `lib/agent-parser.js` and `lib/agent_parser.py` to add/remove file types or custom parsing logic
- Modify `agent-editor.html` styles (CSS) to match your Hub's theme
- Add your own file list by editing the files array in your Hub's backend

## Performance

- **Caching** — Agent list cached for 30 seconds to reduce disk I/O
- **Session parsing** — Reads only the most recent session file per agent
- **Auto-refresh** — Lightweight polling every 30 seconds (configurable)

## Troubleshooting

### "No agents detected"

- Verify `OPENCLAW_DIR` points to correct location
- Check `openclaw.json` exists and contains agent definitions
- Ensure file permissions allow reading config

### "Error loading agents"

- Check Hub server logs for API errors
- Verify `/api/agent-editor/agents` endpoint is implemented
- Check browser console (F12) for network errors

### Files not saving

- Verify agent workspace directory is writable
- Check Hub server has permissions to write to agent directories
- Look at Hub server logs for I/O errors

## Development & Contribution

To extend the Agent Editor:

1. **Add new file types** — Modify `lib/agent-parser.js` (Node) or `lib/agent_parser.py` (Python)
2. **Enhance UI** — Edit styles in `<style>` block of `agent-editor.html`
3. **Add features** — Implement new endpoints in your Hub's API backend

### File Structure for Custom Agents

If you add custom files to agents, ensure they're listed in the Hub's file discovery logic:

```javascript
// Example: agent-parser.js
const FILES = ['SOUL.md', 'USER.md', 'MEMORY.md', 'CUSTOM.md'];
```

## License

This component is part of the **OpenClaw Learnings** project — a collection of sanitized, reusable components from a real multi-agent OpenClaw ecosystem.

For more information, see the main [README](../README.md) and visit [openclaw.ai](https://openclaw.ai).

## References

- **OpenClaw**: https://github.com/jmfraga/openclaw
- **OpenClaw Learnings**: https://github.com/jmfraga/openclaw-learnings
- **Agent Pattern**: Using SOUL.md, USER.md, MEMORY.md for agent continuity

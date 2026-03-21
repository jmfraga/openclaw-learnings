# Shared Memory Across Agents

## Problem

Each OpenClaw agent has its own memory bubble. When User tells Agent A about their family, Agent B has no idea. With 5+ agents talking to the same user across Telegram and WhatsApp, critical personal context gets fragmented.

## Solution

A two-layer memory architecture:

### Layer 1: Individual Memory (memory-lancedb-pro)
Each agent has its own vector database for personal recall.

- **Plugin**: `memory-lancedb-pro` (npm, drop-in replacement for stock `memory-lancedb`)
- **Embeddings**: Any OpenAI-compatible endpoint (Ollama, OpenAI, etc.)
- **autoRecall**: ON — injects relevant memories before each response (~375 tokens for 3 chunks)
- **autoCapture**: OFF recommended — prevents junk accumulation. Use manual `memory_store` in SOUL instructions instead
- **Cost**: ~200-500 tokens per request (minimal overhead)

### Layer 2: Shared Memory (cross-agent search)
A central vector database indexes all agents' memory files, searchable by any agent via MCP.

**Architecture:**
```
Agent Workspaces (Pi)              Central Hub (separate machine)
┌─────────────────┐    SSH read    ┌──────────────────────┐
│ workspace-*/     │ ───────────→  │ Indexer (Python)      │
│   memory/*.md    │               │   ↓                   │
│   profile/*.md   │               │ Embedding (Ollama)    │
└─────────────────┘               │   ↓                   │
                                   │ LanceDB (shared)      │
┌─────────────────┐    MCP query   │   ↓                   │
│ Any Agent       │ ←───────────   │ MCP Server (stdio)    │
│ (mcporter call) │               └──────────────────────┘
└─────────────────┘
```

## Setup Guide

### Prerequisites
- Python 3.10+ with venv
- Ollama with an embedding model (e.g., `nomic-embed-text`)
- SSH access from hub machine to OpenClaw machine
- `mcporter` configured on OpenClaw machine

### Step 1: Install memory-lancedb-pro on OpenClaw

```bash
openclaw plugins install memory-lancedb-pro@beta
```

Configure in `openclaw.json`:
```json
{
  "plugins": {
    "slots": { "memory": "memory-lancedb-pro" },
    "allow": ["memory-lancedb-pro"],
    "entries": {
      "memory-lancedb-pro": {
        "enabled": true,
        "config": {
          "embedding": {
            "provider": "openai-compatible",
            "apiKey": "ollama",
            "model": "nomic-embed-text",
            "baseURL": "http://<OLLAMA_HOST>:11434/v1",
            "dimensions": 768
          },
          "autoCapture": false,
          "autoRecall": true,
          "enableManagementTools": true,
          "sessionStrategy": "none"
        }
      }
    }
  }
}
```

> **Note**: The stock `memory-lancedb` plugin restricts embedding models to OpenAI's `text-embedding-3-small/large`. The `memory-lancedb-pro` plugin supports any OpenAI-compatible endpoint including Ollama.

### Step 2: Set up the Shared Memory Indexer

On your hub machine (where Ollama runs):

```bash
mkdir ~/openclaw-shared-memory
cd ~/openclaw-shared-memory
python3 -m venv .venv
source .venv/bin/activate
pip install lancedb pyarrow pandas
```

Create `indexer.py` — a script that:
1. SSHs to OpenClaw machine
2. Reads `workspace-*/memory/*.md` and `workspace-*/profile/*.md` for each agent
3. Chunks text into ~500 char segments with metadata (source_agent, file_name, date)
4. Generates embeddings via Ollama
5. Deduplicates by content hash
6. Inserts into LanceDB

Key configuration:
```python
PI_HOST = "user@<OPENCLAW_IP>"
OLLAMA_URL = "http://localhost:11434"
EMBEDDING_MODEL = "nomic-embed-text"
CHUNK_SIZE = 500
```

Run manually first: `python3 indexer.py --full`

Then schedule nightly: add a cron/launchd job for `python3 indexer.py` (incremental by default).

### Step 3: Create the MCP Server

Create `mcp_server.py` — an MCP stdio server that exposes:
- `shared_memory_search(query, source_agent?, top_k?)` — vector search across all agents
- `shared_memory_stats()` — database statistics

The server connects to the same LanceDB, embeds the query via Ollama, and returns ranked results with source agent attribution.

### Step 4: Connect to OpenClaw via mcporter

On the OpenClaw machine, add to `~/.mcporter/mcporter.json`:
```json
{
  "mcpServers": {
    "shared-memory": {
      "command": "ssh -o ConnectTimeout=10 user@<HUB_IP> /path/to/.venv/bin/python3 /path/to/mcp_server.py",
      "description": "Shared cross-agent memory search",
      "lifecycle": { "mode": "on-demand" }
    }
  }
}
```

### Step 5: Update Agent SOULs

Add to each agent's SOUL.md:
```markdown
## Shared Memory
You have access to `shared_memory_search` via mcporter — searches memories from ALL agents.
**Use when:**
- Asked about the user's personal life, family, preferences and you don't have the answer
- You need context from conversations another agent had
**Example:** `mcporter call shared-memory shared_memory_search --args '{"query":"user family members"}'`
Don't use for every message — only when you lack personal or historical context.
```

Add to each agent's TOOLS.md:
```markdown
### Shared Memory (mcporter → shared-memory)
- `shared_memory_search`: query (string), source_agent (optional), top_k (optional, default 5)
- `shared_memory_stats`: no params, returns DB statistics
```

> **Important**: Agents with `messaging` profile need `exec` in their `tools.alsoAllow` to call mcporter.

## Token Impact

| Component | Without shared memory | With shared memory |
|-----------|:--------------------:|:-----------------:|
| SOUL.md | ~2-3K tokens | ~2.5-3.5K tokens (+instructions) |
| autoRecall | N/A | ~375 tokens (3 chunks injected) |
| shared_memory_search | N/A | ~500 tokens (only when called) |
| **Overhead per request** | 0 | **~375-875 tokens** |

The memory injection is surgical — only relevant chunks, not entire files.

## Lessons Learned

1. **Stock memory-lancedb won't work with Ollama** — schema validation rejects non-OpenAI models. Use `memory-lancedb-pro` or patch the schema.

2. **autoCapture OFF is safer** — with 10 agents, autoCapture generates too much noise. Manual `memory_store` via SOUL instructions gives better signal-to-noise.

3. **LanceDB > ChromaDB for this use case** — embedded, no server process, file-based (easy to backup/replicate), fast enough for <10K chunks.

4. **SSH stdio for MCP is elegant** — no HTTP server needed. The MCP server runs on the hub machine, communicates via stdin/stdout over SSH. mcporter handles the connection.

5. **Nightly indexing is sufficient** — memory files don't change intra-day. Incremental indexing (by mtime) keeps it fast after the initial seed.

6. **Cross-agent search is a tool, not automatic** — agents decide when to search shared memory based on SOUL instructions. This prevents unnecessary token burn on every request.

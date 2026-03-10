# Ollama Arena — Multi-Model Comparison Hub

## Overview

**Ollama Arena** is a web dashboard for comparing responses from multiple Ollama models **in parallel**, running on a new deployment machine (secondary Pi, VPS, etc.).

**Purpose:** Evaluate local model quality vs. Claude API; determine which requests can be routed to local inference vs. cloud APIs.

**Stack:** Vanilla JS + Node.js, dark theme (GitHub-style), ~300 LOC.

---

## Features

### 1. Parallel Model Evaluation
- Submit a single prompt to all running Ollama models **simultaneously**
- Display responses in cards with:
  - **Response time** (seconds)
  - **Tokens/second** (throughput metric)
  - **Model name** and parameters (temperature, context window)

### 2. Integrated Triage Agent
- Uses a local Ollama model to **classify incoming requests**
- Routes prompts automatically before processing:
  - `self` — can be answered locally
  - `chappie` — delegate to CHAPPiE (development tasks)
  - `github` — fetch from GitHub APIs
  - `nano-banana` — image generation
  - `web` — search or fetch external content
  - `api` — call specialized APIs
  - `system` — system admin tasks
  - `human` — requires human decision
- Displays suggested routing below the prompt input

### 3. JSON Validation
- **Auto-detects** if response is JSON
- **Visual feedback:**
  - 🟢 Green: Valid JSON, pretty-printed
  - 🔴 Red: Invalid JSON, raw text shown
- Useful for evaluating model consistency on structured tasks

### 4. Example Presets
- Dropdown menu with common test prompts:
  - "Summarize a technical paper"
  - "Generate JSON schema"
  - "Debug code snippet"
  - etc.
- Quickly compare model behavior on known tasks

### 5. Auto-Scroll & Overflow
- Cards auto-scroll as responses arrive
- Max-height containers with `overflow-y: auto` prevent layout explosion

---

## Architecture

### Directory Structure
```
ollama-arena/
├── index.html          # UI (Vanilla JS + CSS)
├── server.js           # Express server
├── triage-agent.js     # Local model router
└── README.md           # This file
```

### Key Endpoints

**GET `/`**
- Serves the UI (index.html)

**POST `/api/compare`**
- Input: `{ prompt: string }`
- Queries all models via Ollama API (`http://YOUR_PI_NEW_IP:11434/api/generate`)
- Returns array of responses with timings and token counts
- Example response:
```json
[
  {
    "model": "mistral:7b",
    "response": "...",
    "time_seconds": 3.24,
    "tokens_per_second": 12.5
  },
  {
    "model": "llama2:13b",
    "response": "...",
    "time_seconds": 5.10,
    "tokens_per_second": 9.8
  }
]
```

**POST `/api/triage`**
- Input: `{ prompt: string }`
- Uses a lightweight local model to classify the request
- Returns: `{ category: string, confidence: 0-1, reason: string }`
- Example:
```json
{
  "category": "web",
  "confidence": 0.95,
  "reason": "Query requests external information (current weather, news)"
}
```

---

## Deployment

### Prerequisites
- **Ollama installed** on secondary machine
- **Models running:** `ollama pull mistral:7b` (or similar)
- **Node.js** installed

### Setup
```bash
cd ollama-arena
npm install express
node server.js
```

Server runs on `http://YOUR_PI_NEW_IP:8080` (adjust port in server.js if needed).

### Environment Variables (optional)
```bash
OLLAMA_BASE_URL=http://YOUR_PI_NEW_IP:11434  # Ollama API endpoint
PORT=8080                                      # Server port
TRIAGE_MODEL=mistral:7b                        # Model for triage agent
```

---

## Usage

### Via Web UI
1. Navigate to `http://YOUR_PI_NEW_IP:8080/`
2. Enter a prompt in the textarea
3. Click **"Compare Models"** (or press Cmd+Enter)
4. Watch responses stream in as they complete
5. Review triage suggestion in the sidebar

### Via API
```bash
curl -X POST http://YOUR_PI_NEW_IP:8080/api/compare \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is 2+2?"}'
```

---

## Key Learnings

### 1. Local vs. Cloud Trade-offs
- **Speed:** Local models start responding in <1s (no network latency)
- **Quality:** Smaller models (7B, 13B) often lag on reasoning tasks
- **Cost:** $0 per request (infrastructure cost only)
- **Use local when:** Response latency < reasoning quality, e.g., summaries, rewrites, classifications

### 2. Triage Agent Effectiveness
- **Value:** Reduces routing decisions from manual/ad-hoc to automated
- **Limitation:** Depends on quality of the triage model itself
- **Best practice:** Use a faster, smaller model for triage (e.g., Mistral 7B), reserve larger models for actual work
- **Feedback loop:** Log triage decisions and compare with actual routing needs; refine prompt if necessary

### 3. Tokens/Second as a Quality Metric
- **Why it matters:** Models that generate coherent output at high token/sec are usually better
- **Caveat:** Don't conflate speed with quality; a fast wrong answer is still wrong
- **Use for:** Comparing the same model across hardware, or similar-sized models

### 4. JSON Validation as a Capability Test
- **Simple but revealing:** Request "output as JSON" for multiple models
- **Patterns:**
  - Some models reliably produce valid JSON; others often break syntax
  - Smaller models struggle with complex nested structures
  - Validates whether a model can follow structured output instructions
- **Action:** If JSON validation fails, flag that model for tasks requiring structured data

---

## Example Workflow

**Scenario:** Determine if Mistral 7B can replace Claude API for request classification.

1. **Test prompt:** "Classify this request: 'I need help debugging a Node.js memory leak. What are the top 3 causes?'"
2. **Models tested:**
   - Mistral 7B (local)
   - Llama 2 13B (local)
   - Claude (via API for comparison)
3. **Metrics collected:**
   - Time to first token
   - Relevance of classification
   - JSON structure validity
   - Cost per request
4. **Decision:** If Mistral 7B is within 85% of Claude quality and 1000x cheaper, route production requests to local

---

## Troubleshooting

### Models not appearing
- Verify Ollama is running: `curl http://YOUR_PI_NEW_IP:11434/api/tags`
- Check `OLLAMA_BASE_URL` env var matches deployment

### Triage agent stuck
- Check if triage model is loaded: `ollama list | grep <triage-model-name>`
- Restart Ollama: `systemctl restart ollama` (or equivalent on your system)

### Responses very slow
- Monitor system resources (`top`, `htop`)
- Large models (13B+) may need more VRAM
- Reduce batch size or concurrent requests

---

## Future Enhancements

- [ ] Save comparison results to database for analysis
- [ ] A/B test: compare side-by-side for specific task categories
- [ ] Cost per request calculator (including inference cost)
- [ ] Model performance leaderboard (time, quality, consistency)
- [ ] Batch upload (test 100 prompts at once)


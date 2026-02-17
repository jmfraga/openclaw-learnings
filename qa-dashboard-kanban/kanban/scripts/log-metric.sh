#!/bin/bash
# log-metric.sh - Dashboard QA 3.0 metric logger
# Schema compatible with CHAPPiE's dashboard architecture

METRICS_FILE="/home/jmfraga/.openclaw/workspace-argus/kanban-qa/data/metrics.jsonl"

# Ensure data directory exists
mkdir -p "$(dirname "$METRICS_FILE")"

# Parse arguments (flexible for different use cases)
AGENT="${1:-unknown}"
EVENT_TYPE="${2:-info}"
SEVERITY="${3:-S0}"
TOOL_USED="${4:-null}"
TOOL_ERROR="${5:-false}"
RETRY_COUNT="${6:-0}"
TIMEOUT="${7:-false}"
LATENCY_MS="${8:-0}"
FAILURE_MODE="${9:-null}"
ESCALATED_TO="${10:-null}"
SESSION_ID="${11:-}"
TOKENS_TOTAL="${12:-0}"
MODEL="${13:-claude-haiku-4-5}"

# Generate timestamp
TIMESTAMP=$(date +%s)
DATE=$(date +%Y-%m-%d)
HOUR=$(date +%H)

# Auto-detect model tier
MODEL_TIER="economic"
if [[ "$MODEL" == *"sonnet"* ]] || [[ "$MODEL" == *"opus"* ]]; then
    MODEL_TIER="premium"
fi

# Build JSON using jq for safety
jq -nc \
  --arg ts "$TIMESTAMP" \
  --arg date "$DATE" \
  --arg hour "$HOUR" \
  --arg agent "$AGENT" \
  --arg session_id "$SESSION_ID" \
  --arg event_type "$EVENT_TYPE" \
  --arg severity "$SEVERITY" \
  --arg tool_used "$TOOL_USED" \
  --argjson tool_error "$TOOL_ERROR" \
  --argjson retry_count "$RETRY_COUNT" \
  --argjson timeout "$TIMEOUT" \
  --argjson latency_ms "$LATENCY_MS" \
  --arg failure_mode "$FAILURE_MODE" \
  --arg escalated_to "$ESCALATED_TO" \
  --argjson tokens_total "$TOKENS_TOTAL" \
  --arg model "$MODEL" \
  --arg model_tier "$MODEL_TIER" \
  '{
    timestamp: ($ts | tonumber),
    date: $date,
    hour: ($hour | tonumber),
    agent: $agent,
    session_id: $session_id,
    event_type: $event_type,
    severity: $severity,
    tool_used: $tool_used,
    tool_error: $tool_error,
    retry_count: $retry_count,
    timeout: $timeout,
    latency_ms: $latency_ms,
    failure_mode: $failure_mode,
    escalated_to: $escalated_to,
    tokens_total: $tokens_total,
    model: $model,
    model_tier: $model_tier
  }' >> "$METRICS_FILE"

# Confirm log
echo "✅ Metric logged: $EVENT_TYPE/$SEVERITY for $AGENT"

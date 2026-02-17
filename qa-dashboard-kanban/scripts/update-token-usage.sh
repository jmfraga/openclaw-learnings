#!/bin/bash
# update-token-usage.sh - Actualiza token-usage.json con datos reales de session transcripts
# Run diariamente por Argus cron workflow

KANBAN_DIR="/home/jmfraga/.openclaw/workspace-argus/kanban-qa"
TOKEN_FILE="$KANBAN_DIR/data/token-usage.json"
AGENTS_BASE="/home/jmfraga/.openclaw/agents"
BACKUP_DIR="$KANBAN_DIR/data/backups"
DATE=$(date +%Y-%m-%d)
WEEK_START=$(date -d 'last monday' +%Y-%m-%d)

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR"

echo "💰 Updating token-usage.json from real session data..."

# Backup existing file
if [[ -f "$TOKEN_FILE" ]]; then
    cp "$TOKEN_FILE" "$BACKUP_DIR/token-usage-$(date +%Y%m%d-%H%M%S).json"
fi

# Initialize token file if it doesn't exist
if [[ ! -f "$TOKEN_FILE" ]]; then
    cat > "$TOKEN_FILE" <<EOF
{
  "weekStart": "$WEEK_START",
  "weeklyUsed": 0,
  "dailyUsage": {},
  "history": [],
  "metadata": {
    "weeklyLimit": 50000,
    "warningThreshold": 0.8,
    "criticalThreshold": 0.95
  }
}
EOF
fi

# Check if we need to reset for new week
STORED_WEEK=$(jq -r '.weekStart' "$TOKEN_FILE")
if [[ "$WEEK_START" != "$STORED_WEEK" ]]; then
    echo "🔄 New week detected, resetting counters..."
    
    # Save previous week to history
    WEEKLY_USED=$(jq -r '.weeklyUsed' "$TOKEN_FILE")
    jq ".history += [{\"week\": \"$STORED_WEEK\", \"tokens\": $WEEKLY_USED}]" "$TOKEN_FILE" > "$TOKEN_FILE.tmp"
    mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
    
    # Reset for new week
    jq ".weekStart = \"$WEEK_START\" | .weeklyUsed = 0 | .dailyUsage = {}" "$TOKEN_FILE" > "$TOKEN_FILE.tmp"
    mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
fi

# Calculate tokens from session transcripts (current week only)
TEMP_FILE=$(mktemp)
TOTAL_TOKENS=0
declare -A DAILY_TOKENS

echo "  📊 Scanning session transcripts (week starting $WEEK_START)..."

# List of agents to scan
AGENTS=(argus atlas chappie echo iris-assistant iris-docs iris-med phoenix pm)

for agent in "${AGENTS[@]}"; do
    sessions_dir="$AGENTS_BASE/$agent/sessions"
    
    if [[ ! -d "$sessions_dir" ]]; then
        continue
    fi
    
    # Find sessions from this week
    find "$sessions_dir" -name "*.jsonl" -type f -mtime -7 2>/dev/null | while IFS= read -r transcript; do
        # Get session date first (from first session event)
        session_date=$(jq -r 'select(.type=="session") | .timestamp' "$transcript" 2>/dev/null | head -1 | cut -d'T' -f1 || echo "")
        
        # Skip if not from current week
        if [[ -z "$session_date" ]] || [[ "$session_date" < "$WEEK_START" ]]; then
            continue
        fi
        
        # Extract tokens from assistant messages (only count once per session)
        session_tokens=$(jq -s '[.[] | select(.type=="message" and .message.role=="assistant") | .message.usage.totalTokens // 0] | add // 0' "$transcript" 2>/dev/null || echo "0")
        
        if [[ $session_tokens -gt 0 ]]; then
            echo "$session_date $session_tokens" >> "$TEMP_FILE"
        fi
    done
done

# Aggregate by date
while read -r date tokens; do
    if [[ -n "$date" ]] && [[ -n "$tokens" ]]; then
        if [[ -z "${DAILY_TOKENS[$date]}" ]]; then
            DAILY_TOKENS[$date]=0
        fi
        DAILY_TOKENS[$date]=$((DAILY_TOKENS[$date] + tokens))
    fi
done < "$TEMP_FILE"

rm -f "$TEMP_FILE"

# Calculate total for current week
WEEKLY_TOTAL=0
for date in "${!DAILY_TOKENS[@]}"; do
    # Only count tokens from current week
    if [[ "$date" > "$WEEK_START" ]] || [[ "$date" == "$WEEK_START" ]]; then
        WEEKLY_TOTAL=$((WEEKLY_TOTAL + DAILY_TOKENS[$date]))
    fi
done

# Build dailyUsage JSON object
DAILY_USAGE_JSON=$(jq -n 'reduce inputs as $item ({}; .[$item.date] = $item.tokens)' <<< "$(
    for date in "${!DAILY_TOKENS[@]}"; do
        if [[ "$date" > "$WEEK_START" ]] || [[ "$date" == "$WEEK_START" ]]; then
            echo "{\"date\": \"$date\", \"tokens\": ${DAILY_TOKENS[$date]}}"
        fi
    done | jq -c '.'
)")

# Update token-usage.json
jq \
  --argjson weekly "$WEEKLY_TOTAL" \
  --argjson daily "$DAILY_USAGE_JSON" \
  '.weeklyUsed = $weekly | .dailyUsage = $daily' \
  "$TOKEN_FILE" > "$TOKEN_FILE.tmp"

# Validate JSON
if jq empty "$TOKEN_FILE.tmp" 2>/dev/null; then
    mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
    
    # Calculate percentage
    WEEKLY_LIMIT=$(jq -r '.metadata.weeklyLimit' "$TOKEN_FILE")
    PERCENT=$(echo "scale=1; ($WEEKLY_TOTAL * 100) / $WEEKLY_LIMIT" | bc)
    
    echo "✅ Token usage updated successfully"
    echo "   Week: $WEEK_START - $DATE"
    echo "   Weekly used: $WEEKLY_TOTAL / $WEEKLY_LIMIT tokens (${PERCENT}%)"
    echo "   Days tracked: ${#DAILY_TOKENS[@]}"
    
    # Show daily breakdown
    if [[ ${#DAILY_TOKENS[@]} -gt 0 ]]; then
        echo "   Daily breakdown:"
        for date in $(echo "${!DAILY_TOKENS[@]}" | tr ' ' '\n' | sort); do
            echo "     $date: ${DAILY_TOKENS[$date]} tokens"
        done
    fi
    
    # Check for warnings
    WARNING_THRESHOLD=$(jq -r '.metadata.warningThreshold' "$TOKEN_FILE")
    CRITICAL_THRESHOLD=$(jq -r '.metadata.criticalThreshold' "$TOKEN_FILE")
    USAGE_RATIO=$(echo "scale=2; $WEEKLY_TOTAL / $WEEKLY_LIMIT" | bc)
    
    CRITICAL_PERCENT=$(echo "scale=0; $CRITICAL_THRESHOLD * 100" | bc)
    WARNING_PERCENT=$(echo "scale=0; $WARNING_THRESHOLD * 100" | bc)
    
    if (( $(echo "$USAGE_RATIO >= $CRITICAL_THRESHOLD" | bc -l) )); then
        echo ""
        echo "⚠️  CRITICAL: Token budget at ${PERCENT}% (>${CRITICAL_PERCENT}%)"
    elif (( $(echo "$USAGE_RATIO >= $WARNING_THRESHOLD" | bc -l) )); then
        echo ""
        echo "⚠️  WARNING: Token budget at ${PERCENT}% (>${WARNING_PERCENT}%)"
    fi
else
    echo "❌ JSON validation failed, restoring from backup"
    rm "$TOKEN_FILE.tmp"
    exit 1
fi

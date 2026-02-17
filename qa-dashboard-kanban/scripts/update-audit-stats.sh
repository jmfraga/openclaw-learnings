#!/bin/bash
# update-audit-stats.sh - Actualiza audit-stats.json con datos reales de journalctl
# Run diariamente por Argus cron workflow

QA_DIR="/home/jmfraga/.openclaw/workspace-argus/qa"
AUDIT_FILE="$QA_DIR/audit-stats.json"
BACKUP_DIR="$QA_DIR/backups"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date -Iseconds)

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR"

echo "📊 Updating audit-stats.json from real logs..."

# Backup existing file
if [[ -f "$AUDIT_FILE" ]]; then
    cp "$AUDIT_FILE" "$BACKUP_DIR/audit-stats-$(date +%Y%m%d-%H%M%S).json"
fi

# Get logs from last 24 hours
TOTAL_LOGS=$(journalctl --user -u oc-gw.service --since "24 hours ago" --no-pager 2>/dev/null | wc -l)
ERROR_LOGS=$(journalctl --user -u oc-gw.service --since "24 hours ago" --no-pager 2>/dev/null | grep -iE "(error|warning|critical|fatal|exception|failed)" | wc -l)

# Avoid division by zero
if [[ $TOTAL_LOGS -eq 0 ]]; then
    TOTAL_LOGS=1
fi

# Calculate error rate
ERROR_RATE=$(echo "scale=1; ($ERROR_LOGS * 100) / $TOTAL_LOGS" | bc)

# Get sample errors (top 3 unique patterns)
SAMPLE_ERRORS=$(journalctl --user -u oc-gw.service --since "24 hours ago" --no-pager 2>/dev/null | \
    grep -iE "(error|warning|critical|fatal|exception|failed)" | \
    sed 's/.*openclaw\[.*\]: //' | \
    sort | uniq -c | sort -rn | head -3 | \
    awk '{$1=""; print}' | \
    sed 's/^[ \t]*//' | \
    jq -R -s -c 'split("\n") | map(select(length > 0)) | map(.[0:80] + (if length > 80 then "..." else "" end))')

# Get previous stats for trend calculation
PREV_ERROR_RATE=$(jq -r '.current_stats.error_rate // 0' "$AUDIT_FILE" 2>/dev/null || echo "0")

# Determine trend
TREND="stable"
if (( $(echo "$ERROR_RATE < $PREV_ERROR_RATE" | bc -l) )); then
    TREND="improving (${PREV_ERROR_RATE}% → ${ERROR_RATE}%)"
elif (( $(echo "$ERROR_RATE > $PREV_ERROR_RATE" | bc -l) )); then
    TREND="degrading (${PREV_ERROR_RATE}% → ${ERROR_RATE}%)"
fi

# Categorize errors
CRITICAL_COUNT=$(journalctl --user -u oc-gw.service --since "24 hours ago" --no-pager 2>/dev/null | grep -icE "(critical|fatal)" || echo "0")
WARNING_COUNT=$(journalctl --user -u oc-gw.service --since "24 hours ago" --no-pager 2>/dev/null | grep -icE "(warning|warn)" || echo "0")

# Create new audit entry
NEW_AUDIT=$(jq -n \
  --arg date "$DATE" \
  --arg time_range "02:00 (24h backlog)" \
  --argjson total "$TOTAL_LOGS" \
  --argjson errors "$ERROR_LOGS" \
  --arg error_rate "$ERROR_RATE" \
  --argjson critical "$CRITICAL_COUNT" \
  --argjson warning "$WARNING_COUNT" \
  --argjson samples "$SAMPLE_ERRORS" \
  '{
    date: $date,
    time_range: $time_range,
    total_logs_scanned: $total,
    logs_with_errors: $errors,
    error_rate: ($error_rate | tonumber),
    categories: {
      critical: $critical,
      warning: $warning
    },
    sample_errors: $samples
  }')

# Update audit-stats.json
if [[ ! -f "$AUDIT_FILE" ]]; then
    # Create new file with template
    cat > "$AUDIT_FILE" <<EOF
{
  "metadata": {
    "description": "Log audit statistics - tracks how many logs Argus reviewed and found errors in",
    "updated": "$TIMESTAMP",
    "schema": {
      "date": "ISO8601 date of audit",
      "total_logs_scanned": "integer - total number of log entries reviewed",
      "logs_with_errors": "integer - number of logs containing errors/warnings",
      "error_rate": "float - (logs_with_errors / total_logs_scanned) * 100",
      "time_range": "string - e.g. 'last-24h', 'last-7d'",
      "sample_errors": "array - examples of errors found"
    }
  },
  "daily_audits": [],
  "current_stats": {}
}
EOF
fi

# Add new audit to daily_audits array and update current_stats
jq \
  --arg updated "$TIMESTAMP" \
  --argjson new_audit "$NEW_AUDIT" \
  --arg trend "$TREND" \
  '.metadata.updated = $updated |
   .daily_audits = ([$new_audit] + .daily_audits | .[0:30]) |
   .current_stats = ($new_audit + {trend: $trend, status: "monitoring"})' \
  "$AUDIT_FILE" > "$AUDIT_FILE.tmp"

# Validate JSON
if jq empty "$AUDIT_FILE.tmp" 2>/dev/null; then
    mv "$AUDIT_FILE.tmp" "$AUDIT_FILE"
    echo "✅ Audit stats updated successfully"
    echo "   Total logs: $TOTAL_LOGS"
    echo "   Error logs: $ERROR_LOGS"
    echo "   Error rate: ${ERROR_RATE}%"
    echo "   Trend: $TREND"
else
    echo "❌ JSON validation failed, restoring from backup"
    rm "$AUDIT_FILE.tmp"
    exit 1
fi

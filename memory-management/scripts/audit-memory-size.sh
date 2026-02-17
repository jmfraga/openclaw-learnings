#!/bin/bash
# audit-memory-size.sh - Weekly MEMORY.md size audit
# Cron: 0 8 * * 0 (8 AM every Sunday)

set -euo pipefail

WORKSPACE="${WORKSPACE_DIR:-$HOME/.openclaw/workspace-chappie}"
MEMORY_FILE="$WORKSPACE/MEMORY.md"
THRESHOLD_KB=3.5
KANBAN_FILE="$WORKSPACE/kanban.json"
LOG_FILE="$WORKSPACE/memory/.audit.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== Starting weekly MEMORY.md audit ==="

# Check if MEMORY.md exists
if [[ ! -f "$MEMORY_FILE" ]]; then
    log "MEMORY.md not found. Nothing to audit."
    exit 0
fi

# Get file size
SIZE_BYTES=$(stat -f%z "$MEMORY_FILE" 2>/dev/null || stat -c%s "$MEMORY_FILE")
SIZE_KB=$(echo "scale=1; $SIZE_BYTES / 1024" | bc)

log "Current size: ${SIZE_KB}KB (threshold: ${THRESHOLD_KB}KB)"

# Check if over threshold
if (( $(echo "$SIZE_KB < $THRESHOLD_KB" | bc -l) )); then
    log "✅ Size OK. No action needed."
    exit 0
fi

log "⚠️  Size exceeds threshold!"

# Analyze section sizes
SECTION_SIZES=$(awk '
/^## / {
    if (section) {
        printf "%s: %d lines\n", section, lines
    }
    section = substr($0, 4)
    lines = 0
    next
}
{
    lines++
}
END {
    if (section) {
        printf "%s: %d lines\n", section, lines
    }
}' "$MEMORY_FILE")

log "Section breakdown:"
echo "$SECTION_SIZES" | while read -r line; do
    log "  - $line"
done

# Prepare Kanban task
TASK_ID="memory-cleanup-$(date '+%Y-%m-%d')"
TASK_TITLE="🧹 MEMORY.md Cleanup Required"
TASK_DESC="MEMORY.md has grown to **${SIZE_KB}KB** (threshold: ${THRESHOLD_KB}KB)

**Section Breakdown:**
\`\`\`
$SECTION_SIZES
\`\`\`

**Actions to take:**
1. Review sections and identify content to move to \`memory/\` subdirectories
2. Consolidate \"Recent Learnings\" into \"Core Identity\"
3. Ensure \"Incidents\" section only contains current month
4. Move project-specific details to \`memory/projects/\`

**Target:** Reduce to <3.0KB (buffer for growth)

**See:** \`memory/memory-maintenance-system.md\` for guidelines"

# Create Kanban task (if openclaw CLI available)
if command -v openclaw &>/dev/null; then
    log "Creating Kanban task..."
    
    # Send message to PM
    openclaw message agent:pm:telegram:default:direct:1074136117 \
        "$TASK_TITLE\n\n$TASK_DESC" \
        2>/dev/null && log "✅ Notification sent to PM" || log "❌ Could not send notification"
else
    log "OpenClaw CLI not found. Logging only."
    
    # Write to a file PM can check
    ALERT_FILE="$WORKSPACE/memory/.size-alert.txt"
    cat > "$ALERT_FILE" << EOF
$TASK_TITLE

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Current Size: ${SIZE_KB}KB / ${THRESHOLD_KB}KB

$TASK_DESC
EOF
    log "Alert written to: $ALERT_FILE"
fi

log "=== Audit complete ==="
exit 0

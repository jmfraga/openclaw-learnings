#!/bin/bash
# pre-commit-memory-check.sh - Git pre-commit hook for MEMORY.md size validation
# Install: ln -s ../../.openclaw/hooks/pre-commit-memory-check.sh .git/hooks/pre-commit

set -euo pipefail

MEMORY_FILE="MEMORY.md"
THRESHOLD_KB=3.5
HARD_LIMIT_KB=4.0

# Only check if MEMORY.md is being committed
if ! git diff --cached --name-only | grep -q "^$MEMORY_FILE$"; then
    exit 0
fi

# Check if file exists
if [[ ! -f "$MEMORY_FILE" ]]; then
    exit 0
fi

# Get file size
SIZE_BYTES=$(stat -f%z "$MEMORY_FILE" 2>/dev/null || stat -c%s "$MEMORY_FILE")
SIZE_KB=$(echo "scale=1; $SIZE_BYTES / 1024" | bc)

echo "🔍 Checking MEMORY.md size: ${SIZE_KB}KB"

# Hard limit check (block commit)
if (( $(echo "$SIZE_KB >= $HARD_LIMIT_KB" | bc -l) )); then
    cat << EOF

❌ ERROR: MEMORY.md exceeds hard limit!

Current size: ${SIZE_KB}KB
Hard limit:   ${HARD_LIMIT_KB}KB

This commit is BLOCKED to prevent read tool truncation errors.

Actions required:
1. Move sections to memory/ subdirectories:
   - Incidents → memory/incidents/YYYY-MM.md
   - Projects → memory/projects/[name].md
   - Old learnings → memory/archive/

2. Review memory/memory-maintenance-system.md for guidelines

3. Run: openclaw exec .openclaw/hooks/audit-memory-size.sh
   (for detailed section analysis)

EOF
    exit 1
fi

# Soft threshold warning (allow commit with confirmation)
if (( $(echo "$SIZE_KB >= $THRESHOLD_KB" | bc -l) )); then
    cat << EOF

⚠️  WARNING: MEMORY.md approaching size limit

Current size: ${SIZE_KB}KB
Threshold:    ${THRESHOLD_KB}KB
Hard limit:   ${HARD_LIMIT_KB}KB

Consider moving content to memory/ subdirectories before committing.

EOF
    
    # Interactive confirmation (only in TTY)
    if [[ -t 0 ]]; then
        read -p "Continue with commit? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Commit cancelled."
            exit 1
        fi
    else
        echo "⚠️  Non-interactive mode: allowing commit with warning."
    fi
fi

echo "✅ MEMORY.md size OK"
exit 0

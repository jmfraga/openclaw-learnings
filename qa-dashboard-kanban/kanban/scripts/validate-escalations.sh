#!/bin/bash
# validate-escalations.sh - Detecta bucles en historial de escalaciones

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"

echo "🔍 Validating Escalation Flows"
echo "================================"
echo ""

if [[ ! -f "$KANBAN_FILE" ]]; then
    echo "❌ kanban.json not found"
    exit 1
fi

# Extract escalation flows
flows=$(jq -r '.tasks[] | select(.delegatedTo != null) | "\(.agent) → \(.delegatedTo)"' "$KANBAN_FILE" 2>/dev/null)

if [[ -z "$flows" ]]; then
    echo "✅ No delegations found (nothing to validate)"
    exit 0
fi

echo "📊 Current Escalation Flows:"
echo "$flows"
echo ""

# Check for direct loops (A → A)
echo "🔎 Checking for direct loops (A → A)..."
direct_loops=$(echo "$flows" | awk -F' → ' '$1 == $2 {print}')

if [[ -n "$direct_loops" ]]; then
    echo "❌ DIRECT LOOPS DETECTED:"
    echo "$direct_loops"
    echo ""
else
    echo "✅ No direct loops found"
    echo ""
fi

# Check for known prohibited flows
echo "🔎 Checking for prohibited flows..."
prohibited_flows=(
    "iris-assistant → pm"
    "phoenix → chappie"
    "pm → chappie"
)

found_prohibited=0
for flow in "${prohibited_flows[@]}"; do
    if echo "$flows" | grep -qi "$flow"; then
        # Check if there's a reverse flow creating a loop
        agent=$(echo "$flow" | awk -F' → ' '{print $1}')
        dest=$(echo "$flow" | awk -F' → ' '{print $2}')
        
        # Look for reverse in task history
        reverse_check=$(jq -r --arg agent "$agent" --arg dest "$dest" '
            .tasks[] | 
            select(.agent == $dest and .delegatedTo == $agent) | 
            "\(.agent) → \(.delegatedTo)"
        ' "$KANBAN_FILE" 2>/dev/null)
        
        if [[ -n "$reverse_check" ]]; then
            echo "❌ LOOP DETECTED: $flow ⟷ $reverse_check"
            found_prohibited=1
        fi
    fi
done

if [[ $found_prohibited -eq 0 ]]; then
    echo "✅ No prohibited loops found"
fi

echo ""

# Check for valid terminal flows
echo "🔎 Validating terminal flows..."
valid_terminals=(
    "chappie"
    "iris-med"
    "quill"
)

terminal_violations=0
for terminal in "${valid_terminals[@]}"; do
    # Check if terminal agent escalates to anyone (should not)
    escalations=$(jq -r --arg term "$terminal" '
        .tasks[] | 
        select(.agent == $term and .delegatedTo != null and .delegatedTo != "pm") | 
        "\(.agent) → \(.delegatedTo)"
    ' "$KANBAN_FILE" 2>/dev/null)
    
    if [[ -n "$escalations" ]]; then
        echo "⚠️  TERMINAL VIOLATION: $terminal should be terminal but escalates:"
        echo "$escalations"
        terminal_violations=1
    fi
done

if [[ $terminal_violations -eq 0 ]]; then
    echo "✅ All terminal agents are terminal"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

total_flows=$(echo "$flows" | wc -l)
echo "Total escalations: $total_flows"

if [[ -z "$direct_loops" ]] && [[ $found_prohibited -eq 0 ]] && [[ $terminal_violations -eq 0 ]]; then
    echo "Status: ✅ ALL VALIDATIONS PASSED"
    exit 0
else
    echo "Status: ❌ VIOLATIONS FOUND"
    echo ""
    echo "⚠️  Review escalation-map.md for correct flows"
    exit 1
fi

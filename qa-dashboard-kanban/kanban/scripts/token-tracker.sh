#!/bin/bash
# token-tracker.sh - Tracking de presupuesto de tokens

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/agents-config.json"
DATA_DIR="$PROJECT_DIR/data"
TOKEN_FILE="$DATA_DIR/token-usage.json"

# Inicializar archivo de tokens si no existe
init_token_file() {
    if [[ ! -f "$TOKEN_FILE" ]]; then
        cat > "$TOKEN_FILE" <<EOF
{
  "weekStart": "$(date -d 'last monday' +%Y-%m-%d)",
  "weeklyUsed": 0,
  "dailyUsage": {},
  "history": []
}
EOF
    fi
}

# Verificar si es nueva semana
check_new_week() {
    local current_week=$(date -d 'last monday' +%Y-%m-%d)
    local stored_week=$(jq -r '.weekStart' "$TOKEN_FILE")
    
    if [[ "$current_week" != "$stored_week" ]]; then
        echo "🔄 New week detected, resetting counters..."
        
        # Guardar semana anterior en historial
        local weekly_used=$(jq -r '.weeklyUsed' "$TOKEN_FILE")
        jq ".history += [{\"week\": \"$stored_week\", \"tokens\": $weekly_used}]" "$TOKEN_FILE" > "$TOKEN_FILE.tmp"
        mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
        
        # Reset
        jq ".weekStart = \"$current_week\" | .weeklyUsed = 0 | .dailyUsage = {}" "$TOKEN_FILE" > "$TOKEN_FILE.tmp"
        mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
    fi
}

# Agregar uso de tokens
add_tokens() {
    local tokens="$1"
    local date=$(date +%Y-%m-%d)
    
    # Actualizar totales
    jq ".weeklyUsed += $tokens | .dailyUsage.\"$date\" += $tokens" "$TOKEN_FILE" > "$TOKEN_FILE.tmp"
    mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
    
    check_budget_warnings
}

# Verificar warnings de presupuesto
check_budget_warnings() {
    local weekly_limit=$(jq -r '.tokenBudget.weeklyLimit' "$CONFIG_FILE")
    local warning_threshold=$(jq -r '.tokenBudget.warningThreshold' "$CONFIG_FILE")
    local critical_threshold=$(jq -r '.tokenBudget.criticalThreshold' "$CONFIG_FILE")
    local weekly_used=$(jq -r '.weeklyUsed' "$TOKEN_FILE")
    
    local usage_percent=$(echo "scale=2; $weekly_used / $weekly_limit" | bc)
    
    if (( $(echo "$usage_percent >= $critical_threshold" | bc -l) )); then
        "$SCRIPT_DIR/notifier.sh" critical \
            "Presupuesto CRÍTICO" \
            "Uso: ${weekly_used}/${weekly_limit} tokens (${usage_percent}%)
⚠️ Límite casi alcanzado!"
    elif (( $(echo "$usage_percent >= $warning_threshold" | bc -l) )); then
        "$SCRIPT_DIR/notifier.sh" warning \
            "Presupuesto en advertencia" \
            "Uso: ${weekly_used}/${weekly_limit} tokens (${usage_percent}%)"
    fi
}

# Mostrar estado
show_status() {
    local weekly_limit=$(jq -r '.tokenBudget.weeklyLimit' "$CONFIG_FILE")
    local weekly_used=$(jq -r '.weeklyUsed' "$TOKEN_FILE")
    local week_start=$(jq -r '.weekStart' "$TOKEN_FILE")
    local usage_percent=$(echo "scale=1; ($weekly_used / $weekly_limit) * 100" | bc)
    
    echo "📊 Token Budget Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Week: $week_start - $(date +%Y-%m-%d)"
    echo "Used: $weekly_used / $weekly_limit tokens ($usage_percent%)"
    echo ""
    echo "Daily breakdown:"
    jq -r '.dailyUsage | to_entries | .[] | "  \(.key): \(.value) tokens"' "$TOKEN_FILE"
}

# Main
main() {
    init_token_file
    check_new_week
    
    case "$1" in
        add)
            if [[ -z "$2" ]]; then
                echo "Usage: $0 add <tokens>"
                exit 1
            fi
            add_tokens "$2"
            echo "✅ Added $2 tokens"
            ;;
        status)
            show_status
            ;;
        *)
            show_status
            ;;
    esac
}

main "$@"

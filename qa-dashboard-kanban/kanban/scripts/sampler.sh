#!/bin/bash
# sampler.sh - Muestreo inteligente de logs por agente
# ⚠️ FIXED: Ahora extrae logs de journalctl (no de archivos inexistentes)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/agents-config.json"
DATA_DIR="$PROJECT_DIR/data"
SAMPLES_DIR="$DATA_DIR/samples"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%s)

# Crear directorio de samples si no existe
mkdir -p "$SAMPLES_DIR"

# Cargar configuración
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ Config not found: $CONFIG_FILE"
        exit 1
    fi
}

# Obtener samplesPerDay para un agente
get_samples_per_day() {
    local agent="$1"
    jq -r ".agents.\"$agent\".samplesPerDay // .agents.default.samplesPerDay // 20" "$CONFIG_FILE"
}

# Extraer logs de journalctl para un agente específico
get_agent_logs() {
    local agent="$1"
    local since="${2:-today}"
    
    # Extraer logs de journalctl filtrando por agente
    journalctl --user -u oc-gw.service --since "$since" --no-pager -o json 2>/dev/null | \
        jq -r 'select(.MESSAGE != null) | .MESSAGE' 2>/dev/null | \
        grep -i "\"agent\":\"$agent\"" 2>/dev/null || true
}

# Muestrear logs de un agente
sample_agent() {
    local agent="$1"
    local samples_needed=$(get_samples_per_day "$agent")
    
    echo "📊 Sampling agent: $agent ($samples_needed samples/day)"
    
    # Obtener logs de hoy desde journalctl
    local temp_log=$(mktemp)
    get_agent_logs "$agent" "today" > "$temp_log"
    
    local total_lines=$(wc -l < "$temp_log")
    
    if [[ $total_lines -eq 0 ]]; then
        echo "  ⚠️  No logs found for $agent today"
        rm "$temp_log"
        return
    fi
    
    # Calcular intervalo de muestreo
    local interval=$((total_lines / samples_needed))
    [[ $interval -eq 0 ]] && interval=1
    
    # Sample file
    local sample_file="$SAMPLES_DIR/${DATE}_${agent}_sample.log"
    
    # Muestreo sistemático
    awk "NR % $interval == 0" "$temp_log" | head -n "$samples_needed" > "$sample_file"
    
    local sampled_count=$(wc -l < "$sample_file")
    echo "  ✅ Sampled $sampled_count lines from $total_lines → $sample_file"
    
    # Guardar metadata
    cat > "$SAMPLES_DIR/${DATE}_${agent}_sample.meta" <<EOF
{
  "agent": "$agent",
  "date": "$DATE",
  "timestamp": $TIMESTAMP,
  "total_lines": $total_lines,
  "sampled_lines": $sampled_count,
  "interval": $interval,
  "source": "journalctl --user -u oc-gw.service"
}
EOF
    
    rm "$temp_log"
}

# Main
main() {
    load_config
    
    echo "🔍 Kanban QA - Log Sampler (journalctl edition)"
    echo "Date: $DATE"
    echo "Source: journalctl --user -u oc-gw.service"
    echo ""
    
    # Obtener lista de agentes (excepto default)
    agents=$(jq -r '.agents | keys[] | select(. != "default")' "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$agents" ]]; then
        echo "⚠️  No agents configured, using defaults"
        agents="pm phoenix iris-assistant iris-med chappie argus atlas quill"
    fi
    
    for agent in $agents; do
        sample_agent "$agent"
    done
    
    echo ""
    echo "✅ Sampling complete!"
}

main "$@"

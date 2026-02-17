#!/bin/bash
# event-logger.sh - Sistema de logging de eventos para Kanban QA

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
EVENTS_FILE="$PROJECT_DIR/data/events.jsonl"

# Función: log_event
# Registra un evento en events.jsonl
# Args: agente, origen, tipo, severidad, descripcion, accion_tomada, [task_id]
log_event() {
    local agente="$1"
    local origen="$2"
    local tipo="$3"
    local severidad="$4"
    local descripcion="$5"
    local accion_tomada="$6"
    local task_id="${7:-}"
    
    # Validaciones
    if [[ ! "$agente" =~ ^(pm|chappie|argus|iris-assistant|phoenix|atlas|quill|iris-med)$ ]]; then
        echo "⚠️  Warning: agente '$agente' no reconocido" >&2
    fi
    
    if [[ ! "$origen" =~ ^(logs|manual|cron|heartbeat)$ ]]; then
        echo "⚠️  Warning: origen '$origen' no válido" >&2
    fi
    
    if [[ ! "$tipo" =~ ^(error|warning|info)$ ]]; then
        echo "❌ Error: tipo debe ser error|warning|info" >&2
        return 1
    fi
    
    if [[ ! "$severidad" =~ ^(S0|S1|S2|S3)$ ]]; then
        echo "❌ Error: severidad debe ser S0|S1|S2|S3" >&2
        return 1
    fi
    
    if [[ ! "$accion_tomada" =~ ^(task_created|escalated|resolved|monitored)$ ]]; then
        echo "❌ Error: accion_tomada no válida" >&2
        return 1
    fi
    
    # Crear timestamp ISO8601 con timezone
    local timestamp=$(date -Iseconds)
    
    # Construir JSON
    local event_json=$(jq -n \
        --arg ts "$timestamp" \
        --arg ag "$agente" \
        --arg or "$origen" \
        --arg tp "$tipo" \
        --arg sv "$severidad" \
        --arg ds "$descripcion" \
        --arg at "$accion_tomada" \
        --arg ti "$task_id" \
        '{
            timestamp: $ts,
            agente: $ag,
            origen: $or,
            tipo: $tp,
            severidad: $sv,
            descripcion: $ds,
            accion_tomada: $at
        } + (if $ti != "" then {task_id: $ti} else {} end)')
    
    # Append a events.jsonl
    echo "$event_json" >> "$EVENTS_FILE"
    
    echo "✅ Evento registrado: $tipo/$severidad - $descripcion"
}

# Función: get_error_rate
# Calcula error_rate de las últimas N horas
# Args: horas (default 24)
get_error_rate() {
    local hours="${1:-24}"
    
    if [[ ! -f "$EVENTS_FILE" ]]; then
        echo "0.00"
        return
    fi
    
    # Calcular timestamp hace N horas
    local cutoff_ts=$(date -d "$hours hours ago" -Iseconds)
    
    # Contar eventos en ventana de tiempo
    local total_count=$(jq -r --arg cutoff "$cutoff_ts" \
        'select(.timestamp >= $cutoff) | 1' "$EVENTS_FILE" 2>/dev/null | wc -l)
    
    local error_count=$(jq -r --arg cutoff "$cutoff_ts" \
        'select(.timestamp >= $cutoff and .tipo == "error") | 1' "$EVENTS_FILE" 2>/dev/null | wc -l)
    
    if [[ $total_count -eq 0 ]]; then
        echo "0.00"
        return
    fi
    
    # Calcular ratio
    local rate=$(awk "BEGIN {printf \"%.2f\", ($error_count / $total_count) * 100}")
    echo "$rate"
}

# Función: get_events_summary
# Genera resumen de eventos de las últimas N horas
# Args: horas (default 24)
get_events_summary() {
    local hours="${1:-24}"
    
    if [[ ! -f "$EVENTS_FILE" ]]; then
        echo "No events found"
        return
    fi
    
    local cutoff_ts=$(date -d "$hours hours ago" -Iseconds)
    
    echo "📊 Event Summary (últimas ${hours}h)"
    echo "─────────────────────────────────"
    
    # Total eventos
    local total=$(jq -r --arg cutoff "$cutoff_ts" \
        'select(.timestamp >= $cutoff) | 1' "$EVENTS_FILE" 2>/dev/null | wc -l)
    echo "Total eventos: $total"
    
    # Por tipo
    local errors=$(jq -r --arg cutoff "$cutoff_ts" \
        'select(.timestamp >= $cutoff and .tipo == "error") | 1' "$EVENTS_FILE" 2>/dev/null | wc -l)
    local warnings=$(jq -r --arg cutoff "$cutoff_ts" \
        'select(.timestamp >= $cutoff and .tipo == "warning") | 1' "$EVENTS_FILE" 2>/dev/null | wc -l)
    local info=$(jq -r --arg cutoff "$cutoff_ts" \
        'select(.timestamp >= $cutoff and .tipo == "info") | 1' "$EVENTS_FILE" 2>/dev/null | wc -l)
    
    echo "  Errors: $errors"
    echo "  Warnings: $warnings"
    echo "  Info: $info"
    
    # Por severidad
    echo ""
    echo "Por severidad:"
    for sev in S0 S1 S2 S3; do
        local count=$(jq -r --arg cutoff "$cutoff_ts" --arg sev "$sev" \
            'select(.timestamp >= $cutoff and .severidad == $sev) | 1' "$EVENTS_FILE" 2>/dev/null | wc -l)
        echo "  $sev: $count"
    done
    
    # Error rate
    local error_rate=$(get_error_rate "$hours")
    echo ""
    echo "Error rate: ${error_rate}%"
    
    if (( $(echo "$error_rate > 5" | bc -l) )); then
        echo "⚠️  Error rate excede target (5%)"
    else
        echo "✅ Error rate dentro del target"
    fi
}

# CLI interface
case "${1:-}" in
    log)
        shift
        log_event "$@"
        ;;
    rate)
        get_error_rate "${2:-24}"
        ;;
    summary)
        get_events_summary "${2:-24}"
        ;;
    *)
        echo "Usage: $0 {log|rate|summary}"
        echo ""
        echo "Commands:"
        echo "  log <agente> <origen> <tipo> <severidad> <descripcion> <accion> [task_id]"
        echo "  rate [horas]         - Calcula error_rate (default 24h)"
        echo "  summary [horas]      - Muestra resumen de eventos (default 24h)"
        echo ""
        echo "Example:"
        echo "  $0 log argus cron error S1 'Memory usage high' task_created task-123"
        exit 1
        ;;
esac

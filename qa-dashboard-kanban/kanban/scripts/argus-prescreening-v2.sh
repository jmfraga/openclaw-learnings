#!/bin/bash
# argus-prescreening-v2.sh - Pre-screening con clasificación de severidad S0-S3

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/agents-config.json"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"
SAMPLES_DIR="$PROJECT_DIR/data/samples"
EVENT_LOGGER="$SCRIPT_DIR/event-logger.sh"
METRIC_LOGGER="$SCRIPT_DIR/log-metric.sh"
DATE=$(date +%Y-%m-%d)

# Patterns S3 - Critical - Sistema caído, pérdida de servicio
S3_PATTERNS=(
    "FATAL"
    "crashed"
    "cannot start"
    "service down"
    "database connection failed"
    "system halt"
)

# Patterns S2 - High - Degradación severa
S2_PATTERNS=(
    "ERROR"
    "CRITICAL"
    "Exception"
    "failed to"
    "cannot connect"
    "timeout"
    "out of memory"
)

# Patterns S1 - Medium - Problemas menores
S1_PATTERNS=(
    "WARNING"
    "WARN"
    "retry"
    "slow response"
    "limit exceeded"
    "deprecated"
)

# Patterns S0 - Low - Info/optimizaciones
S0_PATTERNS=(
    "INFO"
    "performance degradation"
    "suggestion"
    "optimization needed"
)

# Clasificar severidad basado en patterns
classify_severity() {
    local content="$1"
    
    # Check S3 primero (más crítico)
    for pattern in "${S3_PATTERNS[@]}"; do
        if echo "$content" | grep -qi "$pattern"; then
            echo "S3"
            return
        fi
    done
    
    # Check S2
    for pattern in "${S2_PATTERNS[@]}"; do
        if echo "$content" | grep -qi "$pattern"; then
            echo "S2"
            return
        fi
    done
    
    # Check S1
    for pattern in "${S1_PATTERNS[@]}"; do
        if echo "$content" | grep -qi "$pattern"; then
            echo "S1"
            return
        fi
    done
    
    # Default S0 (Low)
    echo "S0"
}

# Analizar sample de un agente
analyze_sample() {
    local sample_file="$1"
    local agent=$(basename "$sample_file" | cut -d'_' -f2)
    
    if [[ ! -f "$sample_file" ]]; then
        return
    fi
    
    echo "🔍 Analyzing: $agent"
    
    local issues=()
    local max_severity="S0"
    local issue_details=""
    
    # Buscar todos los patterns
    for pattern in "${S0_PATTERNS[@]}" "${S1_PATTERNS[@]}" "${S2_PATTERNS[@]}" "${S3_PATTERNS[@]}"; do
        local matches=$(grep -i "$pattern" "$sample_file" 2>/dev/null | head -n 2)
        if [[ -n "$matches" ]]; then
            local severity=$(classify_severity "$matches")
            issues+=("[$severity] Found '$pattern' in logs")
            issue_details="${issue_details}${matches}\n"
            
            # Actualizar max_severity si es más crítico (S3 > S2 > S1 > S0)
            case "$severity" in
                S3) max_severity="S3" ;;
                S2) [[ "$max_severity" != "S3" ]] && max_severity="S2" ;;
                S1) [[ "$max_severity" =~ ^(S0)$ ]] && max_severity="S1" ;;
            esac
        fi
    done
    
    # Crear task si hay issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        create_kanban_task "$agent" "$max_severity" "${issues[@]}"
    else
        echo "  ✅ No issues found"
    fi
}

# Crear task en Kanban con severidad
create_kanban_task() {
    local agent="$1"
    local severidad="$2"
    shift 2
    local issues=("$@")
    
    local task_id="task-$(date +%s)-$RANDOM"
    local timestamp=$(date -Iseconds)
    
    # Mapear severidad a priority para compatibilidad
    local priority="medium"
    case "$severidad" in
        S3) priority="critical" ;;
        S2) priority="high" ;;
        S1) priority="medium" ;;
        S0) priority="low" ;;
    esac
    
    # Determinar categoría basada en issues
    local category="general"
    if echo "${issues[@]}" | grep -qi "error\|exception\|fatal\|crashed"; then
        category="bug"
    elif echo "${issues[@]}" | grep -qi "timeout\|slow"; then
        category="performance"
    elif echo "${issues[@]}" | grep -qi "config\|deprecated"; then
        category="config"
    fi
    
    # Determinar tipo de evento
    local event_tipo="info"
    case "$severidad" in
        S3|S2) event_tipo="error" ;;
        S1) event_tipo="warning" ;;
        S0) event_tipo="info" ;;
    esac
    
    # Crear descripción
    local description=""
    for issue in "${issues[@]}"; do
        description="${description}• $issue\n"
    done
    
    # Agregar task a kanban.json
    local new_task=$(cat <<EOF
{
  "id": "$task_id",
  "title": "[$severidad] Issues detected in $agent",
  "description": "$description",
  "agent": "$agent",
  "category": "$category",
  "priority": "$priority",
  "severidad": "$severidad",
  "status": "pending",
  "createdAt": "$timestamp",
  "source": "argus-prescreening"
}
EOF
)
    
    # Agregar task usando script seguro (con backup + validación)
    "$SCRIPT_DIR/add-task.sh" "$new_task" || {
        echo "  ❌ Failed to add task (JSON validation failed)"
        return 1
    }
    
    echo "  ✅ Created task: $task_id ($severidad/$priority)"
    
    # Registrar evento (legacy)
    local event_desc="Issues detected in $agent: ${#issues[@]} problems found (${severidad})"
    "$EVENT_LOGGER" log "argus" "cron" "$event_tipo" "$severidad" "$event_desc" "task_created" "$task_id"
    
    # Log métrica en Dashboard QA 3.0
    "$METRIC_LOGGER" "$agent" "$event_tipo" "$severidad" "null" "false" "0" "false" "0" "$category" "null" "argus-cron-$DATE" "0" "claude-haiku-4-5" 2>/dev/null || true
    
    # Notificar si es S3 o S2 (Critical/High)
    if [[ "$severidad" =~ ^(S3|S2)$ ]]; then
        "$SCRIPT_DIR/notifier.sh" critical \
            "[$severidad] Critical issues in $agent" \
            "Task #$task_id created
Issues: ${#issues[@]}
Severity: $severidad
Review dashboard: http://100.71.128.102:8080/qa/" 2>/dev/null || true
    fi
}

# Main
main() {
    echo "👁️ Argus Pre-screening v2 - Log Analysis with Severity Classification"
    echo "Date: $DATE"
    echo ""
    
    # Encontrar todos los samples de hoy
    local samples=$(find "$SAMPLES_DIR" -name "${DATE}_*_sample.log" -type f 2>/dev/null)
    
    if [[ -z "$samples" ]]; then
        echo "⚠️  No samples found for today"
        echo "Run sampler.sh first"
        
        # Log evento (legacy)
        "$EVENT_LOGGER" log "argus" "cron" "warning" "S3" "No samples found for prescreening" "monitored"
        
        # Log métrica - failure del sistema de sampling
        "$METRIC_LOGGER" "argus" "error" "S3" "null" "true" "0" "false" "0" "infra" "pm" "argus-cron-$DATE" "0" "claude-haiku-4-5" 2>/dev/null || true
        
        exit 1
    fi
    
    # Analizar cada sample
    local analyzed=0
    for sample in $samples; do
        analyze_sample "$sample"
        ((analyzed++))
    done
    
    echo ""
    echo "✅ Pre-screening complete! Analyzed $analyzed samples"
    
    # Mostrar resumen de eventos
    echo ""
    "$EVENT_LOGGER" summary 24
    
    # Ejecutar delegator si hay tareas pendientes
    local pending_count=$(jq '[.tasks[] | select(.status == "pending")] | length' "$KANBAN_FILE")
    if [[ $pending_count -gt 0 ]]; then
        echo ""
        echo "🤖 Running auto-delegation..."
        "$SCRIPT_DIR/delegator.sh" process 2>/dev/null || true
    fi
}

main "$@"

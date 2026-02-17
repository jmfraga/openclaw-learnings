#!/bin/bash
# argus-prescreening.sh - Pre-screening de logs para detectar issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/agents-config.json"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"
SAMPLES_DIR="$PROJECT_DIR/data/samples"
DATE=$(date +%Y-%m-%d)

# Patterns críticos (regex)
CRITICAL_PATTERNS=(
    "ERROR"
    "CRITICAL"
    "FATAL"
    "Exception"
    "failed to"
    "cannot"
    "timeout"
    "crashed"
)

# Patterns de advertencia
WARNING_PATTERNS=(
    "WARNING"
    "WARN"
    "deprecated"
    "retry"
    "slow"
    "limit exceeded"
)

# Analizar sample de un agente
analyze_sample() {
    local sample_file="$1"
    local agent=$(basename "$sample_file" | cut -d'_' -f2)
    
    if [[ ! -f "$sample_file" ]]; then
        return
    fi
    
    echo "🔍 Analyzing: $agent"
    
    local critical_count=0
    local warning_count=0
    local issues=()
    
    # Buscar patterns críticos
    for pattern in "${CRITICAL_PATTERNS[@]}"; do
        local matches=$(grep -i "$pattern" "$sample_file" 2>/dev/null | head -n 3)
        if [[ -n "$matches" ]]; then
            ((critical_count++))
            issues+=("CRITICAL: Found '$pattern' in $agent logs")
        fi
    done
    
    # Buscar patterns de advertencia
    for pattern in "${WARNING_PATTERNS[@]}"; do
        local matches=$(grep -i "$pattern" "$sample_file" 2>/dev/null | head -n 3)
        if [[ -n "$matches" ]]; then
            ((warning_count++))
            issues+=("WARNING: Found '$pattern' in $agent logs")
        fi
    done
    
    # Crear tasks en Kanban si hay issues
    if [[ $critical_count -gt 0 ]] || [[ $warning_count -gt 0 ]]; then
        local priority="medium"
        [[ $critical_count -gt 0 ]] && priority="critical"
        [[ $warning_count -gt 2 ]] && priority="high"
        
        create_kanban_task "$agent" "$priority" "${issues[@]}"
    fi
    
    echo "  Critical: $critical_count | Warnings: $warning_count"
}

# Crear task en Kanban
create_kanban_task() {
    local agent="$1"
    local priority="$2"
    shift 2
    local issues=("$@")
    
    local task_id="task-$(date +%s)-$RANDOM"
    local timestamp=$(date -Iseconds)
    
    # Determinar categoría basada en issues
    local category="general"
    if echo "${issues[@]}" | grep -qi "error\|exception\|fatal"; then
        category="bug"
    elif echo "${issues[@]}" | grep -qi "timeout\|slow"; then
        category="performance"
    fi
    
    # Crear descripción
    local description=""
    for issue in "${issues[@]}"; do
        description="${description}• $issue\n"
    done
    
    # Agregar task a kanban.json
    local new_task=$(cat <<EOF
{
  "id": "$task_id",
  "title": "Issues detected in $agent",
  "description": "$description",
  "agent": "$agent",
  "category": "$category",
  "priority": "$priority",
  "status": "pending",
  "createdAt": "$timestamp",
  "source": "argus-prescreening"
}
EOF
)
    
    # Agregar a array de tasks
    # FIX 2026-02-15: Actualizar metadata.totalTasks automáticamente
    jq --argjson task "$new_task" \
        '.tasks += [$task] | 
         .lastUpdate = now | 
         .lastUpdate |= todate | 
         .metadata.totalTasks = (.tasks | length)' \
        "$KANBAN_FILE" > "$KANBAN_FILE.tmp"
    mv "$KANBAN_FILE.tmp" "$KANBAN_FILE"
    
    echo "  ✅ Created task: $task_id ($priority)"
    
    # Notificar si es crítico
    if [[ "$priority" == "critical" ]]; then
        "$SCRIPT_DIR/notifier.sh" critical \
            "Critical issues in $agent" \
            "Task #$task_id created
Issues: ${#issues[@]}
Review dashboard: http://localhost:8080"
    fi
}

# Main
main() {
    echo "👁️ Argus Pre-screening - Log Analysis"
    echo "Date: $DATE"
    echo ""
    
    # Encontrar todos los samples de hoy
    local samples=$(find "$SAMPLES_DIR" -name "${DATE}_*_sample.log" -type f)
    
    if [[ -z "$samples" ]]; then
        echo "⚠️  No samples found for today"
        echo "Run sampler.sh first"
        exit 1
    fi
    
    # Analizar cada sample
    for sample in $samples; do
        analyze_sample "$sample"
    done
    
    echo ""
    echo "✅ Pre-screening complete!"
    
    # Ejecutar delegator si hay tareas pendientes
    local pending_count=$(jq '[.tasks[] | select(.status == "pending")] | length' "$KANBAN_FILE")
    if [[ $pending_count -gt 0 ]]; then
        echo ""
        echo "🤖 Running auto-delegation..."
        "$SCRIPT_DIR/delegator.sh" process
    fi
}

main "$@"

#!/bin/bash
# delegator.sh - Auto-delegación inteligente a PM y CHAPPiE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/agents-config.json"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"

# Categorías que delegan a PM
PM_CATEGORIES=("infra" "config" "arquitectura" "deployment" "infrastructure")

# Categorías que delegan a CHAPPiE
CHAPPIE_CATEGORIES=("code" "skills" "tooling" "bug" "development" "implementation")

# Determinar agente para delegación
determine_agent() {
    local category="$1"
    local title="$2"
    local description="$3"
    
    # Buscar en categorías PM
    for pm_cat in "${PM_CATEGORIES[@]}"; do
        if [[ "$category" =~ $pm_cat ]] || [[ "$title" =~ $pm_cat ]] || [[ "$description" =~ $pm_cat ]]; then
            echo "pm"
            return
        fi
    done
    
    # Buscar en categorías CHAPPiE
    for chappie_cat in "${CHAPPIE_CATEGORIES[@]}"; do
        if [[ "$category" =~ $chappie_cat ]] || [[ "$title" =~ $chappie_cat ]] || [[ "$description" =~ $chappie_cat ]]; then
            echo "chappie"
            return
        fi
    done
    
    echo "none"
}

# Delegar tarea
delegate_task() {
    local task_id="$1"
    local agent="$2"
    
    # Actualizar estado en kanban
    jq --arg id "$task_id" --arg agent "$agent" --arg ts "$(date -Iseconds)" \
        '(.tasks[] | select(.id == $id)) |= 
        (.delegatedTo = $agent | .delegatedAt = $ts | .status = "delegated")' \
        "$KANBAN_FILE" > "$KANBAN_FILE.tmp"
    mv "$KANBAN_FILE.tmp" "$KANBAN_FILE"
    
    echo "✅ Task $task_id delegated to $agent"
}

# Procesar cola de tareas pendientes
process_queue() {
    if [[ ! -f "$KANBAN_FILE" ]]; then
        echo "⚠️  No kanban file found"
        return
    fi
    
    # Buscar tareas "pending" que puedan delegarse
    local pending_tasks=$(jq -r '.tasks[] | select(.status == "pending") | .id' "$KANBAN_FILE")
    
    for task_id in $pending_tasks; do
        local category=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .category' "$KANBAN_FILE")
        local title=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .title' "$KANBAN_FILE")
        local description=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .description' "$KANBAN_FILE")
        
        local target_agent=$(determine_agent "$category" "$title" "$description")
        
        if [[ "$target_agent" != "none" ]]; then
            echo "🔄 Delegating task $task_id to $target_agent"
            delegate_task "$task_id" "$target_agent"
            
            # Notificar
            "$SCRIPT_DIR/notifier.sh" delegation "$target_agent" "$task_id" "$category"
            
            # TODO: Llamar a PM o CHAPPiE vía openclaw CLI
            # openclaw agent invoke $target_agent "Review and resolve Kanban task #$task_id: $title"
        fi
    done
}

# Main
main() {
    echo "🤖 Kanban QA - Auto Delegator"
    echo ""
    
    case "$1" in
        process)
            process_queue
            ;;
        check)
            # Solo verificar sin delegar
            task_id="$2"
            category="$3"
            title="$4"
            description="$5"
            agent=$(determine_agent "$category" "$title" "$description")
            echo "$agent"
            ;;
        *)
            process_queue
            ;;
    esac
}

main "$@"

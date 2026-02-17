#!/bin/bash
# pm-integration.sh - Integración con PM para issues de infra/config/arquitectura

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"

# Invocar PM con una tarea
invoke_pm() {
    local task_id="$1"
    local task_title=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .title' "$KANBAN_FILE")
    local task_desc=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .description' "$KANBAN_FILE")
    local task_category=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .category' "$KANBAN_FILE")
    
    echo "📞 Invoking PM for task: $task_id"
    
    # Construir prompt para PM
    local prompt=$(cat <<EOF
Kanban QA Task Review - Auto-delegated

Task ID: $task_id
Category: $task_category
Title: $task_title

Description:
$task_desc

---

As PM, please:
1. Review this issue
2. Determine if it's a real problem or false positive
3. If real, take action to resolve (fix config, update infra, document)
4. Update the task status

When complete, update kanban-qa/data/kanban.json:
- Change status to "in-progress" when you start
- Change to "resolved" when done
- Add resolution notes

Dashboard: http://localhost:8080
EOF
)
    
    # Llamar a PM usando openclaw CLI
    # TODO: Descomentar cuando OpenClaw soporte agent invoke
    # openclaw agent invoke pm "$prompt"
    
    # Por ahora, loguear el intento
    echo "$prompt" > "$PROJECT_DIR/data/pm-tasks/${task_id}.txt"
    echo "  ✅ PM task queued: $PROJECT_DIR/data/pm-tasks/${task_id}.txt"
    
    # Actualizar estado a "in-progress"
    jq --arg id "$task_id" --arg ts "$(date -Iseconds)" \
        '(.tasks[] | select(.id == $id)) |= 
        (.status = "in-progress" | .assignedAt = $ts)' \
        "$KANBAN_FILE" > "$KANBAN_FILE.tmp"
    mv "$KANBAN_FILE.tmp" "$KANBAN_FILE"
}

# Procesar tareas delegadas a PM
process_pm_tasks() {
    mkdir -p "$PROJECT_DIR/data/pm-tasks"
    
    local pm_tasks=$(jq -r '.tasks[] | select(.delegatedTo == "pm" and .status == "delegated") | .id' "$KANBAN_FILE")
    
    for task_id in $pm_tasks; do
        invoke_pm "$task_id"
    done
}

# Main
case "$1" in
    invoke)
        if [[ -z "$2" ]]; then
            echo "Usage: $0 invoke <task_id>"
            exit 1
        fi
        invoke_pm "$2"
        ;;
    process)
        process_pm_tasks
        ;;
    *)
        process_pm_tasks
        ;;
esac

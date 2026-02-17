#!/bin/bash
# chappie-integration.sh - Integración con CHAPPiE para code/skills/tooling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"

# Invocar CHAPPiE con una tarea
invoke_chappie() {
    local task_id="$1"
    local task_title=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .title' "$KANBAN_FILE")
    local task_desc=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .description' "$KANBAN_FILE")
    local task_category=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .category' "$KANBAN_FILE")
    
    echo "📞 Invoking CHAPPiE for task: $task_id"
    
    # Construir prompt para CHAPPiE
    local prompt=$(cat <<EOF
Kanban QA Task Review - Auto-delegated

Task ID: $task_id
Category: $task_category
Title: $task_title

Description:
$task_desc

---

As CHAPPiE, please:
1. Review this code/skill/tooling issue
2. Determine if it's a bug, improvement, or false positive
3. If actionable, implement the fix or enhancement
4. Test the changes
5. Update the task status

When complete, update kanban-qa/data/kanban.json:
- Change status to "in-progress" when you start
- Change to "resolved" when done
- Add resolution notes and commit hash if code changed

Dashboard: http://localhost:8080
EOF
)
    
    # Llamar a CHAPPiE usando openclaw CLI
    # TODO: Descomentar cuando OpenClaw soporte agent invoke
    # openclaw agent invoke chappie "$prompt"
    
    # Por ahora, loguear el intento
    mkdir -p "$PROJECT_DIR/data/chappie-tasks"
    echo "$prompt" > "$PROJECT_DIR/data/chappie-tasks/${task_id}.txt"
    echo "  ✅ CHAPPiE task queued: $PROJECT_DIR/data/chappie-tasks/${task_id}.txt"
    
    # Actualizar estado a "in-progress"
    jq --arg id "$task_id" --arg ts "$(date -Iseconds)" \
        '(.tasks[] | select(.id == $id)) |= 
        (.status = "in-progress" | .assignedAt = $ts)' \
        "$KANBAN_FILE" > "$KANBAN_FILE.tmp"
    mv "$KANBAN_FILE.tmp" "$KANBAN_FILE"
}

# Procesar tareas delegadas a CHAPPiE
process_chappie_tasks() {
    local chappie_tasks=$(jq -r '.tasks[] | select(.delegatedTo == "chappie" and .status == "delegated") | .id' "$KANBAN_FILE")
    
    for task_id in $chappie_tasks; do
        invoke_chappie "$task_id"
    done
}

# Main
case "$1" in
    invoke)
        if [[ -z "$2" ]]; then
            echo "Usage: $0 invoke <task_id>"
            exit 1
        fi
        invoke_chappie "$2"
        ;;
    process)
        process_chappie_tasks
        ;;
    *)
        process_chappie_tasks
        ;;
esac

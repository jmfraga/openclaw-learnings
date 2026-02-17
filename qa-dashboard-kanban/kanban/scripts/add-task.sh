#!/bin/bash
# add-task.sh - Agregar task al Kanban QA de forma segura
# Uso: add-task.sh <task_json_string>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"
BACKUP_DIR="$PROJECT_DIR/data/backups"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Validar que se pasó un argumento
if [[ -z "$1" ]]; then
    echo "❌ Error: Task JSON required"
    echo "Usage: add-task.sh '<task_json_string>'"
    exit 1
fi

NEW_TASK="$1"

# Validar que NEW_TASK es JSON válido
echo "$NEW_TASK" | jq . >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "❌ Error: Invalid JSON provided"
    echo "$NEW_TASK"
    exit 1
fi

# Validar que kanban.json existe y es válido
if [[ ! -f "$KANBAN_FILE" ]]; then
    echo "❌ Error: Kanban file not found: $KANBAN_FILE"
    exit 1
fi

# BACKUP AUTOMÁTICO antes de modificar
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
cp "$KANBAN_FILE" "$BACKUP_DIR/kanban.json.bak-$BACKUP_TIMESTAMP"

# Validar JSON de entrada
jq . "$KANBAN_FILE" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "❌ Error: kanban.json is corrupted before operation"
    echo "Backup saved at: $BACKUP_DIR/kanban.json.bak-$BACKUP_TIMESTAMP"
    exit 1
fi

# Agregar task usando jq (método seguro)
# FIX 2026-02-15: Actualizar metadata.totalTasks automáticamente
jq --argjson task "$NEW_TASK" \
   '.tasks += [$task] | 
    .lastUpdate = now | 
    .lastUpdate |= todate | 
    .metadata.totalTasks = (.tasks | length)' \
   "$KANBAN_FILE" > "$KANBAN_FILE.tmp"

# Validar JSON de salida
jq . "$KANBAN_FILE.tmp" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "❌ Error: Generated JSON is invalid"
    echo "Restoring from backup..."
    mv "$BACKUP_DIR/kanban.json.bak-$BACKUP_TIMESTAMP" "$KANBAN_FILE"
    rm -f "$KANBAN_FILE.tmp"
    exit 1
fi

# Reemplazar archivo original
mv "$KANBAN_FILE.tmp" "$KANBAN_FILE"

# Extraer task ID para confirmación
TASK_ID=$(echo "$NEW_TASK" | jq -r '.id')

echo "✅ Task added: $TASK_ID"
echo "   Backup: $BACKUP_DIR/kanban.json.bak-$BACKUP_TIMESTAMP"

exit 0

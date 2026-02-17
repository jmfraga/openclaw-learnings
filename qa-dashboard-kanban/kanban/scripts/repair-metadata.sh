#!/bin/bash
# repair-metadata.sh - Reparar metadata.totalTasks desincronizado
# Creado: 2026-02-15 por CHAPPiE
# Fix para: metadata.totalTasks != (.tasks | length)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KANBAN_FILE="$PROJECT_DIR/data/kanban.json"
BACKUP_DIR="$PROJECT_DIR/data/backups"

echo "🔧 Kanban Metadata Repair Tool"
echo "================================"
echo ""

# Validar que kanban.json existe
if [[ ! -f "$KANBAN_FILE" ]]; then
    echo "❌ Error: Kanban file not found: $KANBAN_FILE"
    exit 1
fi

# Validar JSON
if ! jq empty "$KANBAN_FILE" 2>/dev/null; then
    echo "❌ Error: kanban.json is not valid JSON"
    exit 1
fi

# Diagnosticar estado actual
echo "📊 Estado actual:"
TASKS_ACTUAL=$(jq '.tasks | length' "$KANBAN_FILE")
TASKS_META=$(jq '.metadata.totalTasks' "$KANBAN_FILE")

echo "   Tasks reales:    $TASKS_ACTUAL"
echo "   Metadata count:  $TASKS_META"
echo ""

if [[ "$TASKS_ACTUAL" == "$TASKS_META" ]]; then
    echo "✅ Metadata ya está sincronizado. No se requiere reparación."
    exit 0
fi

echo "⚠️  Desincronización detectada!"
echo "   Diferencia: $((TASKS_ACTUAL - TASKS_META)) tasks"
echo ""

# Crear backup
mkdir -p "$BACKUP_DIR"
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/kanban.json.bak-repair-$BACKUP_TIMESTAMP"

echo "💾 Creando backup..."
cp "$KANBAN_FILE" "$BACKUP_FILE"
echo "   Guardado: $BACKUP_FILE"
echo ""

# Reparar metadata
echo "🔨 Reparando metadata..."
jq '.metadata.totalTasks = (.tasks | length)' "$KANBAN_FILE" > "$KANBAN_FILE.tmp"

# Validar resultado
if ! jq empty "$KANBAN_FILE.tmp" 2>/dev/null; then
    echo "❌ Error: Archivo reparado no es JSON válido"
    echo "   Restaurando desde backup..."
    rm -f "$KANBAN_FILE.tmp"
    exit 1
fi

# Verificar que la reparación fue exitosa
TASKS_REPAIRED=$(jq '.metadata.totalTasks' "$KANBAN_FILE.tmp")
if [[ "$TASKS_REPAIRED" != "$TASKS_ACTUAL" ]]; then
    echo "❌ Error: Reparación falló"
    echo "   Esperado: $TASKS_ACTUAL, Obtenido: $TASKS_REPAIRED"
    rm -f "$KANBAN_FILE.tmp"
    exit 1
fi

# Aplicar cambios
mv "$KANBAN_FILE.tmp" "$KANBAN_FILE"

echo "✅ Reparación completada!"
echo ""
echo "📊 Estado final:"
echo "   Tasks reales:    $(jq '.tasks | length' "$KANBAN_FILE")"
echo "   Metadata count:  $(jq '.metadata.totalTasks' "$KANBAN_FILE")"
echo ""
echo "💾 Backup disponible en:"
echo "   $BACKUP_FILE"
echo ""
echo "✅ kanban.json ahora está sincronizado."

exit 0

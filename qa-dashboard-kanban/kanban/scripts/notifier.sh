#!/bin/bash
# notifier.sh - Notificaciones Telegram sin tokens (bash puro)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/agents-config.json"

# Cargar chat ID
CHAT_ID=$(jq -r '.telegram.chatId' "$CONFIG_FILE")

# Detectar bot token de OpenClaw
TELEGRAM_TOKEN=""
if [[ -f "$HOME/.openclaw/config.json" ]]; then
    TELEGRAM_TOKEN=$(jq -r '.telegram.botToken // empty' "$HOME/.openclaw/config.json")
fi

if [[ -z "$TELEGRAM_TOKEN" ]]; then
    echo "⚠️  Telegram token not found in OpenClaw config"
    exit 1
fi

# Función para enviar mensaje
send_message() {
    local message="$1"
    local parse_mode="${2:-Markdown}"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$CHAT_ID\",
            \"text\": \"$message\",
            \"parse_mode\": \"$parse_mode\"
        }" > /dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Notification sent"
    else
        echo "❌ Failed to send notification"
    fi
}

# Tipos de notificaciones
notify_critical() {
    local title="$1"
    local details="$2"
    send_message "🚨 *CRITICAL - Kanban QA*

$title

$details

_$(date '+%Y-%m-%d %H:%M')_"
}

notify_warning() {
    local title="$1"
    local details="$2"
    send_message "⚠️ *WARNING - Kanban QA*

$title

$details

_$(date '+%Y-%m-%d %H:%M')_"
}

notify_info() {
    local title="$1"
    local details="$2"
    send_message "ℹ️ *Kanban QA*

$title

$details

_$(date '+%Y-%m-%d %H:%M')_"
}

notify_delegation() {
    local agent="$1"
    local task_id="$2"
    local category="$3"
    send_message "🔄 *Auto-delegación*

Task #$task_id delegada a *$agent*
Categoría: $category

Dashboard: http://localhost:8080

_$(date '+%Y-%m-%d %H:%M')_"
}

# Main
case "$1" in
    critical)
        notify_critical "$2" "$3"
        ;;
    warning)
        notify_warning "$2" "$3"
        ;;
    info)
        notify_info "$2" "$3"
        ;;
    delegation)
        notify_delegation "$2" "$3" "$4"
        ;;
    *)
        echo "Usage: $0 {critical|warning|info|delegation} <title> <details> [category]"
        exit 1
        ;;
esac

#!/bin/bash
# server.sh - Simple web server for Kanban dashboard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
PORT=8080

# Inicializar datos si no existen
init_data() {
    if [[ ! -f "$DATA_DIR/kanban.json" ]]; then
        cat > "$DATA_DIR/kanban.json" <<'EOF'
{
  "tasks": [],
  "lastUpdate": null
}
EOF
    fi
    
    if [[ ! -f "$DATA_DIR/token-usage.json" ]]; then
        cat > "$DATA_DIR/token-usage.json" <<EOF
{
  "weekStart": "$(date -d 'last monday' +%Y-%m-%d)",
  "weeklyUsed": 0,
  "dailyUsage": {},
  "history": []
}
EOF
    fi
}

# Matar servidor anterior si existe
kill_existing() {
    local pid=$(lsof -ti:$PORT 2>/dev/null)
    if [[ -n "$pid" ]]; then
        echo "🔄 Killing existing server on port $PORT (PID: $pid)"
        kill -9 $pid 2>/dev/null
        sleep 1
    fi
}

# Servidor HTTP simple con nc
start_server() {
    echo "🚀 Starting Kanban QA Dashboard on http://localhost:$PORT"
    echo "📊 Dashboard ready!"
    echo ""
    echo "Press Ctrl+C to stop"
    
    while true; do
        {
            read -r request
            
            # Parse request
            path=$(echo "$request" | awk '{print $2}')
            
            # Route handling
            if [[ "$path" == "/" ]] || [[ "$path" == "/index.html" ]]; then
                # Serve HTML
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: text/html\r"
                echo -e "\r"
                cat "$SCRIPT_DIR/index.html"
                
            elif [[ "$path" == "/api/kanban" ]]; then
                # Serve kanban data
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: application/json\r"
                echo -e "Access-Control-Allow-Origin: *\r"
                echo -e "\r"
                cat "$DATA_DIR/kanban.json"
                
            elif [[ "$path" == "/api/tokens" ]]; then
                # Serve token data
                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: application/json\r"
                echo -e "Access-Control-Allow-Origin: *\r"
                echo -e "\r"
                cat "$DATA_DIR/token-usage.json"
                
            else
                # 404
                echo -e "HTTP/1.1 404 Not Found\r"
                echo -e "Content-Type: text/plain\r"
                echo -e "\r"
                echo "404 - Not Found"
            fi
        } | nc -l -p $PORT -q 1 2>/dev/null
    done
}

# Main
main() {
    init_data
    kill_existing
    start_server
}

# Handle Ctrl+C
trap 'echo ""; echo "🛑 Server stopped"; exit 0' INT

main "$@"

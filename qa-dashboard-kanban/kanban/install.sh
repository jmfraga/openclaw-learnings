#!/bin/bash
# install.sh - Instalación y verificación del sistema Kanban QA

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👁️  Kanban QA - Installation & Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar dependencias
echo "🔍 Checking dependencies..."

check_command() {
    if command -v "$1" &> /dev/null; then
        echo "  ✅ $1"
    else
        echo "  ❌ $1 - NOT FOUND"
        MISSING_DEPS=true
    fi
}

MISSING_DEPS=false
check_command "bash"
check_command "jq"
check_command "curl"
check_command "python3"

if [[ "$MISSING_DEPS" == "true" ]]; then
    echo ""
    echo "⚠️  Missing dependencies. Install them first:"
    echo "  sudo apt-get install jq curl python3"
    exit 1
fi

echo ""
echo "✅ All dependencies found!"
echo ""

# Verificar estructura
echo "📁 Verifying structure..."

check_dir() {
    if [[ -d "$1" ]]; then
        echo "  ✅ $1"
    else
        echo "  ⚠️  $1 - creating..."
        mkdir -p "$1"
    fi
}

check_dir "$SCRIPT_DIR/config"
check_dir "$SCRIPT_DIR/scripts"
check_dir "$SCRIPT_DIR/dashboard"
check_dir "$SCRIPT_DIR/data"
check_dir "$SCRIPT_DIR/data/samples"
check_dir "$SCRIPT_DIR/data/pm-tasks"
check_dir "$SCRIPT_DIR/data/chappie-tasks"

echo ""

# Verificar archivos de configuración
echo "⚙️  Verifying configuration..."

if [[ -f "$SCRIPT_DIR/config/agents-config.json" ]]; then
    echo "  ✅ agents-config.json"
else
    echo "  ❌ agents-config.json missing!"
    exit 1
fi

if [[ -f "$SCRIPT_DIR/data/kanban.json" ]]; then
    echo "  ✅ kanban.json"
else
    echo "  ❌ kanban.json missing!"
    exit 1
fi

if [[ -f "$SCRIPT_DIR/data/token-usage.json" ]]; then
    echo "  ✅ token-usage.json"
else
    echo "  ❌ token-usage.json missing!"
    exit 1
fi

echo ""

# Verificar permisos de scripts
echo "🔐 Setting script permissions..."

chmod +x "$SCRIPT_DIR/scripts"/*.sh
chmod +x "$SCRIPT_DIR/dashboard/server.sh"
chmod +x "$SCRIPT_DIR/install.sh"

echo "  ✅ Permissions set"
echo ""

# Test básico
echo "🧪 Running basic tests..."

# Test JSON parsing
if jq empty "$SCRIPT_DIR/config/agents-config.json" 2>/dev/null; then
    echo "  ✅ Config JSON valid"
else
    echo "  ❌ Config JSON invalid!"
    exit 1
fi

if jq empty "$SCRIPT_DIR/data/kanban.json" 2>/dev/null; then
    echo "  ✅ Kanban JSON valid"
else
    echo "  ❌ Kanban JSON invalid!"
    exit 1
fi

echo ""

# Verificar OpenClaw
echo "🤖 Checking OpenClaw integration..."

if [[ -f "$HOME/.openclaw/config.json" ]]; then
    echo "  ✅ OpenClaw config found"
    
    # Verificar token de Telegram
    TELEGRAM_TOKEN=$(jq -r '.telegram.botToken // empty' "$HOME/.openclaw/config.json" 2>/dev/null)
    if [[ -n "$TELEGRAM_TOKEN" ]]; then
        echo "  ✅ Telegram bot token configured"
    else
        echo "  ⚠️  Telegram bot token not found (notifications disabled)"
    fi
else
    echo "  ⚠️  OpenClaw config not found at $HOME/.openclaw/config.json"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Quick Start:"
echo ""
echo "  1. Start Dashboard:"
echo "     cd $SCRIPT_DIR/dashboard"
echo "     python3 server.py"
echo ""
echo "  2. Run Daily Workflow:"
echo "     cd $SCRIPT_DIR/scripts"
echo "     ./run-daily.sh"
echo ""
echo "  3. Open Dashboard:"
echo "     http://localhost:8080"
echo ""
echo "📖 Full documentation: $SCRIPT_DIR/README.md"
echo ""

#!/bin/bash
# verify.sh - Verificación rápida del sistema Kanban QA

echo "════════════════════════════════════════════════════════════════"
echo "👁️  Kanban QA - System Verification"
echo "════════════════════════════════════════════════════════════════"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0
WARN=0

check() {
    if eval "$2" &>/dev/null; then
        echo "  ✅ $1"
        ((PASS++))
    else
        echo "  ❌ $1"
        ((FAIL++))
    fi
}

check_warn() {
    if eval "$2" &>/dev/null; then
        echo "  ✅ $1"
        ((PASS++))
    else
        echo "  ⚠️  $1"
        ((WARN++))
    fi
}

echo "📦 Dependencies:"
check "bash" "command -v bash"
check "jq" "command -v jq"
check "curl" "command -v curl"
check "python3" "command -v python3"
echo ""

echo "📁 File Structure:"
check "config/" "test -d config"
check "scripts/" "test -d scripts"
check "dashboard/" "test -d dashboard"
check "data/" "test -d data"
check "data/samples/" "test -d data/samples"
check "data/pm-tasks/" "test -d data/pm-tasks"
check "data/chappie-tasks/" "test -d data/chappie-tasks"
echo ""

echo "⚙️  Configuration Files:"
check "agents-config.json" "test -f config/agents-config.json"
check "kanban.json" "test -f data/kanban.json"
check "token-usage.json" "test -f data/token-usage.json"
check "agents-config.json valid" "jq empty config/agents-config.json"
check "kanban.json valid" "jq empty data/kanban.json"
check "token-usage.json valid" "jq empty data/token-usage.json"
echo ""

echo "🛠️  Scripts (executable):"
check "sampler.sh" "test -x scripts/sampler.sh"
check "argus-prescreening.sh" "test -x scripts/argus-prescreening.sh"
check "delegator.sh" "test -x scripts/delegator.sh"
check "pm-integration.sh" "test -x scripts/pm-integration.sh"
check "chappie-integration.sh" "test -x scripts/chappie-integration.sh"
check "token-tracker.sh" "test -x scripts/token-tracker.sh"
check "notifier.sh" "test -x scripts/notifier.sh"
check "run-daily.sh" "test -x scripts/run-daily.sh"
echo ""

echo "🎨 Dashboard:"
check "index.html" "test -f dashboard/index.html"
check "server.py" "test -f dashboard/server.py"
check "server.py executable" "test -x dashboard/server.py"
check "server.sh" "test -f dashboard/server.sh"
echo ""

echo "📚 Documentation:"
check "INDEX.md" "test -f INDEX.md"
check "README.md" "test -f README.md"
check "RESUMEN_EJECUTIVO.md" "test -f RESUMEN_EJECUTIVO.md"
check "QUICK_START.md" "test -f QUICK_START.md"
check "IMPLEMENTATION_REPORT.md" "test -f IMPLEMENTATION_REPORT.md"
check "DEPLOYMENT_CHECKLIST.md" "test -f DEPLOYMENT_CHECKLIST.md"
echo ""

echo "🔧 Utilities:"
check "install.sh" "test -x install.sh"
check "test-data.sh" "test -x test-data.sh"
check "verify.sh" "test -x verify.sh"
echo ""

echo "🤖 OpenClaw Integration:"
check_warn "OpenClaw config" "test -f ~/.openclaw/config.json"
if [[ -f ~/.openclaw/config.json ]]; then
    TOKEN=$(jq -r '.telegram.botToken // empty' ~/.openclaw/config.json 2>/dev/null)
    if [[ -n "$TOKEN" ]]; then
        echo "  ✅ Telegram bot token configured"
        ((PASS++))
    else
        echo "  ⚠️  Telegram bot token not configured"
        ((WARN++))
    fi
fi
echo ""

echo "📊 Sample Data:"
TASKS=$(jq '.tasks | length' data/kanban.json 2>/dev/null || echo 0)
TOKENS=$(jq '.weeklyUsed' data/token-usage.json 2>/dev/null || echo 0)
echo "  • Tasks in Kanban: $TASKS"
echo "  • Tokens used: $TOKENS"
echo ""

echo "🔍 Data Integrity:"
# FIX 2026-02-15: Validar metadata.totalTasks sincronizado
TASKS_ACTUAL=$(jq '.tasks | length' data/kanban.json 2>/dev/null || echo 0)
TASKS_META=$(jq '.metadata.totalTasks' data/kanban.json 2>/dev/null || echo 0)
if [[ "$TASKS_ACTUAL" == "$TASKS_META" ]]; then
    echo "  ✅ Metadata synchronized (${TASKS_ACTUAL} tasks)"
    ((PASS++))
else
    echo "  ❌ Metadata out of sync! Actual: $TASKS_ACTUAL, Metadata: $TASKS_META"
    echo "     Run: ./scripts/repair-metadata.sh"
    ((FAIL++))
fi
echo ""

echo "🌐 Port Availability:"
if lsof -i :8080 &>/dev/null; then
    PID=$(lsof -ti :8080)
    echo "  ⚠️  Port 8080 in use (PID: $PID)"
    echo "     Dashboard may already be running"
    ((WARN++))
else
    echo "  ✅ Port 8080 available"
    ((PASS++))
fi
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "📊 Verification Summary"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ Passed:   $PASS"
echo "  ❌ Failed:   $FAIL"
echo "  ⚠️  Warnings: $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo "✅ System verification PASSED!"
    echo ""
    echo "Next steps:"
    echo "  1. Load test data: ./test-data.sh"
    echo "  2. Start dashboard: cd dashboard && python3 server.py"
    echo "  3. Open browser: http://localhost:8080"
    echo "  4. Read docs: INDEX.md"
    exit 0
else
    echo "❌ System verification FAILED!"
    echo ""
    echo "Fix the failed checks above, then run:"
    echo "  ./install.sh"
    exit 1
fi

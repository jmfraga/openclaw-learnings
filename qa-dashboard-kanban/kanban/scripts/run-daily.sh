#!/bin/bash
# run-daily.sh - Workflow diario completo del Kanban QA

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👁️  KANBAN QA - Daily Workflow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Paso 1: Muestreo de logs
echo "📊 Step 1: Log Sampling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/sampler.sh"
echo ""

# Paso 2: Pre-screening con Argus
echo "🔍 Step 2: Argus Pre-screening"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/argus-prescreening-v2.sh"
echo ""

# Paso 3: Update Dashboard Metrics
echo "📈 Step 3: Update Dashboard Metrics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
/home/jmfraga/.openclaw/workspace-argus/qa/update-audit-stats.sh
echo ""
/home/jmfraga/.openclaw/workspace-argus/qa/update-token-usage.sh
echo ""

# Paso 4: Auto-delegación
echo "🤖 Step 4: Auto-delegation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/delegator.sh" process
echo ""

# Paso 5: Invocar agentes delegados
echo "📞 Step 5: Agent Integration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/pm-integration.sh" process
"$SCRIPT_DIR/chappie-integration.sh" process
echo ""

# Paso 6: Reporte de tokens
echo "💰 Step 6: Token Budget Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/token-tracker.sh" status
echo ""

# Resumen final
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Daily workflow complete!"
echo ""
echo "Dashboard: http://localhost:8080"
echo "Logs: $PROJECT_DIR/data/samples/"
echo "Kanban: $PROJECT_DIR/data/kanban.json"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

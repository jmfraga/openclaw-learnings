#!/bin/bash
# test-data.sh - Crear datos de prueba para demostración

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KANBAN_FILE="$SCRIPT_DIR/data/kanban.json"

echo "🧪 Creating test data..."

# Crear algunas tasks de ejemplo
cat > "$KANBAN_FILE" <<'EOF'
{
  "tasks": [
    {
      "id": "task-001",
      "title": "Database connection timeout in PM",
      "description": "• CRITICAL: Found 'timeout' in pm logs\n• ERROR: Connection pool exhausted",
      "agent": "pm",
      "category": "infra",
      "priority": "critical",
      "status": "pending",
      "createdAt": "2026-02-13T10:30:00-06:00",
      "source": "argus-prescreening"
    },
    {
      "id": "task-002",
      "title": "Deprecated API usage in Quill",
      "description": "• WARNING: Found 'deprecated' in quill logs\n• Using old markdown parser",
      "agent": "quill",
      "category": "code",
      "priority": "medium",
      "status": "delegated",
      "delegatedTo": "chappie",
      "delegatedAt": "2026-02-13T11:00:00-06:00",
      "createdAt": "2026-02-13T10:45:00-06:00",
      "source": "argus-prescreening"
    },
    {
      "id": "task-003",
      "title": "Config validation errors in Atlas",
      "description": "• ERROR: Found 'failed to' in atlas logs\n• Invalid coordinates format",
      "agent": "atlas",
      "category": "config",
      "priority": "high",
      "status": "in-progress",
      "delegatedTo": "pm",
      "delegatedAt": "2026-02-13T12:00:00-06:00",
      "assignedAt": "2026-02-13T12:15:00-06:00",
      "createdAt": "2026-02-13T11:30:00-06:00",
      "source": "argus-prescreening"
    },
    {
      "id": "task-004",
      "title": "Memory leak in CHAPPiE subprocess",
      "description": "• CRITICAL: Memory usage exceeding limits\n• WARNING: GC not collecting properly",
      "agent": "chappie",
      "category": "bug",
      "priority": "critical",
      "status": "resolved",
      "delegatedTo": "chappie",
      "delegatedAt": "2026-02-13T09:00:00-06:00",
      "assignedAt": "2026-02-13T09:15:00-06:00",
      "resolvedAt": "2026-02-13T13:45:00-06:00",
      "resolution": "Fixed memory leak in subprocess cleanup. Added garbage collection hints.",
      "createdAt": "2026-02-13T08:30:00-06:00",
      "source": "argus-prescreening"
    },
    {
      "id": "task-005",
      "title": "Slow response time in Iris Med",
      "description": "• WARNING: Found 'slow' in iris-med logs\n• API calls taking >2s",
      "agent": "iris-med",
      "category": "performance",
      "priority": "medium",
      "status": "pending",
      "createdAt": "2026-02-13T14:00:00-06:00",
      "source": "argus-prescreening"
    }
  ],
  "lastUpdate": "2026-02-13T14:30:00-06:00",
  "metadata": {
    "createdAt": "2026-02-13T16:44:00-06:00",
    "version": "1.0.0",
    "totalTasks": 5
  }
}
EOF

echo "  ✅ Created 5 test tasks"
echo "  • 2 Pending"
echo "  • 1 Delegated"
echo "  • 1 In Progress"
echo "  • 1 Resolved"
echo ""

# Actualizar token usage
cat > "$SCRIPT_DIR/data/token-usage.json" <<EOF
{
  "weekStart": "2026-02-10",
  "weeklyUsed": 12500,
  "dailyUsage": {
    "2026-02-10": 2000,
    "2026-02-11": 3500,
    "2026-02-12": 4000,
    "2026-02-13": 3000
  },
  "history": [
    {
      "week": "2026-02-03",
      "tokens": 42000
    },
    {
      "week": "2026-01-27",
      "tokens": 38500
    }
  ],
  "metadata": {
    "weeklyLimit": 50000,
    "warningThreshold": 0.8,
    "criticalThreshold": 0.95
  }
}
EOF

echo "  ✅ Set token usage to 12,500 / 50,000 (25%)"
echo ""
echo "✅ Test data created successfully!"
echo ""
echo "Start dashboard with:"
echo "  cd dashboard && python3 server.py"

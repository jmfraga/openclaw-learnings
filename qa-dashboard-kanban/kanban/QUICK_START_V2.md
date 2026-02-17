# Quick Start — Kanban QA v2.0

## 🚀 Start Dashboard

```bash
# 1. Stop old server (if running)
pkill -f "python.*server.py"

# 2. Start v2 server
cd /home/jmfraga/.openclaw/workspace-pm/hub/qa
python3 server.py &

# 3. Access dashboard
# http://100.71.128.102:8081/
```

---

## 📊 View Metrics

```bash
cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa

# Error rate (24h)
./scripts/event-logger.sh rate 24

# Event summary
./scripts/event-logger.sh summary 24

# Validate escalations
./scripts/validate-escalations.sh
```

---

## 📝 Log Event

```bash
cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa

./scripts/event-logger.sh log \
  argus \           # agente
  cron \            # origen
  error \           # tipo
  S1 \              # severidad
  "Description" \   # descripcion
  task_created \    # accion_tomada
  task-123          # task_id (optional)
```

---

## 🔍 Files Locations

```
Dashboard: /home/jmfraga/.openclaw/workspace-pm/hub/qa/index-v2.html
Tasks:     /home/jmfraga/.openclaw/workspace-argus/kanban-qa/data/kanban.json
Events:    /home/jmfraga/.openclaw/workspace-argus/kanban-qa/data/events.jsonl
Map:       /home/jmfraga/.openclaw/workspace-pm/memory/escalation-map.md
```

---

## ✅ Quick Test

```bash
# 1. Check files exist
ls -lh workspace-argus/kanban-qa/data/events.jsonl
ls -lh workspace-pm/hub/qa/index-v2.html

# 2. Verify events
./scripts/event-logger.sh summary 24

# 3. Validate escalations
./scripts/validate-escalations.sh

# 4. Check dashboard accessible
curl -I http://localhost:8081/
```

---

## 📈 Severidad Guide

- **S0** — Low (mejoras, optimizaciones)
- **S1** — Medium (workarounds disponibles)
- **S2** — High (funcionalidad afectada)
- **S3** — Critical (sistema caído, datos comprometidos)

---

## 🎯 Target

**Error Rate**: < 5%  
**Current**: 33.33% (pequeña muestra)  
**Goal**: Estabilizar < 5% antes de bajar a Haiku

---

## 📞 Support

**Developer**: CHAPPiE  
**Escalation**: PM → Juan Ma (Telegram)  
**Docs**: CHANGELOG-v2.md, escalation-map.md

# 👁️ Kanban QA - Quick Start Guide

**5 minutos para estar corriendo** 🚀

---

## 1️⃣ Instalar (30 segundos)

```bash
cd ~/.openclaw/workspace-argus/kanban-qa
./install.sh
```

Verifica que todo esté OK. Debe mostrar ✅ en todas las dependencias.

---

## 2️⃣ Ver Dashboard (1 minuto)

```bash
cd dashboard
python3 server.py
```

Abre en tu navegador: **http://localhost:8080**

Deja corriendo en una terminal.

---

## 3️⃣ Cargar Datos de Prueba (10 segundos)

En otra terminal:

```bash
cd ~/.openclaw/workspace-argus/kanban-qa
./test-data.sh
```

Refresca el dashboard → deberías ver 5 tasks de ejemplo.

---

## 4️⃣ Ejecutar Workflow Completo (2 minutos)

```bash
cd scripts
./run-daily.sh
```

Esto ejecuta todo el ciclo:
1. Muestreo de logs
2. Pre-screening
3. Auto-delegación
4. Integración con agentes
5. Reporte de tokens

---

## 5️⃣ Scripts Individuales

### Ver presupuesto de tokens
```bash
./scripts/token-tracker.sh status
```

### Agregar tokens usados
```bash
./scripts/token-tracker.sh add 1500
```

### Muestrear logs manualmente
```bash
./scripts/sampler.sh
```

### Pre-screening manual
```bash
./scripts/argus-prescreening.sh
```

### Enviar notificación de prueba
```bash
./scripts/notifier.sh info "Test" "Esto es una prueba"
```

---

## 📊 Dashboard Features

- **Columnas:** Pending → Delegated → In Progress → Resolved
- **Stats:** Total, Pending, In Progress, Resolved
- **Token Budget:** Progress bar con % de uso
- **Filtros:** Por agente y prioridad
- **Auto-refresh:** Cada 30 segundos

---

## ⚙️ Configuración Rápida

### Ajustar sampling por agente

Edita `config/agents-config.json`:

```json
{
  "pm": {
    "samplesPerDay": 10,  // ← Cambia aquí
    "priority": "high"
  }
}
```

### Cambiar presupuesto semanal

Edita `config/agents-config.json`:

```json
{
  "tokenBudget": {
    "weeklyLimit": 50000  // ← Cambia aquí
  }
}
```

---

## 🔔 Activar Notificaciones Telegram

Verifica que exista:

```bash
cat ~/.openclaw/config.json | jq '.telegram.botToken'
```

Si no existe, agrega el token del bot.

---

## 🤖 Auto-delegación

El sistema delega automáticamente:

- **PM** → infra, config, arquitectura
- **CHAPPiE** → code, skills, tooling, bugs

Las tasks delegadas se guardan en:
- `data/pm-tasks/task-ID.txt`
- `data/chappie-tasks/task-ID.txt`

---

## 🔄 Automatizar con Cron

```bash
crontab -e
```

Agregar:
```
# Kanban QA workflow diario a las 9 AM
0 9 * * * cd ~/.openclaw/workspace-argus/kanban-qa/scripts && ./run-daily.sh >> /tmp/kanban-qa.log 2>&1
```

---

## 📁 Archivos Importantes

| Archivo | Descripción |
|---------|-------------|
| `config/agents-config.json` | Configuración de agentes y sampling |
| `data/kanban.json` | Estado del tablero Kanban |
| `data/token-usage.json` | Tracking de tokens |
| `data/samples/` | Logs muestreados por fecha |
| `README.md` | Documentación completa |

---

## 🆘 Troubleshooting

### Dashboard no inicia
```bash
# Verificar puerto
lsof -i :8080

# Si está ocupado, el server.py hace kill automático
# Intenta de nuevo
python3 dashboard/server.py
```

### No hay logs para muestrear
```bash
# Verifica que existan logs
ls -lh /home/jmfraga/.openclaw/logs/agent-*.log

# Si no, ajusta paths en config/agents-config.json
```

### Notificaciones no llegan
```bash
# Verifica token
jq '.telegram.botToken' ~/.openclaw/config.json

# Test manual
./scripts/notifier.sh info "Test" "Prueba de notificación"
```

---

## 📖 Más Info

- **Documentación completa:** `README.md`
- **Reporte de implementación:** `IMPLEMENTATION_REPORT.md`
- **Esta guía:** `QUICK_START.md`

---

**👁️ Argus te está vigilando... para bien.**

Dashboard: **http://localhost:8080**

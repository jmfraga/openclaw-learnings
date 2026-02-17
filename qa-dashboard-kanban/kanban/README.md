# 👁️ Kanban QA - Sistema de Auditoría Continua

Sistema de auditoría automática para agentes OpenClaw con tablero Kanban, auto-delegación y presupuesto de tokens.

## 🎯 Características

- ✅ **Muestreo inteligente** de logs con ajuste por agente
- ✅ **Pre-screening automático** con Argus para detectar issues
- ✅ **Tablero Kanban** visual en tiempo real (puerto 8080)
- ✅ **Auto-delegación** a PM (infra/config) y CHAPPiE (code/skills)
- ✅ **Tracking de tokens** con presupuesto semanal de 50K
- ✅ **Notificaciones Telegram** (bash puro, sin tokens)

## 📁 Estructura

```
kanban-qa/
├── config/
│   └── agents-config.json      # Configuración de agentes y sampling
├── scripts/
│   ├── sampler.sh              # Muestreo de logs
│   ├── argus-prescreening.sh   # Pre-screening de issues
│   ├── delegator.sh            # Auto-delegación
│   ├── pm-integration.sh       # Integración con PM
│   ├── chappie-integration.sh  # Integración con CHAPPiE
│   ├── token-tracker.sh        # Tracking de presupuesto
│   ├── notifier.sh             # Notificaciones Telegram
│   └── run-daily.sh            # Workflow diario completo
├── dashboard/
│   ├── index.html              # Tablero Kanban
│   └── server.sh               # Servidor web :8080
├── data/
│   ├── kanban.json             # Estado del tablero
│   ├── token-usage.json        # Uso de tokens
│   └── samples/                # Logs muestreados
└── README.md                   # Esta documentación
```

## 🚀 Quick Start

### 1. Iniciar el Dashboard

```bash
cd kanban-qa/dashboard
python3 server.py
```

O usando el script bash (requiere netcat):
```bash
./server.sh
```

Abre http://localhost:8080 en tu navegador.

### 2. Ejecutar Workflow Diario

```bash
cd kanban-qa/scripts
./run-daily.sh
```

Esto ejecuta:
1. Muestreo de logs
2. Pre-screening con Argus
3. Auto-delegación
4. Invocación de PM/CHAPPiE
5. Reporte de tokens

### 3. Ejecutar Pasos Individuales

```bash
# Solo muestreo
./scripts/sampler.sh

# Solo pre-screening
./scripts/argus-prescreening.sh

# Solo delegación
./scripts/delegator.sh process

# Verificar presupuesto
./scripts/token-tracker.sh status

# Agregar tokens usados
./scripts/token-tracker.sh add 1500
```

## ⚙️ Configuración

### Agentes y Sampling

Edita `config/agents-config.json`:

```json
{
  "agents": {
    "pm": {
      "priority": "high",
      "samplesPerDay": 10,
      "categories": ["infra", "config", "arquitectura"],
      "delegationEnabled": true
    },
    "quill": {
      "priority": "high",
      "samplesPerDay": 8,
      ...
    }
  }
}
```

**Parámetros:**
- `priority`: `high` | `medium` | `low`
- `samplesPerDay`: Número de logs a muestrear por día
- `categories`: Categorías que maneja el agente
- `delegationEnabled`: Si permite auto-delegación

### Presupuesto de Tokens

```json
{
  "tokenBudget": {
    "weeklyLimit": 50000,
    "warningThreshold": 0.8,
    "criticalThreshold": 0.95
  }
}
```

### Notificaciones Telegram

El sistema usa el bot token de OpenClaw (`~/.openclaw/config.json`).

```json
{
  "telegram": {
    "chatId": "1074136117",
    "notifyOn": ["critical", "delegated", "budget-warning"]
  }
}
```

## 🔄 Workflow Automático

### Diagrama de Flujo

```
Logs de agentes
    ↓
[Sampler] → Muestreo inteligente (ajustado por agente)
    ↓
Samples guardados en data/samples/
    ↓
[Argus Pre-screening] → Detecta patterns (ERROR, WARNING, etc.)
    ↓
Issues encontrados → Crea tasks en Kanban
    ↓
[Delegator] → Auto-asigna según categoría
    ↓
    ├─→ PM (infra, config, arquitectura)
    └─→ CHAPPiE (code, skills, tooling)
    ↓
Agentes resuelven → Actualizan Kanban
    ↓
[Dashboard] → Visualización en tiempo real
```

### Estados de Tasks

1. **Pending** 📋 - Detectada por Argus, sin asignar
2. **Delegated** 🔄 - Asignada a PM o CHAPPiE
3. **In Progress** ⚙️ - Agente trabajando en ella
4. **Resolved** ✅ - Completada y verificada

## 📊 Dashboard

El tablero Kanban muestra:

- **Stats**: Total issues, pending, in-progress, resolved
- **Token Budget**: Uso semanal con progress bar
- **Filtros**: Por agente, prioridad
- **Columnas Kanban**: Pending, Delegated, In Progress, Resolved
- **Auto-refresh**: Cada 30 segundos

## 🤖 Auto-Delegación

El sistema delega automáticamente según categorías:

**PM** recibe:
- `infra`, `config`, `arquitectura`, `deployment`, `infrastructure`

**CHAPPiE** recibe:
- `code`, `skills`, `tooling`, `bug`, `development`, `implementation`

### Cómo funciona

1. Argus crea task con categoría
2. Delegator analiza categoría/título/descripción
3. Si match con patterns → asigna a agente
4. Agente recibe prompt con contexto completo
5. Agente actualiza estado cuando resuelve

## 📈 Tracking de Tokens

Sistema de presupuesto semanal con alertas:

```bash
# Ver estado actual
./scripts/token-tracker.sh status

# Agregar uso
./scripts/token-tracker.sh add 2000

# Resetea automáticamente cada lunes
# Guarda historial en data/token-usage.json
```

**Alertas:**
- 80% uso → Warning vía Telegram
- 95% uso → Critical vía Telegram

## 🔔 Notificaciones

Usa `notifier.sh` para enviar alertas:

```bash
# Critical
./scripts/notifier.sh critical "Título" "Detalles"

# Warning
./scripts/notifier.sh warning "Título" "Detalles"

# Info
./scripts/notifier.sh info "Título" "Detalles"

# Delegación
./scripts/notifier.sh delegation "pm" "task-123" "infra"
```

## 🛠️ Desarrollo

### Agregar Nuevo Agente

1. Edita `config/agents-config.json`:

```json
{
  "nuevo-agente": {
    "name": "Nuevo Agente",
    "priority": "medium",
    "samplesPerDay": 5,
    "categories": ["category1", "category2"],
    "delegationEnabled": false,
    "logPath": "/home/jmfraga/.openclaw/logs/agent-nuevo-*.log"
  }
}
```

2. Ejecuta el sampler

### Agregar Pattern de Detección

Edita `scripts/argus-prescreening.sh`:

```bash
CRITICAL_PATTERNS=(
    "ERROR"
    "CRITICAL"
    "TU_PATTERN_AQUI"
)
```

### Personalizar Dashboard

Edita `dashboard/index.html` - HTML/CSS/JS estándar.

### Integrar con Cron

```bash
# Ejecutar workflow diario a las 9 AM
0 9 * * * cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa/scripts && ./run-daily.sh >> /tmp/kanban-qa.log 2>&1
```

## 🧪 Testing

### Probar Sampler

```bash
./scripts/sampler.sh
ls -lh data/samples/
```

### Probar Pre-screening

```bash
./scripts/argus-prescreening.sh
cat data/kanban.json | jq '.tasks'
```

### Probar Dashboard

```bash
./dashboard/server.sh &
curl http://localhost:8080/api/kanban
curl http://localhost:8080/api/tokens
```

## 🐛 Troubleshooting

### Dashboard no inicia en :8080

```bash
# Verificar si puerto está ocupado
lsof -i :8080

# Matar proceso existente
./dashboard/server.sh  # Hace kill automático
```

### Sampler no encuentra logs

Verifica paths en `config/agents-config.json`:

```bash
ls /home/jmfraga/.openclaw/logs/agent-*.log
```

### Notificaciones no llegan

Verifica token de Telegram:

```bash
jq '.telegram.botToken' ~/.openclaw/config.json
```

## 📝 Notas

- **Presupuesto:** 50K tokens/semana ≈ ~7K/día
- **Sampling:** Ajustable por agente según actividad
- **Delegación:** PM y CHAPPiE deben actualizar Kanban manualmente por ahora
- **Dashboard:** Reemplaza dashboard anterior en :8080

## 🔮 Roadmap

- [ ] Integración real con `openclaw agent invoke`
- [ ] Machine learning para mejorar detección
- [ ] Export de reportes semanales
- [ ] Integración con GitHub Issues
- [ ] Métricas de tiempo de resolución
- [ ] API REST completa

## 📄 Licencia

Parte del ecosistema OpenClaw - Uso interno

---

**Creado por:** Argus (Sistema de Auditoría)  
**Versión:** 1.0.0  
**Fecha:** 2026-02-13

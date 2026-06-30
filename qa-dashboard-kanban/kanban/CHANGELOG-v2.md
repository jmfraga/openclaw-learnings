# Kanban QA v2.0 - Changelog

**Fecha**: 2026-02-13  
**Desarrollador**: CHAPPiE  
**Solicitado por**: Juan Ma (vía PM)

## 🎯 Objetivo

Mejorar el sistema Kanban QA con severidad S0-S3, registro de eventos, error_rate, y documentación de escalación antes de bajar modelos a Haiku.

---

## ✅ Cambios Implementados

### 1. Sistema de Severidad S0-S3

**Archivo modificado**: `data/kanban.json`

**Schema actualizado**:
```json
{
  "id": "task-XXX",
  "severidad": "S0|S1|S2|S3",
  "priority": "critical|high|medium|low",
  ...
}
```

**Clasificación**:
- **S0 (Low)** — Mejoras, optimizaciones, nice-to-have
- **S1 (Medium)** — Problemas menores, workarounds disponibles
- **S2 (High)** — Degradación severa, funcionalidad afectada
- **S3 (Critical)** — Sistema caído, pérdida de servicio, datos comprometidos

**Migración de tasks existentes**:
- task-006 (Iris SOUL.md bug) → S2 (degradación severa de funcionalidad)
- task-007 (PM path mapping) → S2 (infraestructura crítica)
- task-008 (Agent-to-Agent leak) → S1 (tiene workaround)

---

### 2. Sistema de Registro de Eventos

**Archivo creado**: `data/events.jsonl`

**Formato**:
```json
{"timestamp":"2026-02-13T20:37:00-06:00","agente":"argus","origen":"cron","tipo":"error","severidad":"S1","descripcion":"...","accion_tomada":"task_created","task_id":"task-XXX"}
```

**Campos obligatorios**:
- `timestamp` — ISO 8601 con timezone
- `agente` — pm|chappie|argus|iris-assistant|phoenix|atlas|quill|iris-med
- `origen` — logs|manual|cron|heartbeat
- `tipo` — error|warning|info
- `severidad` — S0|S1|S2|S3
- `accion_tomada` — task_created|escalated|resolved|monitored
- `task_id` — (opcional) ID de task relacionada

**Eventos iniciales cargados**: 6 eventos históricos desde 2026-02-13

---

### 3. Métrica error_rate

**Implementación**: Dashboard v2 + event-logger.sh

**Cálculo**:
```
error_rate = (eventos tipo:error / eventos totales) × 100
```

**Ventana de tiempo**: 24 horas

**Target**: < 5% (verde), >= 5% (rojo)

**Tendencia**: Comparación con 24h previas (↑↓—)

**Visualización**:
- Gráfico de barras semanal (últimos 7 días)
- Color coding: normal (azul), high-error (rojo)
- Hover muestra valor exacto por día

---

### 4. Scripts de Argus Mejorados

**Archivos creados**:

#### `scripts/event-logger.sh`
Biblioteca de funciones para logging de eventos:
- `log_event` — Registrar evento en events.jsonl
- `get_error_rate` — Calcular error_rate de últimas N horas
- `get_events_summary` — Resumen de eventos por tipo/severidad

**Validaciones**:
- Campos obligatorios
- Valores válidos (enums)
- Timestamps ISO8601 con timezone

**Uso**:
```bash
./event-logger.sh log argus cron error S1 "Memory usage high" task_created task-123
./event-logger.sh rate 24
./event-logger.sh summary 24
```

#### `scripts/argus-prescreening-v2.sh`
Versión mejorada del prescreening con:
- Clasificación automática de severidad según patterns
- Logging de eventos
- Notificación para S0/S1
- Integración con event-logger

**Patterns de clasificación**:
- **S3**: FATAL, crashed, service down, database connection failed
- **S2**: ERROR, CRITICAL, Exception, failed to, timeout, out of memory
- **S1**: WARNING, WARN, retry, slow response, deprecated
- **S0**: INFO, suggestions, optimizations

**Auto-escalación**:
- S3 → Inmediata a PM (notificación crítica)
- S2 → Inmediata a PM
- S1/S0 → Daily review

---

### 5. Documentación de Coherencia

**Archivo creado**: `/home/jmfraga/.openclaw/workspace-pm/memory/escalation-map.md`

**Contenido**:
- ✅ Matriz de escalación válida (quién → quién)
- ❌ Flujos prohibidos (bucles A→B→A)
- Responsabilidades claras por agente
- Reglas de validación (No Loops, Escalación Única, PM es Hub)
- Severidad y auto-escalación
- Canales de comunicación con Juan Ma

**Agentes documentados**: 8 (PM, CHAPPiE, Iris Assistant, Iris Med, Phoenix, Argus, Atlas, Quill)

**Flujos validados**:
- ✅ Iris Assistant → Iris Med (terminal médico)
- ✅ Phoenix → CHAPPiE (terminal técnico)
- ✅ PM → CHAPPiE (desarrollo)
- ✅ Argus → PM (escalación de críticos)
- ❌ Iris Assistant → PM → Iris Assistant (bucle)
- ❌ Phoenix → CHAPPiE → Phoenix (bucle)
- ❌ PM → CHAPPiE → PM → CHAPPiE (ping-pong)

---

### 6. Dashboard QA Actualizado

**Archivo creado**: `/home/jmfraga/.openclaw/workspace-pm/hub/qa/index-v2.html`

**Nuevas features**:

#### Panel de error_rate
- Métrica destacada en header
- Gráfico de barras semanal (últimos 7 días)
- Indicador de tendencia (↑↓—)
- Color verde/rojo según target 5%

#### Filtro por severidad
- Dropdown: S0 / S1 / S2 / S3
- Combinable con otros filtros (agent, priority, status)

#### Badge de severidad
- Visible en cada task card
- Color-coded:
  - S0 → Gris (#6c757d) - Low
  - S1 → Amarillo (#ffc107) - Medium
  - S2 → Rojo (#dc3545) - High
  - S3 → Púrpura (#9c27b0) - Critical

#### Mejoras visuales
- Mobile-first responsive
- Dark gradient background
- Animaciones sutiles en hover
- Modal mejorado con metadata grid

**Servidor actualizado**: `server.py`
- Endpoint `/api/events` — Sirve events.jsonl como JSON array
- Default a index-v2.html
- CORS habilitado

---

## 📊 Métricas del Sistema

### Estado Actual (2026-02-13 20:37 CST)

**Tasks**:
- Total: 3
- Pending: 1 (task-008, S1)
- Resolved: 2 (task-006/007, S2)

**Eventos**:
- Total registrados: 6
- Errors: 2
- Warnings: 1
- Info: 3
- Error rate: 33.3% (over target, pero basado en muestra pequeña)

**Severidad distribution**:
- S0: 1 evento
- S1: 1 evento
- S2: 4 eventos
- S3: 0

---

## 🔧 Scripts y Herramientas

### Estructura de Archivos

```
workspace-argus/kanban-qa/
├── data/
│   ├── kanban.json              (actualizado con severidad)
│   └── events.jsonl             (NUEVO - registro de eventos)
├── scripts/
│   ├── event-logger.sh          (NUEVO - sistema de logging)
│   ├── argus-prescreening-v2.sh (NUEVO - con severidad)
│   └── [scripts existentes...]
└── CHANGELOG-v2.md              (este archivo)

workspace-pm/
├── hub/qa/
│   ├── index-v2.html            (NUEVO - dashboard mejorado)
│   └── server.py                (actualizado con /api/events)
└── memory/
    └── escalation-map.md        (NUEVO - matriz de escalación)
```

### Compatibilidad

**Backward compatible**: ✅
- Tasks sin severidad siguen funcionando
- Dashboard v1 sigue disponible
- Scripts v1 no afectados

**Forward compatible**: ✅
- Nuevos scripts pueden usarse junto con v1
- event-logger.sh puede usarse standalone

---

## 🧪 Testing Realizado

### ✅ Tests Completados

1. **Schema de severidad**
   - Migración de 3 tasks existentes
   - Validación de valores S0-S3
   - Metadata schema documentado

2. **Sistema de eventos**
   - 6 eventos históricos cargados
   - Formato JSONL validado
   - Timestamps ISO8601 correctos

3. **Event logger**
   - Validación de campos obligatorios
   - Cálculo de error_rate
   - Resumen de eventos por tipo/severidad

4. **Dashboard v2**
   - Renderizado de severidad badges
   - Filtro por severidad funcional
   - Gráfico de error_rate (pendiente datos reales)
   - Responsividad mobile

5. **Servidor**
   - Endpoint /api/events funcional
   - Parse de JSONL a JSON array
   - CORS habilitado

### ⚠️ Pendiente de Testing

1. **Integración con cron**
   - Argus-prescreening-v2 en cron jobs
   - Verificar auto-severidad classification

2. **Datos reales**
   - Error rate con >100 eventos
   - Tendencia semanal con datos históricos

3. **Notificaciones**
   - Escalación S0/S1 a PM vía notifier.sh

---

## 📚 Documentación

### Archivos de Documentación

1. **CHANGELOG-v2.md** (este archivo) — Cambios técnicos detallados
2. **escalation-map.md** — Matriz de escalación y responsabilidades
3. **Schema en kanban.json** — metadata.schema define estructura

### Para Juan Ma

**Interfaces visibles**:
- Dashboard: http://<tailscale-ip>:8081/
- Kanban board con badges de severidad
- Error rate panel con tendencia

**Archivos revisables**:
- `/home/jmfraga/.openclaw/workspace-argus/kanban-qa/data/kanban.json`
- `/home/jmfraga/.openclaw/workspace-argus/kanban-qa/data/events.jsonl`
- `/home/jmfraga/.openclaw/workspace-pm/memory/escalation-map.md`

---

## 🚀 Next Steps

### Recomendaciones

1. **Deployment**
   - Reiniciar servidor QA con nuevo server.py
   - Verificar dashboard v2 accesible en :8081

2. **Integración cron**
   - Reemplazar argus-prescreening.sh → argus-prescreening-v2.sh
   - Agregar event-logger calls a scripts existentes

3. **Acumulación de datos**
   - Permitir 7 días de eventos para gráfico semanal significativo
   - Validar target 5% error_rate con datos reales

4. **Monitoreo**
   - Revisar escalation-map.md periódicamente
   - Actualizar si se agregan nuevos agentes

5. **Optimización Haiku**
   - Con error_rate < 5% estable → safe to downgrade a Haiku
   - Monitorear si error_rate sube post-downgrade

---

## 📝 Notas del Desarrollador (CHAPPiE)

- Implementación completa en ~2h
- Código minimalista, sin dependencias extra
- Scripts bash con validación robusta
- Dashboard HTML/CSS/JS vanilla (no frameworks)
- Mobile-first, dark theme, animaciones sutiles
- Backward compatible con sistema existente
- Documentación exhaustiva para continuidad

**Estatus**: ✅ **COMPLETADO**

Todos los 6 entregables solicitados implementados y listos para uso.

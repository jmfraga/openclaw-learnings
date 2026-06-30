# Kanban QA Dashboard - Changelog

## [v1.1.0] - 2026-02-13

### ✨ Mejoras Implementadas

#### 1. **Tarjetas Expandibles con Detalles Completos** ✅
- ✅ Modal responsive que se abre al hacer clic en cualquier tarjeta
- ✅ Información completa mostrada:
  - Metadata: Agente, Categoría, Prioridad, Estado
  - Descripción completa del problema
  - Contexto detallado / evidencia
  - Stack trace (si disponible)
  - Link al log completo (si disponible)
  - Resolución (si fue resuelta)
  - **Timeline completo** mostrando:
    - Fecha de creación
    - Fecha de delegación (y a quién)
    - Fecha de asignación
    - Fecha de resolución
  - Fuente del issue (argus-prescreening, etc.)

#### 2. **Filtros Funcionales** ✅
Todos los filtros ahora están **completamente funcionales**:
- ✅ **Agente**: Filtra por agente específico (PM, Phoenix, Iris, Atlas, Quill, CHAPPiE, etc.)
  - Se puebla dinámicamente con los agentes que tengan tareas
- ✅ **Prioridad**: Critical, High, Medium, Low
- ✅ **Estado**: Pending, Delegated, In Progress, Resolved
- ✅ **Categoría**: Filtra por tipo de issue (infra, code, bug, performance, etc.)
  - Se puebla dinámicamente con las categorías existentes
- ✅ Los filtros se pueden combinar
- ✅ Los stats se actualizan según los filtros aplicados
- ✅ Reset con el selector "All [X]"

#### 3. **Configuración Editable en UI** ✅
- ✅ Nuevo botón **⚙️ Config** en la barra de filtros
- ✅ Modal de configuración con formulario editable:
  - **Weekly Token Limit**: Límite de tokens por semana
  - **Warning Threshold**: Umbral de advertencia (0-1)
  - **Critical Threshold**: Umbral crítico (0-1)
- ✅ Cambios se guardan en `config/agents-config.json`
- ✅ Mensaje de confirmación al guardar
- ✅ Dashboard se recarga automáticamente con nueva configuración
- ✅ Validación de formulario (números válidos, rangos correctos)

### 🔧 Mejoras Técnicas

- **Backend (server.py)**:
  - Nuevo endpoint `GET /api/config` para leer configuración
  - Nuevo endpoint `POST /api/config` para guardar configuración
  - Manejo de CORS para peticiones POST
  - Método `do_OPTIONS` para preflight requests

- **Frontend (index.html)**:
  - Sistema de filtrado completo con estado reactivo
  - Modals con animaciones suaves (fade-in, slide-down)
  - Timeline visual para historia de tareas
  - Formateo de fechas legible
  - Grid responsive para metadata
  - Cierre de modals con click fuera o botón X
  - Auto-refresh cada 30s mantiene filtros activos

### 📊 Endpoints API

```bash
GET  /api/kanban  - Lista de tareas
GET  /api/tokens  - Uso de tokens
GET  /api/config  - Configuración actual
POST /api/config  - Guardar configuración
```

### 🧪 Testing

Todos los endpoints verificados:
```bash
# Kanban data
curl http://localhost:8081/api/kanban

# Token usage
curl http://localhost:8081/api/tokens

# Config read
curl http://localhost:8081/api/config

# Config write
curl -X POST http://localhost:8081/api/config \
  -H "Content-Type: application/json" \
  -d '{"weeklyLimit": 60000, "warningThreshold": 0.8, "criticalThreshold": 0.95}'
```

### 🚀 Cómo Usar

1. **Ver detalles de una tarea**: Click en cualquier tarjeta
2. **Filtrar tareas**: Usa los selectores en la barra superior
3. **Editar configuración**: Click en botón **⚙️ Config**
4. **Refrescar manualmente**: Botón **🔄 Refresh** (o espera 30s para auto-refresh)

### 📝 Notas

- El dashboard ahora es **completamente funcional** para gestión de QA
- Todas las configuraciones se persisten en `config/agents-config.json`
- Los filtros mantienen su estado durante el auto-refresh
- Los modals son responsive y funcionan en móvil

---

**Status**: ✅ LISTO PARA PROBAR
**Dashboard**: http://<tailscale-ip>:8081

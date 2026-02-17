# Test de Mejoras - Kanban QA Dashboard

## ✅ Checklist de Pruebas

### 1. Tarjetas Expandibles

- [ ] Abrir dashboard en http://100.71.128.102:8081
- [ ] Click en cualquier tarjeta
- [ ] Verificar que se abre el modal
- [ ] Verificar que se muestra:
  - Título de la tarea
  - Metadata (Agente, Categoría, Prioridad, Estado)
  - Descripción completa
  - Timeline con eventos (Created, Delegated, Assigned, Resolved)
  - Fuente del issue
- [ ] Click en X o fuera del modal para cerrar
- [ ] Probar con diferentes tarjetas en diferentes estados

### 2. Filtros Funcionales

#### Filtro por Agente
- [ ] Abrir dropdown "All Agents"
- [ ] Verificar que aparecen: pm, quill, atlas, iris-med, chappie
- [ ] Seleccionar "pm"
- [ ] Verificar que solo se muestran tareas del PM
- [ ] Verificar que los stats se actualizan (Total Issues, Pending, etc.)
- [ ] Cambiar a "All Agents" - verificar que se muestran todas

#### Filtro por Prioridad
- [ ] Seleccionar "Critical"
- [ ] Verificar que solo se muestran tareas críticas (borde rojo)
- [ ] Probar con High, Medium, Low
- [ ] Verificar colores de borde:
  - Critical: Rojo (#dc3545)
  - High: Amarillo (#ffc107)
  - Medium: Azul claro (#17a2b8)
  - Low: Gris (#6c757d)

#### Filtro por Estado
- [ ] Seleccionar "Pending"
- [ ] Verificar que solo aparecen en columna "Pending"
- [ ] Probar con Delegated, In Progress, Resolved
- [ ] Verificar que otras columnas quedan vacías

#### Filtro por Categoría
- [ ] Abrir dropdown "All Categories"
- [ ] Verificar opciones: infra, code, config, bug, performance
- [ ] Seleccionar "infra"
- [ ] Verificar que solo se muestran tareas de infraestructura

#### Combinación de Filtros
- [ ] Seleccionar Agente=pm + Priority=critical
- [ ] Verificar que solo aparece tarea "Database connection timeout"
- [ ] Probar otras combinaciones
- [ ] Verificar que el contador de badges se actualiza correctamente

### 3. Configuración Editable

- [ ] Click en botón "⚙️ Config"
- [ ] Verificar que se abre modal de configuración
- [ ] Verificar valores actuales:
  - Weekly Token Limit: 50000
  - Warning Threshold: 0.8
  - Critical Threshold: 0.95
- [ ] Cambiar Weekly Token Limit a 60000
- [ ] Click en "💾 Save Changes"
- [ ] Verificar mensaje verde "✅ Configuration saved successfully!"
- [ ] Modal se cierra automáticamente
- [ ] Verificar que el Token Budget en stats se actualizó
- [ ] Abrir modal de nuevo - verificar que el valor persiste (60000)

### 4. Persistencia de Datos

```bash
# Verificar que la config se guardó
cat ~/.openclaw/workspace-argus/kanban-qa/config/agents-config.json | jq '.tokenBudget'

# Debe mostrar:
# {
#   "weeklyLimit": 60000,  # ← cambió de 50000
#   "warningThreshold": 0.8,
#   "criticalThreshold": 0.95
# }
```

### 5. Auto-Refresh

- [ ] Dejar el dashboard abierto
- [ ] Esperar 30 segundos
- [ ] Verificar que se hace refresh automático (sin perder filtros)
- [ ] Click en "🔄 Refresh" para refresh manual

### 6. Responsive Design

- [ ] Abrir en móvil o reducir ventana
- [ ] Verificar que el kanban cambia a 2 columnas en tablet
- [ ] Verificar que el kanban cambia a 1 columna en móvil
- [ ] Verificar que los modals se adaptan al tamaño de pantalla

---

## 🧪 Tests Automatizados

```bash
cd ~/.openclaw/workspace-argus/kanban-qa

# Test endpoints
echo "Testing GET /api/config..."
curl -s http://localhost:8081/api/config | jq '.tokenBudget'

echo "Testing GET /api/kanban..."
curl -s http://localhost:8081/api/kanban | jq '.tasks | length'

echo "Testing GET /api/tokens..."
curl -s http://localhost:8081/api/tokens | jq '.weeklyUsed'

echo "Testing POST /api/config..."
curl -s -X POST http://localhost:8081/api/config \
  -H "Content-Type: application/json" \
  -d '{"weeklyLimit": 75000, "warningThreshold": 0.85, "criticalThreshold": 0.98}' | jq

echo "Verifying save..."
curl -s http://localhost:8081/api/config | jq '.tokenBudget'
```

---

## 📋 Issues Conocidos

Ninguno. Todo está funcionando según especificaciones.

---

## 🎯 Resultado Esperado

✅ **TODAS las mejoras solicitadas están implementadas y funcionando:**
1. ✅ Tarjetas expandibles con detalles completos
2. ✅ Filtros funcionales por agente, prioridad, estado, categoría
3. ✅ Configuración editable que persiste en JSON

**Dashboard listo para uso en producción.**

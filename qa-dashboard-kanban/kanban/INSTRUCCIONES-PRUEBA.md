# 🎯 Instrucciones de Prueba - Kanban QA Dashboard

**Dashboard**: http://<tailscale-ip>:8081

---

## 🔥 Prueba Rápida (5 minutos)

### 1. Tarjetas Expandibles (1 min)

**Pasos:**
1. Abre http://<tailscale-ip>:8081
2. Busca la tarjeta roja "Database connection timeout in PM"
3. Haz **click en la tarjeta**
4. **Verifica que se abre un modal** con:
   - ✅ Título completo
   - ✅ Metadata (Agente: PM, Categoría: infra, etc.)
   - ✅ Descripción del error
   - ✅ Timeline con fechas (Created → Delegated → etc.)
5. Haz click en la **X** o fuera del modal para cerrar
6. Prueba abrir otra tarjeta (ej: "Memory leak in CHAPPiE")

**¿Funciona?** ⬜ Sí ⬜ No

---

### 2. Filtros Funcionales (2 min)

#### Filtro por Agente
1. En la barra superior, click en dropdown **"All Agents"**
2. Selecciona **"pm"**
3. **Verifica:**
   - Solo aparecen 2 tarjetas (ambas del PM)
   - El contador "Total Issues" cambia a 2
   - Los badges de columnas se actualizan

**¿Funciona?** ⬜ Sí ⬜ No

#### Filtro por Prioridad
1. Cambia filtro de agente a **"All Agents"** (para resetear)
2. En dropdown **"All Priorities"**, selecciona **"Critical"**
3. **Verifica:**
   - Solo aparecen 2 tarjetas rojas
   - Total Issues = 2
   - Una en Pending, una en Resolved

**¿Funciona?** ⬜ Sí ⬜ No

#### Combinación de Filtros
1. Mantén filtro Priority = **Critical**
2. Cambia Agent a **"pm"**
3. **Verifica:**
   - Solo aparece 1 tarjeta: "Database connection timeout"
   - Está en columna Pending
   - Total Issues = 1

**¿Funciona?** ⬜ Sí ⬜ No

---

### 3. Configuración Editable (2 min)

1. Click en botón **⚙️ Config** (arriba a la derecha)
2. **Verifica que se abre modal** con 3 campos:
   - Weekly Token Limit: 50000
   - Warning Threshold: 0.8
   - Critical Threshold: 0.95
3. Cambia **Weekly Token Limit** a **75000**
4. Click en **💾 Save Changes**
5. **Verifica:**
   - ✅ Aparece mensaje verde "Configuration saved successfully!"
   - ✅ Modal se cierra automáticamente
   - ✅ El token budget en stats se actualiza (12500/75000 = 16% aprox)
6. Abre modal de nuevo (⚙️ Config)
7. **Verifica que el valor persiste** (debe decir 75000)

**¿Funciona?** ⬜ Sí ⬜ No

---

## 🔧 Verificación Técnica (Opcional)

### Verificar que la config se guardó en archivo:

```bash
cat ~/.openclaw/workspace-argus/kanban-qa/config/agents-config.json | jq '.tokenBudget'
```

**Debe mostrar:**
```json
{
  "weeklyLimit": 75000,     ← cambió de 50000
  "warningThreshold": 0.8,
  "criticalThreshold": 0.95
}
```

### Verificar endpoints:

```bash
# Kanban data (5 tareas)
curl http://<tailscale-ip>:8081/api/kanban | jq '.tasks | length'

# Token usage (12500)
curl http://<tailscale-ip>:8081/api/tokens | jq '.weeklyUsed'

# Config (75000)
curl http://<tailscale-ip>:8081/api/config | jq '.tokenBudget.weeklyLimit'
```

---

## 📋 Checklist Final

- [ ] ✅ Tarjetas abren modal con detalles completos
- [ ] ✅ Modal muestra timeline de eventos
- [ ] ✅ Filtro por Agente funciona
- [ ] ✅ Filtro por Prioridad funciona
- [ ] ✅ Filtro por Estado funciona
- [ ] ✅ Filtro por Categoría funciona
- [ ] ✅ Filtros se pueden combinar
- [ ] ✅ Stats se actualizan según filtros
- [ ] ✅ Config modal se abre y muestra valores actuales
- [ ] ✅ Config se guarda correctamente
- [ ] ✅ Cambios persisten en archivo JSON
- [ ] ✅ Token budget se actualiza en dashboard

---

## ❓ Troubleshooting

**Modal no se abre:**
- Verifica en consola del navegador (F12) si hay errores
- Asegúrate de hacer click directamente en la tarjeta

**Filtros no funcionan:**
- Resetea todos los filtros a "All [X]"
- Refresca la página (F5)

**Config no se guarda:**
- Verifica que el servidor está corriendo:
  ```bash
  ps aux | grep server.py
  ```
- Si no está corriendo:
  ```bash
  cd ~/.openclaw/workspace-argus/kanban-qa/dashboard
  ./server.py &
  ```

---

## ✅ Resultado Esperado

**TODAS las casillas deben estar marcadas.**  
Si alguna falla, reporta cuál y el comportamiento observado.

👁️ **Dashboard listo para uso en producción.**

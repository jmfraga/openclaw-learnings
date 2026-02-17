# 🚀 Quick Reference - Quill Fix

Comandos rápidos para validar y deployar el fix de Quill.

---

## ✅ Validación Rápida (< 2 min)

### 1. Verificar que MCP funciona
```bash
mcporter list google-workspace
```

**Esperado**: Lista de ~46 tools, incluyendo drive y docs tools.

---

### 2. Test del workflow completo
```bash
cd ~/.openclaw/workspace-chappie
bash quill-workflow-simple.sh
```

**Esperado**:
```
✅ Template copied successfully
✅ Content inserted successfully
✅ PDF exported successfully
```

**Si falla en "copy_drive_file not available"**:
```bash
# Intenta llamarlo directamente
mcporter call google-workspace.copy_drive_file \
  file_id=10alUOjkfMwiwpm12igyTbmBWR2sdIs5LkZpNzXAbREk \
  new_name="TEST-Manual" \
  parent_folder_id=1nv9DYWHEBn2E87dKOTt4IOR_Ecp_Tzs9
```

---

## 🔄 Deploy del Fix (< 5 min)

### 1. Backup del SOUL.md actual
```bash
cp /home/jmfraga/.openclaw/agents/quill/agent/SOUL.md \
   /home/jmfraga/.openclaw/agents/quill/agent/SOUL.md.backup-$(date +%Y%m%d)
```

### 2. Copiar nuevo SOUL.md
```bash
cp ~/.openclaw/workspace-chappie/quill-SOUL-rewrite.md \
   /home/jmfraga/.openclaw/agents/quill/agent/SOUL.md
```

### 3. Reiniciar Quill (si está corriendo)
```bash
# Matar sesiones activas de Quill
pkill -f "agent.*quill" || true

# Nueva sesión se levantará automáticamente con nuevo SOUL.md
```

### 4. Test con Quill real
```bash
# Abrir chat con Quill y pedirle:
"Genera una carta de recomendación de prueba para SimAcademy.
Alumno: Dr. Test Usuario
Diplomado: Simulación Clínica 2025-2026"
```

**Validar que**:
- [ ] Lee SOUL.md al inicio
- [ ] Lee memory/drive-structure.md para IDs
- [ ] Usa `mcporter call google-workspace.copy_drive_file`
- [ ] NO intenta ejecutar scripts Python
- [ ] Completa workflow en < 1 minuto
- [ ] Reporta link de documento y PDF

---

## 🐛 Troubleshooting

### Error: "copy_drive_file not found"

**Opción A**: Usar workaround (más lento)
```bash
# Ver quill-testing-plan.md sección "Workaround Plan"
```

**Opción B**: Fix MCP server
```bash
# Investigar por qué copy_drive_file no está registrado
cd /home/jmfraga/migration-staging/repos/google_workspace_mcp

# Ver si hay @server.tool() en la función
grep -A5 "@server.tool()" gdrive/drive_tools.py | grep -A5 "copy_drive_file"

# Ver logs del MCP server
tail -50 mcp_server_debug.log
```

---

### Error: "Content appears AFTER signature"

**Fix**: Ajustar `index` en `docs_insert_text`

```bash
# Obtener estructura del documento
mcporter call google-workspace.docs_get_content_as_markdown \
  document_id=DOC_ID

# Contar caracteres hasta donde va el contenido
# Ajustar index en SOUL.md (línea del docs_insert_text)
```

---

### Error: "PDF download 403 Forbidden"

**Fix**: Hacer documento público temporalmente

```bash
mcporter call google-workspace.share_drive_file \
  file_id=DOC_ID \
  role=reader \
  type=anyone
```

---

## 📊 Validación Post-Deploy

### 1. Check logs de Quill
```bash
tail -50 ~/.openclaw/agents/quill/sessions/*.jsonl | grep -i error
```

**Esperado**: No errores recientes.

---

### 2. Verificar archivos generados en Drive
```bash
# Buscar documentos generados hoy
mcporter call google-workspace.drive_search_files \
  query="modifiedTime > '$(date +%Y-%m-%d)'" \
  page_size=20 \
  shared_drive_id=0AO2nrmeDoW7FUk9PVA
```

**Esperado**: Lista de documentos recientes en Documentos Generados.

---

### 3. Performance check
```bash
# Medir tiempo del workflow
time bash ~/.openclaw/workspace-chappie/quill-workflow-simple.sh
```

**Target**: < 15 segundos total.

---

## 🔧 Comandos Útiles

### Listar archivos en Documentos Generados (SimAcademy)
```bash
mcporter call google-workspace.drive_search_files \
  query="'1nv9DYWHEBn2E87dKOTt4IOR_Ecp_Tzs9' in parents" \
  page_size=10
```

---

### Leer contenido de un documento
```bash
mcporter call google-workspace.docs_get_content_as_markdown \
  document_id=DOC_ID
```

---

### Eliminar documento de prueba
```bash
mcporter call google-workspace.drive_delete_file \
  file_id=DOC_ID
```

---

### Ver estructura de carpetas
```bash
cat /home/jmfraga/.openclaw/agents/quill/agent/memory/drive-structure.md
```

---

## 📝 Rollback (si algo sale mal)

### 1. Restaurar SOUL.md anterior
```bash
cp /home/jmfraga/.openclaw/agents/quill/agent/SOUL.md.backup-* \
   /home/jmfraga/.openclaw/agents/quill/agent/SOUL.md
```

### 2. Reiniciar Quill
```bash
pkill -f "agent.*quill" || true
```

---

## 📚 Documentos Generados por este Fix

Todos en: `/home/jmfraga/.openclaw/workspace-chappie/`

1. **SUMMARY-quill-fix.md** ← Lee esto primero
2. **quill-fix-analysis.md** → Root cause detallado
3. **quill-SOUL-rewrite.md** → Nuevo SOUL.md para Quill
4. **quill-testing-plan.md** → Test suite completo
5. **quill-workflow-simple.sh** → Script ejecutable de prueba
6. **QUICK-REFERENCE.md** → Este archivo

---

## ⏱️ Timeline

| Acción | Tiempo |
|--------|--------|
| Validar MCP | 1 min |
| Test workflow | 1 min |
| Backup SOUL.md | 30 seg |
| Deploy nuevo SOUL.md | 30 seg |
| Test con Quill | 2 min |
| **TOTAL** | **~5 min** |

---

## ✉️ Contacto

Si algo falla o tienes dudas:
- **CHAPPiE** (desarrollo/debug)
- **PM** (coordinación)
- **Docs**: Ver archivos generados en workspace-chappie

---

**¡Buena suerte! 🚀**

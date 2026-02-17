# ✅ Kanban QA - Deployment Checklist

**Úsala para poner el sistema en producción paso a paso.**

---

## Pre-Deployment

### ☐ Verificar Entorno

```bash
# 1. Verificar que estás en el workspace de Argus
pwd
# Debe mostrar: /home/jmfraga/.openclaw/workspace-argus

# 2. Verificar dependencias
cd kanban-qa
./install.sh
# Todo debe mostrar ✅
```

### ☐ Configurar Telegram

```bash
# Verificar token del bot
cat ~/.openclaw/config.json | jq '.telegram.botToken'

# Debe mostrar un token válido, no null
# Si es null, agregar token:
jq '.telegram.botToken = "YOUR_BOT_TOKEN"' ~/.openclaw/config.json > /tmp/config.json
mv /tmp/config.json ~/.openclaw/config.json
```

### ☐ Ajustar Configuración de Agentes

```bash
# Editar configuración
nano config/agents-config.json

# Verificar:
# 1. Paths de logs correctos para cada agente
# 2. samplesPerDay ajustado según actividad real
# 3. Chat ID de Telegram correcto

# Validar JSON
jq empty config/agents-config.json && echo "✅ JSON válido"
```

### ☐ Verificar Logs Existentes

```bash
# Listar logs disponibles
ls -lh /home/jmfraga/.openclaw/logs/agent-*.log

# Si no hay logs, ejecuta algunos agentes primero
# O ajusta los paths en config/agents-config.json
```

---

## Testing en Desarrollo

### ☐ Test 1: Dashboard con Datos de Prueba

```bash
# Cargar datos de prueba
./test-data.sh

# Iniciar dashboard
cd dashboard
python3 server.py &

# Abrir en navegador
# http://localhost:8080

# Verificar:
# ✓ 5 tasks visibles
# ✓ Stats correctas
# ✓ Token usage al 25%
# ✓ Filtros funcionan
```

### ☐ Test 2: Sampler

```bash
cd scripts

# Ejecutar sampler
./sampler.sh

# Verificar archivos generados
ls -lh ../data/samples/

# Debe haber archivos: YYYY-MM-DD_AGENT_sample.log
```

### ☐ Test 3: Pre-screening

```bash
# Ejecutar pre-screening
./argus-prescreening.sh

# Verificar Kanban
cat ../data/kanban.json | jq '.tasks | length'

# Debe mostrar número de tasks
```

### ☐ Test 4: Token Tracker

```bash
# Ver estado
./token-tracker.sh status

# Agregar tokens de prueba
./token-tracker.sh add 1000

# Verificar actualización
./token-tracker.sh status
```

### ☐ Test 5: Notificaciones (si tienes token)

```bash
# Enviar test
./notifier.sh info "Test Deployment" "Sistema Kanban QA funcionando"

# Verificar que llega a Telegram
```

### ☐ Test 6: Workflow Completo

```bash
# Ejecutar workflow completo
./run-daily.sh

# Verificar output sin errores
# Verificar dashboard actualizado
```

---

## Deployment a Producción

### ☐ Configurar Cron Job

```bash
# Editar crontab
crontab -e

# Agregar línea (ajustar hora según preferencia):
0 9 * * * cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa/scripts && ./run-daily.sh >> /tmp/kanban-qa.log 2>&1

# Verificar crontab
crontab -l | grep kanban
```

### ☐ Dashboard como Servicio Persistente

**Opción A: Screen (Simple)**
```bash
screen -dmS kanban-dashboard bash -c 'cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa/dashboard && python3 server.py'

# Verificar
screen -ls | grep kanban

# Reconnectar si necesitas
screen -r kanban-dashboard
```

**Opción B: Systemd (Robusto)**
```bash
# Crear servicio
sudo nano /etc/systemd/system/kanban-qa-dashboard.service
```

Contenido:
```ini
[Unit]
Description=Kanban QA Dashboard
After=network.target

[Service]
Type=simple
User=jmfraga
WorkingDirectory=/home/jmfraga/.openclaw/workspace-argus/kanban-qa/dashboard
ExecStart=/usr/bin/python3 server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Activar servicio
sudo systemctl daemon-reload
sudo systemctl enable kanban-qa-dashboard
sudo systemctl start kanban-qa-dashboard

# Verificar estado
sudo systemctl status kanban-qa-dashboard
```

### ☐ Configurar Logging Permanente

```bash
# Crear directorio de logs
mkdir -p ~/logs/kanban-qa

# Actualizar cron con logging
crontab -e

# Cambiar a:
0 9 * * * cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa/scripts && ./run-daily.sh >> ~/logs/kanban-qa/$(date +\%Y-\%m-\%d).log 2>&1
```

### ☐ Configurar Rotación de Logs

```bash
# Crear script de limpieza
nano scripts/cleanup-old-logs.sh
```

Contenido:
```bash
#!/bin/bash
# Limpiar samples de más de 30 días
find /home/jmfraga/.openclaw/workspace-argus/kanban-qa/data/samples -name "*.log" -mtime +30 -delete
find /home/jmfraga/.openclaw/workspace-argus/kanban-qa/data/samples -name "*.meta" -mtime +30 -delete
echo "✅ Old samples cleaned"
```

```bash
chmod +x scripts/cleanup-old-logs.sh

# Agregar a cron (semanal)
crontab -e

# Agregar:
0 2 * * 0 /home/jmfraga/.openclaw/workspace-argus/kanban-qa/scripts/cleanup-old-logs.sh
```

---

## Post-Deployment

### ☐ Monitoreo Inicial (Primera Semana)

**Día 1-3:**
- [ ] Verificar dashboard 2-3 veces al día
- [ ] Revisar logs de cron: `cat /tmp/kanban-qa.log`
- [ ] Verificar que lleguen notificaciones
- [ ] Revisar tasks creadas (¿falsos positivos?)

**Día 4-7:**
- [ ] Ajustar sampling si es necesario
- [ ] Revisar presupuesto de tokens
- [ ] Ajustar patterns de detección
- [ ] Verificar auto-delegación funciona bien

### ☐ Tunning de Configuración

```bash
# Si hay muchos falsos positivos:
# 1. Ajustar patterns en argus-prescreening.sh
# 2. Reducir sampling en agentes menos críticos

# Si hay muy pocas detecciones:
# 1. Aumentar sampling en agentes importantes
# 2. Agregar más patterns de búsqueda

# Si se agota el presupuesto:
# 1. Revisar qué agente consume más
# 2. Reducir sampling en ese agente
# 3. O aumentar presupuesto semanal
```

### ☐ Backup de Configuración

```bash
# Crear backup
tar -czf ~/kanban-qa-backup-$(date +%Y%m%d).tar.gz \
  kanban-qa/config/ \
  kanban-qa/data/kanban.json \
  kanban-qa/data/token-usage.json

# Verificar
ls -lh ~/kanban-qa-backup-*.tar.gz
```

---

## Verificación de Salud

### ☐ Checklist Semanal

```bash
# 1. Dashboard está corriendo
curl -s http://localhost:8080 > /dev/null && echo "✅ Dashboard UP" || echo "❌ Dashboard DOWN"

# 2. Presupuesto de tokens
cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa/scripts
./token-tracker.sh status

# 3. Tasks resueltas esta semana
cat ../data/kanban.json | jq '[.tasks[] | select(.status == "resolved")] | length'

# 4. Logs de cron recientes
ls -lh /tmp/kanban-qa.log
tail -50 /tmp/kanban-qa.log

# 5. Samples generados
ls -lh ../data/samples/ | head -20
```

---

## Troubleshooting

### ☐ Dashboard no responde

```bash
# Verificar proceso
ps aux | grep "python3 server.py"

# Si no hay proceso, reiniciar
cd /home/jmfraga/.openclaw/workspace-argus/kanban-qa/dashboard
python3 server.py &

# O con systemd
sudo systemctl restart kanban-qa-dashboard
```

### ☐ Cron no ejecuta

```bash
# Verificar cron está corriendo
sudo systemctl status cron

# Verificar permisos
ls -l /home/jmfraga/.openclaw/workspace-argus/kanban-qa/scripts/run-daily.sh

# Verificar logs
tail -100 /var/log/syslog | grep CRON
```

### ☐ No se detectan issues

```bash
# Verificar que hay logs para muestrear
ls -lh /home/jmfraga/.openclaw/logs/agent-*.log

# Ejecutar sampler manualmente y ver output
cd scripts
./sampler.sh

# Verificar samples generados
ls -lh ../data/samples/
```

### ☐ Notificaciones no llegan

```bash
# Test manual
./scripts/notifier.sh info "Test" "Manual test"

# Verificar token
cat ~/.openclaw/config.json | jq '.telegram.botToken'

# Verificar chat ID
cat config/agents-config.json | jq '.telegram.chatId'
```

---

## Rollback Plan

### ☐ Si algo falla

```bash
# 1. Detener cron
crontab -e
# Comentar línea del Kanban QA

# 2. Detener dashboard
pkill -f "python3 server.py"
# O con systemd:
sudo systemctl stop kanban-qa-dashboard

# 3. Restaurar backup
cd ~
tar -xzf kanban-qa-backup-YYYYMMDD.tar.gz

# 4. Revisar logs y documentación
cat /tmp/kanban-qa.log
cat kanban-qa/README.md
```

---

## Sign-off

### ☐ Deployment Completo

- [ ] Tests pasados ✅
- [ ] Dashboard corriendo 24/7
- [ ] Cron job configurado
- [ ] Notificaciones funcionando
- [ ] Logs rotando
- [ ] Backup creado
- [ ] Documentación leída

**Fecha de deployment:** _______________

**Deployed by:** _______________

**Notas:** 

_________________________________________________

_________________________________________________

_________________________________________________

---

**🎉 Sistema en producción!**

**Monitorea:** http://localhost:8080  
**Logs:** `/tmp/kanban-qa.log`  
**Config:** `kanban-qa/config/agents-config.json`

**👁️ Argus watching... always.**

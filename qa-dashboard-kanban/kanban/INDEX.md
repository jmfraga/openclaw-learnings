# 📚 Kanban QA - Documentation Index

**Guía de navegación de toda la documentación del sistema.**

---

## 🚀 Para Empezar

**Si es tu primera vez aquí, empieza con:**

1. **[RESUMEN_EJECUTIVO.md](RESUMEN_EJECUTIVO.md)** ← Lee esto primero (5 min)
   - Qué es el sistema
   - Qué hace
   - Por qué existe

2. **[QUICK_START.md](QUICK_START.md)** ← Luego pruébalo (5 min)
   - Instalación rápida
   - Ver dashboard
   - Comandos básicos

3. **[README.md](README.md)** ← Cuando quieras profundizar (20 min)
   - Documentación completa
   - Configuración detallada
   - Casos de uso

---

## 📖 Documentación por Rol

### Para PM (Juan Ma)

**Lectura recomendada:**
1. [RESUMEN_EJECUTIVO.md](RESUMEN_EJECUTIVO.md) - Qué se implementó
2. [QUICK_START.md](QUICK_START.md) - Cómo usarlo
3. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Poner en producción

**Referencias:**
- [README.md](README.md) - Cuando necesites algo específico
- [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) - Detalles técnicos

### Para Desarrolladores (CHAPPiE)

**Lectura recomendada:**
1. [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) - Arquitectura técnica
2. [README.md](README.md) - API y extensión
3. Código fuente en `/scripts/` y `/dashboard/`

**Referencias:**
- `config/agents-config.json` - Schema de configuración
- `scripts/*.sh` - Implementación bash

### Para Usuarios Finales

**Lectura recomendada:**
1. [QUICK_START.md](QUICK_START.md) - Uso básico
2. README.md secciones: Quick Start, Dashboard, Troubleshooting

---

## 📂 Archivos por Categoría

### Documentación General

| Archivo | Propósito | Tiempo de lectura |
|---------|-----------|-------------------|
| [INDEX.md](INDEX.md) | Este archivo, índice de docs | 2 min |
| [README.md](README.md) | Documentación completa del sistema | 20 min |
| [RESUMEN_EJECUTIVO.md](RESUMEN_EJECUTIVO.md) | Overview para PM | 5 min |

### Guías de Uso

| Archivo | Propósito | Tiempo |
|---------|-----------|--------|
| [QUICK_START.md](QUICK_START.md) | Empezar en 5 minutos | 5 min |
| [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) | Poner en producción paso a paso | 15 min |

### Documentación Técnica

| Archivo | Propósito | Audiencia |
|---------|-----------|-----------|
| [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) | Reporte de implementación | Técnica |

### Scripts Ejecutables

| Archivo | Función | Uso |
|---------|---------|-----|
| [install.sh](install.sh) | Instalación y verificación | `./install.sh` |
| [test-data.sh](test-data.sh) | Generar datos de prueba | `./test-data.sh` |

---

## 🗂️ Estructura del Proyecto

```
kanban-qa/
├── 📚 DOCUMENTACIÓN
│   ├── INDEX.md                    ← Estás aquí
│   ├── README.md                   ← Docs completas
│   ├── RESUMEN_EJECUTIVO.md        ← Para PM
│   ├── QUICK_START.md              ← Inicio rápido
│   ├── IMPLEMENTATION_REPORT.md    ← Detalles técnicos
│   └── DEPLOYMENT_CHECKLIST.md     ← Deploy paso a paso
│
├── ⚙️ CONFIGURACIÓN
│   └── config/
│       └── agents-config.json      ← Config principal (editable)
│
├── 🛠️ SCRIPTS
│   └── scripts/
│       ├── sampler.sh              ← Muestreo de logs
│       ├── argus-prescreening.sh   ← Detección de issues
│       ├── delegator.sh            ← Auto-delegación
│       ├── pm-integration.sh       ← Integración PM
│       ├── chappie-integration.sh  ← Integración CHAPPiE
│       ├── token-tracker.sh        ← Presupuesto tokens
│       ├── notifier.sh             ← Notificaciones
│       └── run-daily.sh            ← Workflow completo
│
├── 🎨 DASHBOARD
│   └── dashboard/
│       ├── index.html              ← UI del tablero
│       ├── server.py               ← Servidor (Python)
│       └── server.sh               ← Servidor (bash)
│
├── 💾 DATOS
│   └── data/
│       ├── kanban.json             ← Estado del Kanban
│       ├── token-usage.json        ← Tracking de tokens
│       ├── samples/                ← Logs muestreados
│       ├── pm-tasks/               ← Tasks para PM
│       └── chappie-tasks/          ← Tasks para CHAPPiE
│
└── 🔧 UTILIDADES
    ├── install.sh                  ← Instalación
    └── test-data.sh                ← Datos de prueba
```

---

## 🎯 Flujos de Lectura Recomendados

### Flujo 1: "Quiero empezar YA"

1. [QUICK_START.md](QUICK_START.md) - 5 min
2. Ejecutar `./install.sh`
3. Ejecutar `./test-data.sh`
4. Abrir dashboard en http://localhost:8080
5. ✅ Listo!

### Flujo 2: "Quiero entender el sistema"

1. [RESUMEN_EJECUTIVO.md](RESUMEN_EJECUTIVO.md) - 5 min
2. [README.md](README.md) - 20 min
3. [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) - 15 min
4. Explorar código en `/scripts/`

### Flujo 3: "Quiero deployar a producción"

1. [QUICK_START.md](QUICK_START.md) - Familiarizarse
2. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Seguir paso a paso
3. [README.md](README.md) - Sección "Troubleshooting"
4. Ejecutar tests
5. Deploy

### Flujo 4: "Algo no funciona"

1. [README.md](README.md) - Sección "Troubleshooting"
2. [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Sección "Troubleshooting"
3. Revisar logs: `/tmp/kanban-qa.log`
4. Verificar configuración: `config/agents-config.json`

---

## 🔍 Búsqueda Rápida

### ¿Cómo hago...?

| Tarea | Documento | Sección |
|-------|-----------|---------|
| Instalar el sistema | [QUICK_START.md](QUICK_START.md) | 1️⃣ Instalar |
| Ver el dashboard | [QUICK_START.md](QUICK_START.md) | 2️⃣ Ver Dashboard |
| Configurar sampling | [README.md](README.md) | Configuración → Agentes y Sampling |
| Cambiar presupuesto | [README.md](README.md) | Configuración → Presupuesto de Tokens |
| Activar notificaciones | [README.md](README.md) | Configuración → Notificaciones Telegram |
| Agregar nuevo agente | [README.md](README.md) | Desarrollo → Agregar Nuevo Agente |
| Deployar a producción | [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) | Deployment a Producción |
| Resolver problemas | [README.md](README.md) | Troubleshooting |

### ¿Dónde está...?

| Info | Ubicación |
|------|-----------|
| Arquitectura del sistema | [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) → Estructura Final |
| Lista de entregables | [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) → Entregables Completados |
| Workflow completo | [README.md](README.md) → Workflow Automático |
| Comandos CLI | [QUICK_START.md](QUICK_START.md) → Scripts Individuales |
| Configuración JSON | `config/agents-config.json` |
| Estado del Kanban | `data/kanban.json` |

---

## 📊 Estadísticas de Documentación

- **Total de docs:** 6 archivos
- **Páginas totales:** ~40 páginas
- **Tiempo de lectura completo:** ~1.5 horas
- **Quick start:** 5 minutos
- **Cobertura:** 100% del sistema

---

## 🆘 Ayuda

### Si tienes dudas sobre...

- **Instalación:** [QUICK_START.md](QUICK_START.md)
- **Configuración:** [README.md](README.md) → Configuración
- **Uso diario:** [README.md](README.md) → Quick Start
- **Deployment:** [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)
- **Problemas:** [README.md](README.md) → Troubleshooting
- **Arquitectura:** [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md)

### Si necesitas...

- **Empezar rápido:** [QUICK_START.md](QUICK_START.md)
- **Entender el sistema:** [RESUMEN_EJECUTIVO.md](RESUMEN_EJECUTIVO.md)
- **Referencia completa:** [README.md](README.md)
- **Poner en producción:** [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)

---

## 📝 Actualizaciones

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0.0 | 2026-02-13 | Release inicial |

---

## 📞 Soporte

- **Dashboard:** http://localhost:8080
- **Logs:** `/tmp/kanban-qa.log`
- **Config:** `kanban-qa/config/agents-config.json`
- **Issues:** Crear task en el Kanban 😉

---

**👁️ Happy monitoring!**

**Argus - Sistema de Auditoría Continua**

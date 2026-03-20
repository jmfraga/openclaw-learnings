# Iris Contact System

## Propósito

El sistema de contactos de Iris es una solución de gestión de contactos para agentes OpenClaw que integra información personal, profesional y contextual sobre individuos, colaboradores, pacientes y organizaciones. Diseñado originalmente para Iris Assistant, permite a los agentes acceder, actualizar y mantener un registro estructurado de contactos con metadatos relevantes para la comunicación contextualizada.

## Características

- **Almacenamiento JSONL**: Base de datos de contactos en formato JSONL (JSON Lines) para compatibilidad con herramientas de procesamiento de datos
- **Roles y niveles de acceso**: Clasificación flexible de contactos por rol (familia, amigo, colaborador, paciente, etc.) y nivel de acceso (A, B, C)
- **Contexto preferido**: Define el contexto óptimo para cada contacto (personal, organizacional, médico, profesional)
- **Metadata enriquecida**: Fecha de nacimiento, último contacto, notas internas, apodos, organización asociada
- **Herramienta de gestión**: Script `contact-update` para agregar, editar, consultar y listar contactos sin manipular JSON manualmente

## Estructura de Archivos

```
iris-contact-system/
├── README.md                    # Este archivo (documentación)
├── contacts.jsonl               # Base de datos de contactos (JSONL)
└── contact-update               # Script bash para gestión de contactos
```

### contacts.jsonl

Base de datos en formato JSONL donde cada línea es un objeto JSON que representa un contacto. Almacenado en:
- **Workspace de Iris**: `/home/jmfraga/.openclaw/workspace-iris-assistant/contacts.jsonl`

**Ubicación compartida** (para integración con otros agentes):
- `/home/jmfraga/.openclaw/workspace/shared_with_phoenix/docs/contacts.jsonl`

### contact-update

Script bash que proporciona interfaz segura para gestionar contactos sin necesidad de editar JSON directamente.

**Ubicación**: `/home/jmfraga/.openclaw/workspace-iris-assistant/scripts/contact-update`

## Esquema de Contacto

```json
{
  "numero": "+5214422581157",
  "nombre": "Dr. Juan Manuel Fraga Sastrias",
  "apodo": null,
  "roles": ["familia"],
  "rol_primario": "familia",
  "organizacion": null,
  "nivel_acceso": "A",
  "contexto_preferido": "personal",
  "fecha_nacimiento": "1976-04-25",
  "ultimo_contacto": "2026-02-05",
  "notas": "Mi humano"
}
```

### Campos

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `numero` | string | ✅ | Número telefónico (formato E.164, ej. +5214422581157) |
| `nombre` | string | ✅ | Nombre completo del contacto |
| `apodo` | string\|null | ❌ | Apodo o sobrenombre |
| `roles` | array[string] | ✅ | Lista de roles (familia, amigo, colaborador, paciente, coordinadora, etc.) |
| `rol_primario` | string | ✅ | Rol principal del contacto |
| `organizacion` | string\|null | ❌ | Organización asociada (SimAcademy, Cancer Center Tec 100, etc.) |
| `nivel_acceso` | string | ✅ | Nivel de privacidad/acceso (A=alto, B=medio, C=bajo/cliente) |
| `contexto_preferido` | string | ✅ | Contexto óptimo para contacto (personal, organizacional, médico, profesional) |
| `fecha_nacimiento` | date\|null | ❌ | Fecha de nacimiento en formato YYYY-MM-DD |
| `ultimo_contacto` | date | ✅ | Última fecha de contacto en formato YYYY-MM-DD |
| `notas` | string | ✅ | Anotaciones internas (información médica, contexto, recordatorios) |

## Ejemplos de Contactos

### Familia
```json
{"numero":"+5214422742162","nombre":"María Isabel Segura Esquivel","apodo":"Maribel","roles":["familia"],"rol_primario":"familia","organizacion":null,"nivel_acceso":"A","contexto_preferido":"personal","fecha_nacimiento":"1976-02-23","ultimo_contacto":"2026-02-07","notas":"Novia de JuanMa"}
```

### Colaborador Profesional
```json
{"numero":"+5215531273760","nombre":"Hugo Olvera","roles":["colaborador","amigo"],"rol_primario":"colaborador","organizacion":"simacademy","nivel_acceso":"C","contexto_preferido":"organizacional","fecha_nacimiento":null,"ultimo_contacto":"2026-02-06","notas":"Profesor SimAcademy"}
```

### Paciente con Contexto Médico
```json
{"numero":"+5214423246714","nombre":"Cristóbal Escárcega Rincón","roles":["paciente"],"rol_primario":"paciente","nivel_acceso":"C","contexto_preferido":"medico","fecha_nacimiento":"1952-07-16","ultimo_contacto":"2026-02-10","notas":"⚠️ ALÉRGICO A SULFAS (Trimetoprim-sulfametoxazol). Diagnóstico: Hipertensión arterial, dolor neuropático (neuralgia). Receta: Gabapentina 300mg 2x/día + Losartan 50/Hidroclorotiazida 12.5 1x/día."}
```

### Otro Agente
```json
{"numero":"+5214426406066","nombre":"Iris","roles":["colaborador"],"rol_primario":"colaborador","organizacion":null,"nivel_acceso":"A","contexto_preferido":"organizacional","fecha_nacimiento":"2026-02-04","ultimo_contacto":"2026-02-06","notas":"Asistente de IA - Raspberry Pi 5"}
```

## Instrucciones de Uso

### 1. Listar Todos los Contactos

```bash
./contact-update list
```

Output:
```
Asistente Dra Segura (+5214465219551)
Asistente Hermano - Gateway: http://100.107.30.22:18789 (+5214426586883)
Dr. Juan Manuel Fraga Sastrias (+5214422581157)
...
```

### 2. Obtener Detalles de un Contacto

```bash
./contact-update get "+5214422581157"
```

Output:
```json
{
  "numero": "+5214422581157",
  "nombre": "Dr. Juan Manuel Fraga Sastrias",
  "roles": ["familia"],
  "rol_primario": "familia",
  ...
}
```

### 3. Agregar un Nuevo Contacto

```bash
./contact-update add "+5215551234567" "María García" "1990-05-15" "María"
```

Esto crea un contacto con:
- `rol_primario`: "cliente_potencial"
- `nivel_acceso`: "C"
- `contexto_preferido`: "medico"

### 4. Editar un Campo de Contacto

```bash
# Campo texto simple
./contact-update edit "+5214422581157" "notas" "Actualizado: médico principal"

# Cambiar rol primario
./contact-update edit "+5215551234567" "rol_primario" "colaborador"

# Actualizar roles (array JSON)
./contact-update edit "+5215551234567" "roles" '["amiga","colaboradora"]'

# Cambiar fecha de último contacto
./contact-update edit "+5215551234567" "ultimo_contacto" "2026-03-20"
```

## Integración para Otros Agentes

### Opción 1: Lectura Directa del Archivo

```bash
# Buscar contacto por número
grep "\"numero\":\"+5214422581157\"" /home/jmfraga/.openclaw/workspace-iris-assistant/contacts.jsonl | jq .

# Listar todos los contactos de un rol específico
jq 'select(.roles[] | contains("familia"))' /home/jmfraga/.openclaw/workspace-iris-assistant/contacts.jsonl
```

### Opción 2: Usar el Script contact-update

Copia el script `contact-update` a tu workspace y úsalo con la ruta absoluta del archivo `contacts.jsonl`:

```bash
# En tu agente, editar contact-update para apuntar a la ruta correcta
sed -i 's|CONTACTS_FILE=.*|CONTACTS_FILE="/ruta/a/contacts.jsonl"|' contact-update

# Luego usar normalmente
./contact-update list
```

### Opción 3: Implementar en tu Agente

Analiza el script `contact-update` para inspirarte en cómo implementar gestión de contactos en tu propio agente. La lógica principal:

1. **Validar JSON**: Usar `jq empty` para verificar sintaxis
2. **Backup automático**: Guardar versiones anteriores antes de cambios
3. **Transacciones**: Usar archivos temporales para evitar corrupción
4. **Metadata temporal**: Actualizar `ultimo_contacto` automáticamente

## Compatibilidad

- **Formato**: JSONL (compatible con jq, Python, Node.js)
- **Requisitos**: `jq` (para validación de JSON)
- **Bash**: Compatible con bash 4.0+
- **Plataforma**: Desarrollado en Linux (Raspberry Pi ARM64)

## Notas de Seguridad

- El archivo `contacts.jsonl` contiene información personal sensible, médica e identificable
- Nivel de acceso "A" = información privada, "C" = información de cliente
- Las notas pueden incluir diagnósticos médicos, alergias, identificadores personales
- Mantener backups regulares (el script `contact-update` lo hace automáticamente)
- No compartir el archivo completo sin revisar sensibilidad de datos

## Autor y Historia

- **Creado por**: Phoenix (colaborador de OpenClaw)
- **Adaptado/Mejorado por**: Iris Assistant
- **Fecha**: Febrero 2026
- **Versión del script**: 2.0 (manejo mejorado de JSON)

## Referencias

- [JSONL Format](https://jsonlines.org/)
- [jq Manual](https://stedolan.github.io/jq/)
- OpenClaw Architecture Documentation

---

**Última actualización**: 2026-03-20

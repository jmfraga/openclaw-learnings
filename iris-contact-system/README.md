# Iris Contact System

## Propósito

El sistema de contactos de Iris es una solución de gestión de contactos para agentes OpenClaw que integra información personal, profesional y contextual sobre individuos, colaboradores y organizaciones. Diseñado originalmente para Iris Assistant, permite a los agentes acceder, actualizar y mantener un registro estructurado de contactos con metadatos relevantes para la comunicación contextualizada.

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
├── contacts.jsonl               # Base de datos de contactos (JSONL) — NO incluido en repo
└── contact-update               # Script bash para gestión de contactos
```

> ⚠️ El archivo `contacts.jsonl` contiene información personal y NO debe subirse al repositorio. Está incluido en `.gitignore`.

## Esquema de Contacto

```json
{
  "numero": "+521XXXXXXXXXX",
  "nombre": "Nombre Completo del Contacto",
  "apodo": null,
  "roles": ["colaborador"],
  "rol_primario": "colaborador",
  "organizacion": "nombre-organizacion",
  "nivel_acceso": "B",
  "contexto_preferido": "profesional",
  "fecha_nacimiento": "1980-01-15",
  "ultimo_contacto": "2026-01-01",
  "notas": "Notas internas sobre el contacto"
}
```

### Campos

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `numero` | string | ✅ | Número telefónico (formato E.164, ej. +521XXXXXXXXXX) |
| `nombre` | string | ✅ | Nombre completo del contacto |
| `apodo` | string\|null | ❌ | Apodo o sobrenombre |
| `roles` | array[string] | ✅ | Lista de roles (familia, amigo, colaborador, paciente, coordinadora, etc.) |
| `rol_primario` | string | ✅ | Rol principal del contacto |
| `organizacion` | string\|null | ❌ | Organización asociada |
| `nivel_acceso` | string | ✅ | Nivel de privacidad/acceso (A=alto, B=medio, C=bajo/cliente) |
| `contexto_preferido` | string | ✅ | Contexto óptimo para contacto (personal, organizacional, médico, profesional) |
| `fecha_nacimiento` | date\|null | ❌ | Fecha de nacimiento en formato YYYY-MM-DD |
| `ultimo_contacto` | date | ✅ | Última fecha de contacto en formato YYYY-MM-DD |
| `notas` | string | ✅ | Anotaciones internas (información médica, contexto, recordatorios) |

## Ejemplos de Contactos

### Familiar / Contacto Personal
```json
{"numero":"+521XXXXXXXXXX","nombre":"Nombre Apellido","apodo":"Apodo","roles":["familia"],"rol_primario":"familia","organizacion":null,"nivel_acceso":"A","contexto_preferido":"personal","fecha_nacimiento":"1980-06-15","ultimo_contacto":"2026-01-01","notas":"Familiar cercano"}
```

### Colaborador Profesional
```json
{"numero":"+521XXXXXXXXXX","nombre":"Dr. Ejemplo García","roles":["colaborador"],"rol_primario":"colaborador","organizacion":"nombre-empresa","nivel_acceso":"C","contexto_preferido":"organizacional","fecha_nacimiento":null,"ultimo_contacto":"2026-01-01","notas":"Descripción del rol"}
```

### Paciente con Contexto Médico
```json
{"numero":"+521XXXXXXXXXX","nombre":"Paciente Ejemplo","roles":["paciente"],"rol_primario":"paciente","nivel_acceso":"C","contexto_preferido":"medico","fecha_nacimiento":"1960-01-01","ultimo_contacto":"2026-01-01","notas":"⚠️ Alergias y condiciones relevantes. Diagnóstico: [condición]. Medicamentos: [lista]."}
```

### Agente IA
```json
{"numero":"+521XXXXXXXXXX","nombre":"NombreAgente","roles":["colaborador"],"rol_primario":"colaborador","organizacion":null,"nivel_acceso":"A","contexto_preferido":"organizacional","fecha_nacimiento":"2026-01-01","ultimo_contacto":"2026-01-01","notas":"Agente de IA - descripción"}
```

## Instrucciones de Uso

### 1. Listar Todos los Contactos

```bash
./contact-update list
```

### 2. Obtener Detalles de un Contacto

```bash
./contact-update get "+521XXXXXXXXXX"
```

### 3. Agregar un Nuevo Contacto

```bash
./contact-update add "+521XXXXXXXXXX" "Nombre Apellido" "1990-05-15" "Apodo"
```

### 4. Editar un Campo de Contacto

```bash
# Campo texto simple
./contact-update edit "+521XXXXXXXXXX" "notas" "Notas actualizadas"

# Cambiar rol primario
./contact-update edit "+521XXXXXXXXXX" "rol_primario" "colaborador"

# Actualizar roles (array JSON)
./contact-update edit "+521XXXXXXXXXX" "roles" '["amigo","colaborador"]'

# Cambiar fecha de último contacto
./contact-update edit "+521XXXXXXXXXX" "ultimo_contacto" "2026-03-20"
```

## Integración para Otros Agentes

### Opción 1: Lectura Directa del Archivo

```bash
# Buscar contacto por número
grep "\"numero\":\"+521XXXXXXXXXX\"" /ruta/a/contacts.jsonl | jq .

# Listar todos los contactos de un rol específico
jq 'select(.roles[] | contains("familia"))' /ruta/a/contacts.jsonl
```

### Opción 2: Usar el Script contact-update

```bash
# Editar contact-update para apuntar a tu ruta de contacts.jsonl
sed -i 's|CONTACTS_FILE=.*|CONTACTS_FILE="/ruta/a/contacts.jsonl"|' contact-update

# Luego usar normalmente
./contact-update list
```

## Compatibilidad

- **Formato**: JSONL (compatible con jq, Python, Node.js)
- **Requisitos**: `jq` (para validación de JSON)
- **Bash**: Compatible con bash 4.0+
- **Plataforma**: Desarrollado en Linux (ARM64)

## Notas de Seguridad

- El archivo `contacts.jsonl` contiene información personal sensible — **nunca subir al repositorio**
- Nivel de acceso "A" = información privada, "C" = información de cliente
- Las notas pueden incluir diagnósticos médicos, alergias, identificadores personales
- Mantener backups regulares (el script `contact-update` lo hace automáticamente)
- Agregar `contacts.jsonl` al `.gitignore` del proyecto

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

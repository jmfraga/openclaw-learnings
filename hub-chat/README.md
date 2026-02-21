# Hub Chat — OpenClaw

Chat web interface para hablar directamente con agentes OpenClaw desde el Hub.
Sirve como canal de emergencia cuando WhatsApp/Telegram no están disponibles.

## Características

- **Sesiones persistentes por agente** — Cada agente mantiene su propio historial de conversaciones
- **Nueva conversación** — Botón para iniciar sesiones frescas cuando se necesite
- **Historial de conversaciones** — Accede a chats anteriores desde la sidebar
- **Dark mode** — Interfaz oscura optimizada para bajo consumo y legibilidad
- **Sin dependencias externas** — Vanilla JS + Node.js. Funciona en cualquier Hub OpenClaw

## Instalación

### 1. Copiar archivos

```bash
# En tu Hub (o servidor donde corre OpenClaw):
mkdir -p /path/to/hub/chat/lib

# Copiar archivos
cp chat.html /path/to/hub/
cp lib/chat-handler.js /path/to/hub/lib/
```

### 2. Registrar rutas en tu servidor Hub

Si usas el Hub default de OpenClaw (Node.js), agrega al archivo `index.js` (o similar):

```javascript
const chatHandlers = require('./lib/chat-handler');

app.get('/api/chat/agents', (req, res) => {
    chatHandlers.handleGetAgents(req, res);
});

app.get('/api/chat/:agentId/sessions', (req, res) => {
    const agentId = req.params.agentId;
    chatHandlers.handleGetSessions(req, res, agentId);
});

app.post('/api/chat/:agentId/send', (req, res) => {
    const agentId = req.params.agentId;
    chatHandlers.handleSendMessage(req, res, agentId);
});

app.post('/api/chat/:agentId/new', (req, res) => {
    const agentId = req.params.agentId;
    chatHandlers.handleNewSession(req, res, agentId);
});
```

### 3. Configuración de agentes

Abre `lib/chat-handler.js` y personaliza el array `AGENTS`:

```javascript
const AGENTS = [
    { id: 'YOUR_AGENT_ID', name: 'Tu Agente', emoji: '🤖' },
    // Agrega más agentes aquí
];
```

### 4. Acceder al chat

Abre en tu navegador:
```
http://YOUR_HUB_IP:8080/chat.html
```

## Uso

1. **Selecciona un agente** desde la sidebar izquierda
2. **Elige una sesión anterior** o comienza una nueva
3. **Escribe tu mensaje** y presiona `Enter` o haz clic en "Enviar"
4. El agente responde automáticamente en la conversación

### Atajos de teclado

- **Enter** → Enviar mensaje
- **Shift + Enter** → Nueva línea en el mensaje

## Estructura de datos

Las sesiones se guardan en `data/chat-sessions.json`:

```json
{
  "agent-id": {
    "activeSesionKey": "agent:agent-id:web:timestamp:random",
    "sessions": [
      {
        "key": "agent:agent-id:web:timestamp:random",
        "title": "Chat — 2026-02-20 13:30:00",
        "createdAt": "2026-02-20T13:30:00Z",
        "messages": []
      }
    ]
  }
}
```

## Configuración avanzada

### Personalizar colores

En `chat.html`, modifica las variables CSS al inicio del `<style>`:

```css
:root {
    --bg-primary: #0a0e27;        /* Fondo principal */
    --bg-secondary: #10141e;      /* Fondo secundario */
    --accent: #10a37f;             /* Color de acento (verde) */
    --error: #ef4444;              /* Color de error */
}
```

### Timeout de mensajes

En `lib/chat-handler.js`, línea con `timeout: 30000`, ajusta el valor en milisegundos:

```javascript
const { stdout, stderr } = await execPromise(cmd, { timeout: 60000 }); // 60 segundos
```

## Troubleshooting

### "No se pudieron cargar los agentes"

- Verifica que el servidor está corriendo
- Confirma que `/api/chat/agents` responde correctamente
- Revisa la consola del navegador (F12 → Console)

### Mensajes no enviados

- Asegúrate de que los agentes están configurados en `AGENTS` array
- Verifica que `openclaw agent` funciona desde CLI:
  ```bash
  openclaw agent --agent "pm" --message "hola" --json
  ```

### Sesiones no se guardan

- Comprueba permisos de escritura en `data/` directory
- Revisa logs del servidor Node.js

## API Reference

### `GET /api/chat/agents`

Retorna lista de agentes disponibles.

**Response:**
```json
{
  "agents": [
    { "id": "pm", "name": "PM", "emoji": "🎯" }
  ]
}
```

### `GET /api/chat/:agentId/sessions`

Obtiene sesiones de un agente.

**Response:**
```json
{
  "activeSesionKey": "...",
  "sessions": [...]
}
```

### `POST /api/chat/:agentId/send`

Envía mensaje a un agente.

**Body:**
```json
{
  "message": "tu mensaje aquí",
  "sessionKey": "opcional"
}
```

**Response:**
```json
{
  "sessionKey": "...",
  "userMessage": "tu mensaje",
  "agentResponse": "respuesta del agente",
  "success": true
}
```

### `POST /api/chat/:agentId/new`

Crea nueva sesión.

**Response:**
```json
{
  "sessionKey": "...",
  "session": {...}
}
```

## Licencia

MIT — Úsalo libremente en tu Hub OpenClaw

---

**¿Preguntas?** Abre un issue en el repo.

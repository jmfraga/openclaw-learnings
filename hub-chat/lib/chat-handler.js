const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const execPromise = promisify(exec);

const DATA_DIR = path.join(__dirname, '..', 'data');
const SESSIONS_FILE = path.join(DATA_DIR, 'chat-sessions.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Defined agents with emojis
const AGENTS = [
    { id: 'pm', name: 'PM', emoji: '🎯' },
    { id: 'chappie', name: 'CHAPPiE', emoji: '🤖' },
    { id: 'iris-assistant', name: 'Iris', emoji: '🌿' },
    { id: 'iris-med', name: 'Iris Med', emoji: '🏥' },
    { id: 'atlas', name: 'Atlas', emoji: '📅' },
    { id: 'quill', name: 'Quill', emoji: '🪶' },
    { id: 'phoenix', name: 'Phoenix', emoji: '🔥' },
    { id: 'argus', name: 'Argus', emoji: '👁️' },
    { id: 'echo', name: 'Echo', emoji: '🔮' },
];

// Load sessions from disk
function loadSessions() {
    try {
        if (fs.existsSync(SESSIONS_FILE)) {
            return JSON.parse(fs.readFileSync(SESSIONS_FILE, 'utf8'));
        }
    } catch (error) {
        console.error('[CHAT] Error loading sessions:', error);
    }
    
    // Initialize empty sessions structure
    const sessions = {};
    AGENTS.forEach(agent => {
        sessions[agent.id] = {
            activeSesionKey: null,
            sessions: []
        };
    });
    return sessions;
}

// Save sessions to disk
function saveSessions(sessions) {
    try {
        fs.writeFileSync(SESSIONS_FILE, JSON.stringify(sessions, null, 2));
    } catch (error) {
        console.error('[CHAT] Error saving sessions:', error);
    }
}

// Generate unique session key
function generateSessionKey(agentId) {
    return `agent:${agentId}:web:${Date.now()}:${Math.random().toString(36).substr(2, 9)}`;
}

// Extract text from agent response
function extractResponseText(output) {
    try {
        // Parse the JSON output from openclaw agent --json
        const obj = JSON.parse(output);
        
        // Navigate the response structure
        if (obj.result && obj.result.payloads && Array.isArray(obj.result.payloads)) {
            const firstPayload = obj.result.payloads[0];
            if (firstPayload && firstPayload.text) {
                return firstPayload.text.trim();
            }
        }
        
        // Fallback: try other common structures
        if (obj.data && obj.data.message && obj.data.message.content) {
            const content = obj.data.message.content;
            if (Array.isArray(content)) {
                const textBlock = content.find(c => c.type === 'text');
                if (textBlock) return textBlock.text;
            } else if (typeof content === 'string') {
                return content;
            }
        }
        
        if (obj.output) return obj.output;
        if (obj.response) return obj.response;
        if (obj.text) return obj.text;
    } catch (parseError) {
        // Not valid JSON, continue
    }
    
    // Fallback: return raw output, cleaned up
    let result = output.trim();
    // Remove OpenClaw log prefix if present
    result = result.replace(/^🦞.*?\n/s, '');
    return result;
}

// Send message to agent via CLI
async function sendMessageToAgent(agentId, message, sessionKey) {
    try {
        const sessionArg = sessionKey ? `--session-id "${sessionKey}"` : '';
        
        // Robust escaping for shell injection and special characters
        const escapedMsg = message
            .replace(/\\/g, '\\\\')  // Backslash
            .replace(/"/g, '\\"')     // Double quote
            .replace(/`/g, '\\`')     // Backtick
            .replace(/\$/g, '\\$')    // Dollar sign
            .replace(/!/g, '\\!');    // Exclamation mark
        
        const cmd = `openclaw agent --agent "${agentId}" ${sessionArg} --message "${escapedMsg}" --json 2>&1`;
        
        console.log(`[CHAT] Executing command for agent: ${agentId}, session: ${sessionKey || 'new'}`);
        const { stdout, stderr } = await execPromise(cmd, { timeout: 30000 });
        
        const responseText = extractResponseText(stdout || stderr);
        return {
            success: true,
            text: responseText,
            raw: stdout,
            error: null
        };
    } catch (error) {
        console.error(`[CHAT] Error sending message to ${agentId}:`, error);
        return {
            success: false,
            text: `Error: ${error.message}`,
            raw: error.message,
            error: error.message
        };
    }
}

// API Handlers
async function handleGetAgents(req, res) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ agents: AGENTS }, null, 2));
}

async function handleGetSessions(req, res, agentId) {
    try {
        const sessions = loadSessions();
        
        if (!sessions[agentId]) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Agent not found' }));
            return;
        }
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(sessions[agentId], null, 2));
    } catch (error) {
        console.error('[CHAT] Error getting sessions:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
    }
}

async function handleSendMessage(req, res, agentId) {
    try {
        // Parse JSON body
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        
        req.on('end', async () => {
            try {
                const payload = JSON.parse(body);
                const { message, sessionKey, title } = payload;
                
                if (!message || !message.trim()) {
                    res.writeHead(400, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: 'Message is required' }));
                    return;
                }
                
                // Load or create session
                const sessions = loadSessions();
                let actualSessionKey = sessionKey;
                
                if (!actualSessionKey) {
                    // Create new session
                    actualSessionKey = generateSessionKey(agentId);
                    const newSession = {
                        key: actualSessionKey,
                        title: title || `Chat — ${new Date().toLocaleString('es-MX')}`,
                        createdAt: new Date().toISOString(),
                        messages: []
                    };
                    
                    sessions[agentId].sessions.unshift(newSession);
                    sessions[agentId].activeSesionKey = actualSessionKey;
                } else {
                    // Update existing session's last activity
                    const session = sessions[agentId].sessions.find(s => s.key === sessionKey);
                    if (session) {
                        session.updatedAt = new Date().toISOString();
                    }
                    sessions[agentId].activeSesionKey = sessionKey;
                }
                
                saveSessions(sessions);
                
                // Send message to agent
                const response = await sendMessageToAgent(agentId, message, actualSessionKey);
                
                // Save messages to session
                const session = sessions[agentId].sessions.find(s => s.key === actualSessionKey);
                if (session) {
                    if (!session.messages) session.messages = [];
                    
                    // Add user message
                    session.messages.push({
                        role: 'user',
                        text: message,
                        ts: Date.now()
                    });
                    
                    // Add agent response
                    session.messages.push({
                        role: 'agent',
                        text: response.text,
                        ts: Date.now()
                    });
                    
                    // Keep only last 100 messages
                    if (session.messages.length > 100) {
                        session.messages = session.messages.slice(-100);
                    }
                    
                    saveSessions(sessions);
                }
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    sessionKey: actualSessionKey,
                    userMessage: message,
                    agentResponse: response.text,
                    success: response.success,
                    timestamp: new Date().toISOString()
                }, null, 2));
                
            } catch (parseError) {
                console.error('[CHAT] Error parsing request body:', parseError);
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Invalid JSON in request body' }));
            }
        });
        
    } catch (error) {
        console.error('[CHAT] Error sending message:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
    }
}

async function handleNewSession(req, res, agentId) {
    try {
        const sessions = loadSessions();
        
        if (!sessions[agentId]) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Agent not found' }));
            return;
        }
        
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        
        req.on('end', async () => {
            try {
                const payload = body ? JSON.parse(body) : {};
                const { title } = payload;
                
                const newSessionKey = generateSessionKey(agentId);
                const newSession = {
                    key: newSessionKey,
                    title: title || `Chat — ${new Date().toLocaleString('es-MX')}`,
                    createdAt: new Date().toISOString(),
                    messages: []
                };
                
                sessions[agentId].sessions.unshift(newSession);
                sessions[agentId].activeSesionKey = newSessionKey;
                
                saveSessions(sessions);
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    sessionKey: newSessionKey,
                    session: newSession
                }, null, 2));
                
            } catch (parseError) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Invalid request body' }));
            }
        });
        
    } catch (error) {
        console.error('[CHAT] Error creating new session:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
    }
}

async function handleGetSessionMessages(req, res, agentId, sessionKey) {
    try {
        const sessions = loadSessions();
        
        if (!sessions[agentId]) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Agent not found' }));
            return;
        }
        
        const session = sessions[agentId].sessions.find(s => s.key === sessionKey);
        
        if (!session) {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Session not found' }));
            return;
        }
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            messages: session.messages || []
        }, null, 2));
        
    } catch (error) {
        console.error('[CHAT] Error getting session messages:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
    }
}

module.exports = {
    handleGetAgents,
    handleGetSessions,
    handleSendMessage,
    handleNewSession,
    handleGetSessionMessages,
    AGENTS
};

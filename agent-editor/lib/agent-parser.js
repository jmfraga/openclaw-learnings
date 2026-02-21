const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const readdir = promisify(fs.readdir);
const stat = promisify(fs.stat);
const readFile = promisify(fs.readFile);

// Configuration: Set OPENCLAW_DIR to your OpenClaw root directory
// Default: ~/.openclaw (use process.env.OPENCLAW_DIR to override)
const OPENCLAW_DIR = process.env.OPENCLAW_DIR || path.join(process.env.HOME, '.openclaw');
const AGENTS_BASE = path.join(OPENCLAW_DIR, 'agents');
const CONFIG_PATH = path.join(OPENCLAW_DIR, 'openclaw.json');

const cache = {
    data: null,
    timestamp: 0,
    ttl: 30000 // 30 seconds
};

// Read agent list from openclaw.json
function getAgentList() {
    try {
        const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
        return (config.agents?.list || []).map(a => {
            // Extract model string (handle both "string" and {"primary": "string"} formats)
            let modelStr = null;
            if (typeof a.model === 'string') {
                modelStr = a.model;
            } else if (a.model?.primary) {
                modelStr = a.model.primary;
            } else {
                modelStr = config.agents?.defaults?.model?.primary || null;
            }
            
            // Strip provider prefix if present (anthropic/claude-x → claude-x)
            if (modelStr && modelStr.includes('/')) {
                modelStr = modelStr.split('/')[1];
            }
            
            return {
                id: a.id,
                model: modelStr
            };
        });
    } catch (e) {
        return [];
    }
}

async function getLatestSessionFile(agentName) {
    const sessionsDir = path.join(AGENTS_BASE, agentName, 'sessions');
    
    try {
        const files = await readdir(sessionsDir);
        // Include both active .jsonl and recently deleted ones
        const jsonlFiles = files.filter(f => f.endsWith('.jsonl'));
        const deletedFiles = files.filter(f => f.includes('.jsonl.deleted.'));
        
        const allFiles = [...jsonlFiles, ...deletedFiles];
        if (allFiles.length === 0) return null;
        
        // Get file stats and sort by mtime
        const fileStats = await Promise.all(
            allFiles.map(async (file) => {
                const filePath = path.join(sessionsDir, file);
                try {
                    const stats = await stat(filePath);
                    return { file, path: filePath, mtime: stats.mtime, deleted: file.includes('.deleted.') };
                } catch (e) {
                    return null;
                }
            })
        );
        
        const valid = fileStats.filter(f => f !== null);
        valid.sort((a, b) => b.mtime - a.mtime);
        return valid[0] || null;
    } catch (error) {
        return null;
    }
}

async function parseAgentSession(agentName, configModel) {
    const latestFile = await getLatestSessionFile(agentName);
    
    if (!latestFile) {
        return {
            name: agentName,
            status: 'offline',
            lastActivity: null,
            model: configModel,
            usage: null
        };
    }

    try {
        const content = await readFile(latestFile.path, 'utf-8');
        const lines = content.trim().split('\n');
        
        let lastMessage = null;
        let lastModel = null;
        
        // Parse from end to find the most recent message
        for (let i = lines.length - 1; i >= 0; i--) {
            try {
                const line = JSON.parse(lines[i]);
                if (line.type === 'message') {
                    if (!lastMessage) lastMessage = line;
                    if (line.message?.model) {
                        lastModel = line.message.model;
                        break;
                    }
                }
            } catch (e) {
                continue;
            }
        }
        
        if (!lastMessage) {
            return {
                name: agentName,
                status: 'offline',
                lastActivity: latestFile.mtime.getTime(),
                model: configModel,
                usage: null
            };
        }

        const timestampRaw = lastMessage.timestamp || lastMessage.message?.timestamp;
        // Handle both ISO strings and epoch milliseconds
        let timestamp = null;
        if (timestampRaw) {
            const parsed = typeof timestampRaw === 'number' ? timestampRaw : new Date(timestampRaw).getTime();
            if (!isNaN(parsed) && parsed > 86400000) timestamp = parsed;
        }
        
        // Fallback to file mtime
        if (!timestamp) timestamp = latestFile.mtime.getTime();
        
        const now = Date.now();
        const ageMinutes = (now - timestamp) / 60000;
        
        let status = 'offline';
        if (ageMinutes < 5) status = 'active';
        else if (ageMinutes < 60) status = 'idle';
        
        return {
            name: agentName,
            status,
            lastActivity: timestamp,
            model: configModel, // Always use config model (source of truth)
            usage: lastMessage.message?.usage || null,
            sessionFile: path.basename(latestFile.path),
            fileModified: latestFile.mtime.getTime()
        };
    } catch (error) {
        console.error(`Error parsing session for ${agentName}:`, error);
        return {
            name: agentName,
            status: 'error',
            lastActivity: null,
            model: configModel,
            usage: null,
            error: error.message
        };
    }
}

async function getAgentsInfo() {
    const now = Date.now();
    
    if (cache.data && (now - cache.timestamp) < cache.ttl) {
        return cache.data;
    }

    try {
        const agentConfigs = getAgentList();
        const agents = await Promise.all(
            agentConfigs.map(a => parseAgentSession(a.id, a.model))
        );
        
        cache.data = agents;
        cache.timestamp = now;
        
        return agents;
    } catch (error) {
        console.error('Error fetching agents info:', error);
        return [];
    }
}

async function getAllSessionMessages() {
    const agentConfigs = getAgentList();
    const allMessages = [];
    
    for (const agentConfig of agentConfigs) {
        const sessionsDir = path.join(AGENTS_BASE, agentConfig.id, 'sessions');
        
        try {
            const files = await readdir(sessionsDir);
            const jsonlFiles = files.filter(f => f.endsWith('.jsonl'));
            
            for (const file of jsonlFiles) {
                const filePath = path.join(sessionsDir, file);
                try {
                    const content = await readFile(filePath, 'utf-8');
                    const lines = content.trim().split('\n');
                    
                    for (const line of lines) {
                        try {
                            const data = JSON.parse(line);
                            if (data.type === 'message') {
                                const timestampRaw = data.timestamp || data.message?.timestamp;
                                const timestamp = timestampRaw ? new Date(timestampRaw).getTime() : null;
                                
                                allMessages.push({
                                    agent: agentConfig.id,
                                    timestamp: timestamp,
                                    type: data.type,
                                    model: data.message?.model,
                                    usage: data.message?.usage,
                                    data: data
                                });
                            }
                        } catch (e) {}
                    }
                } catch (e) {}
            }
        } catch (error) {
            continue;
        }
    }
    
    return allMessages;
}

module.exports = {
    getAgentsInfo,
    getAllSessionMessages
};

const fs = require('fs').promises;
const path = require('path');
const { execSync } = require('child_process');

// Configuration
// Set these environment variables or edit directly:
// OPENCLAW_SESSIONS_DIR - path to openclaw agents sessions directory
// Default: /path/to/openclaw/agents
const SESSIONS_DIR = process.env.OPENCLAW_SESSIONS_DIR || '/YOUR_OPENCLAW_PATH/agents';
const DATA_DIR = path.join(__dirname, '../data');
const REQUESTS_FILE = path.join(DATA_DIR, 'api-cost-requests.json');
const METRICS_FILE = path.join(DATA_DIR, 'api-cost-metrics.json');

// Pricing per 1M tokens (2026-02-21 rates)
// Source: https://www.anthropic.com/pricing/claude
const PRICING = {
    'claude-opus-4-6': { input: 15.0, output: 45.0 },
    'claude-sonnet-4-6': { input: 3.0, output: 15.0 },
    'claude-haiku-4-5': { input: 0.80, output: 4.0 }
};

/**
 * Heuristic classification rules for requests
 * Determines if a request is suitable for local execution (M4 Pro/Sonnet)
 * vs Claude API
 */
function classifyRequest(message) {
    if (!message || !message.message) {
        return { classification: 'UNKNOWN', reasoning: 'Missing message data' };
    }

    const messageBody = message.message;
    if (!messageBody.usage) {
        return { classification: 'UNKNOWN', reasoning: 'Missing usage data' };
    }

    const usage = messageBody.usage;
    const inputTokens = usage.input || 0;
    const toolsCount = message.data?.tools_used ? (Array.isArray(message.data.tools_used) ? message.data.tools_used.length : 0) : 0;
    
    // Extract prompt preview
    let promptText = '';
    if (messageBody.content) {
        const content = messageBody.content;
        if (Array.isArray(content)) {
            const textBlock = content.find(b => b.type === 'text');
            promptText = (textBlock?.text || '').toLowerCase();
        } else if (typeof content === 'string') {
            promptText = content.toLowerCase();
        }
    }

    // Keywords for classification
    const localViableKeywords = [
        'transcribe', 'audio', 'foto', 'extract', 'triage',
        'categorize', 'clasificar', 'resumen', 'parse',
        'diagnóstico simple', 'simple summary', 'format', 'convert'
    ];

    const needsClaudeKeywords = [
        'debug', 'architecture', 'design', 'refactor', 'code-review',
        'reasoning', 'agentic', 'loop', 'complex', 'orchestration'
    ];

    const hasLocalKeywords = localViableKeywords.some(kw => promptText.includes(kw));
    const hasComplexKeywords = needsClaudeKeywords.some(kw => promptText.includes(kw));
    const hasThinking = (usage.thinking || 0) > 0;

    // Classification logic
    if (toolsCount >= 3 || hasComplexKeywords || hasThinking) {
        return {
            classification: 'NEEDS_CLAUDE',
            reasoning: `tools=${toolsCount}, complex=${hasComplexKeywords}, thinking=${hasThinking}`
        };
    }

    if (inputTokens < 4000 && toolsCount === 0 && hasLocalKeywords) {
        return {
            classification: 'LOCAL_VIABLE',
            reasoning: `input=${inputTokens}<4k, no tools, local keywords present`
        };
    }

    if (inputTokens <= 8000 && toolsCount <= 2) {
        return {
            classification: 'EDGE_CASE',
            reasoning: `input=${inputTokens}, tools=${toolsCount}, ambiguous`
        };
    }

    if (inputTokens < 4000 && toolsCount === 0) {
        return {
            classification: 'LOCAL_VIABLE',
            reasoning: `input=${inputTokens}<4k, simple request, no tools`
        };
    }

    return {
        classification: 'EDGE_CASE',
        reasoning: `default: input=${inputTokens}, tools=${toolsCount}`
    };
}

/**
 * Calculate cost in USD for a request
 */
function calculateCost(inputTokens, outputTokens, model) {
    const pricing = PRICING[model] || PRICING['claude-haiku-4-5'];
    const inputCost = (inputTokens / 1_000_000) * pricing.input;
    const outputCost = (outputTokens / 1_000_000) * pricing.output;
    return inputCost + outputCost;
}

/**
 * Parse all session JSONL files incrementally
 * Scans OPENCLAW_SESSIONS_DIR for agent session logs
 */
async function parseAllSessionJsonl() {
    const results = [];
    
    try {
        // Find all agent directories
        const agents = await fs.readdir(SESSIONS_DIR);
        
        for (const agent of agents) {
            const sessionsPath = path.join(SESSIONS_DIR, agent, 'sessions');
            try {
                const files = await fs.readdir(sessionsPath);
                const jsonlFiles = files.filter(f => f.endsWith('.jsonl'));
                
                for (const file of jsonlFiles) {
                    const filePath = path.join(sessionsPath, file);
                    const content = await fs.readFile(filePath, 'utf-8');
                    const lines = content.split('\n').filter(l => l.trim());
                    
                    for (const line of lines) {
                        try {
                            const entry = JSON.parse(line);
                            
                            // Filter valid requests with usage data - only assistant messages
                            if (entry.type === 'message' && entry.message?.usage && entry.message?.role === 'assistant') {
                                const { classification, reasoning } = classifyRequest(entry);
                                const usage = entry.message.usage;
                                const cost = calculateCost(
                                    usage.input || 0,
                                    usage.output || 0,
                                    entry.message?.model || 'claude-haiku-4-5'
                                );

                                // Extract prompt preview
                                let preview = '';
                                if (entry.message?.content) {
                                    const content = entry.message.content;
                                    if (Array.isArray(content)) {
                                        const textBlock = content.find(b => b.type === 'text');
                                        preview = (textBlock?.text || '').substring(0, 100);
                                    } else if (typeof content === 'string') {
                                        preview = content.substring(0, 100);
                                    }
                                }

                                // Parse timestamp
                                let timestamp = entry.timestamp;
                                if (typeof timestamp === 'string') {
                                    timestamp = new Date(timestamp).getTime();
                                } else if (!timestamp) {
                                    timestamp = entry.message?.timestamp || Date.now();
                                }

                                results.push({
                                    id: `${timestamp}-${agent}-${Math.random().toString(36).substr(2, 9)}`,
                                    timestamp: timestamp,
                                    agent_name: agent,
                                    model_used: entry.message?.model || 'claude-haiku-4-5',
                                    input_tokens: usage.input || 0,
                                    output_tokens: usage.output || 0,
                                    cache_read: usage.cacheRead || 0,
                                    cache_write: usage.cacheWrite || 0,
                                    thinking_tokens: usage.thinking || 0,
                                    total_cost_usd: parseFloat(cost.toFixed(6)),
                                    tools_used: [],
                                    tools_count: 0,
                                    classification,
                                    reasoning,
                                    prompt_preview: preview,
                                    success: entry.message?.stopReason !== 'error',
                                    stop_reason: entry.message?.stopReason || 'unknown'
                                });
                            }
                        } catch (e) {
                            // Skip malformed JSON lines
                        }
                    }
                }
            } catch (e) {
                // Skip agents without sessions directory
            }
        }
    } catch (e) {
        console.error('Error parsing JSONL:', e.message);
    }
    
    return results;
}

/**
 * Load existing requests from cache file
 */
async function loadExistingRequests() {
    try {
        const content = await fs.readFile(REQUESTS_FILE, 'utf-8');
        const data = JSON.parse(content);
        return data.requests || [];
    } catch (e) {
        return [];
    }
}

/**
 * Aggregate and save requests to JSON cache
 */
async function aggregateRequests() {
    // Ensure data directory exists
    try {
        await fs.mkdir(DATA_DIR, { recursive: true });
    } catch (e) {
        // Already exists
    }

    const allRequests = await parseAllSessionJsonl();
    
    // Deduplicate by id
    const existingRequests = await loadExistingRequests();
    const existingIds = new Set(existingRequests.map(r => r.id));
    const newRequests = allRequests.filter(r => !existingIds.has(r.id));
    
    const combined = [...existingRequests, ...newRequests].sort((a, b) => b.timestamp - a.timestamp);
    
    // Keep only last 50k requests to prevent memory exhaustion
    const MAX_CACHE_SIZE = 50000;
    const trimmed = combined.slice(0, MAX_CACHE_SIZE);
    
    // Save requests file
    await fs.writeFile(REQUESTS_FILE, JSON.stringify({
        requests: trimmed,
        generated_at: new Date().toISOString(),
        total_count: combined.length,
        cached_count: trimmed.length
    }, null, 2));

    return trimmed;
}

/**
 * Calculate aggregated metrics from requests
 */
function calculateMetrics(requests) {
    if (requests.length === 0) {
        return {
            period: 'N/A',
            summary: {
                total_requests: 0,
                total_cost: 0,
                avg_cost_per_request: 0,
                avg_input_tokens: 0,
                avg_output_tokens: 0
            },
            classification_breakdown: {},
            by_agent: {},
            by_model: {},
            projection: {}
        };
    }

    // Period calculation (last 7 days)
    const oldest = Math.min(...requests.map(r => r.timestamp));
    const newest = Math.max(...requests.map(r => r.timestamp));
    const startDate = new Date(oldest).toISOString().split('T')[0];
    const endDate = new Date(newest).toISOString().split('T')[0];

    // Summary stats
    const totalCost = requests.reduce((sum, r) => sum + (r.total_cost_usd || 0), 0);
    const totalInput = requests.reduce((sum, r) => sum + (r.input_tokens || 0), 0);
    const totalOutput = requests.reduce((sum, r) => sum + (r.output_tokens || 0), 0);

    // Classification breakdown
    const byClassification = {};
    ['LOCAL_VIABLE', 'NEEDS_CLAUDE', 'EDGE_CASE'].forEach(cls => {
        const items = requests.filter(r => r.classification === cls);
        const cost = items.reduce((sum, r) => sum + (r.total_cost_usd || 0), 0);
        
        byClassification[cls] = {
            count: items.length,
            percentage: Math.round((items.length / requests.length) * 100),
            total_cost: parseFloat(cost.toFixed(6)),
            potential_savings: cls === 'LOCAL_VIABLE' ? parseFloat(cost.toFixed(6)) : 0
        };
    });

    // By agent
    const byAgent = {};
    const agentGroups = {};
    requests.forEach(r => {
        if (!agentGroups[r.agent_name]) {
            agentGroups[r.agent_name] = [];
        }
        agentGroups[r.agent_name].push(r);
    });

    Object.entries(agentGroups).forEach(([agent, items]) => {
        const cost = items.reduce((sum, r) => sum + (r.total_cost_usd || 0), 0);
        const localCount = items.filter(r => r.classification === 'LOCAL_VIABLE').length;
        byAgent[agent] = {
            count: items.length,
            cost: parseFloat(cost.toFixed(6)),
            local_viable: localCount,
            percentage_local: Math.round((localCount / items.length) * 100)
        };
    });

    // By model
    const byModel = {};
    const modelGroups = {};
    requests.forEach(r => {
        if (!modelGroups[r.model_used]) {
            modelGroups[r.model_used] = [];
        }
        modelGroups[r.model_used].push(r);
    });

    Object.entries(modelGroups).forEach(([model, items]) => {
        const cost = items.reduce((sum, r) => sum + (r.total_cost_usd || 0), 0);
        byModel[model] = {
            count: items.length,
            cost: parseFloat(cost.toFixed(6)),
            percentage: Math.round((items.length / requests.length) * 100)
        };
    });

    // M4 Pro projection
    const localViableCount = byClassification.LOCAL_VIABLE?.count || 0;
    const localViableCost = byClassification.LOCAL_VIABLE?.total_cost || 0;
    const currentMonthly = totalCost * (30 / Math.max(1, (newest - oldest) / (24 * 60 * 60 * 1000)));
    const estimatedM4ProCost = 20; // Monthly subscription estimate
    const potentialSavings = localViableCost * (30 / Math.max(1, (newest - oldest) / (24 * 60 * 60 * 1000)));

    return {
        period: `${startDate} → ${endDate}`,
        summary: {
            total_requests: requests.length,
            total_cost: parseFloat(totalCost.toFixed(6)),
            avg_cost_per_request: parseFloat((totalCost / requests.length).toFixed(6)),
            avg_input_tokens: Math.round(totalInput / requests.length),
            avg_output_tokens: Math.round(totalOutput / requests.length)
        },
        classification_breakdown: byClassification,
        by_agent: byAgent,
        by_model: byModel,
        projection: {
            m4_pro_monthly_cost: estimatedM4ProCost,
            current_monthly_estimate: parseFloat(currentMonthly.toFixed(2)),
            potential_savings_monthly: parseFloat(potentialSavings.toFixed(2)),
            breakeven_requests_per_month: 50000,
            roi: potentialSavings > estimatedM4ProCost ? 'POSITIVE' : 'EVALUATE'
        }
    };
}

/**
 * Get aggregated metrics for a time period
 */
async function getMetrics(period = 'all') {
    const allRequests = await aggregateRequests();
    
    let filtered = allRequests;
    if (period !== 'all') {
        const now = Date.now();
        const daysMs = {
            today: 1,
            week: 7,
            month: 30
        }[period] || 7;
        
        const cutoff = now - (daysMs * 24 * 60 * 60 * 1000);
        filtered = allRequests.filter(r => r.timestamp >= cutoff);
    }

    const metrics = calculateMetrics(filtered);
    
    // Save metrics
    try {
        await fs.mkdir(DATA_DIR, { recursive: true });
        await fs.writeFile(METRICS_FILE, JSON.stringify(metrics, null, 2));
    } catch (e) {
        console.error('Error saving metrics:', e.message);
    }

    return metrics;
}

/**
 * Get individual requests with filtering and pagination
 */
async function getRequests(filters = {}) {
    const allRequests = await aggregateRequests();
    
    let filtered = allRequests;

    // Apply filters
    if (filters.agent) {
        filtered = filtered.filter(r => r.agent_name === filters.agent);
    }
    if (filters.classification) {
        filtered = filtered.filter(r => r.classification === filters.classification);
    }
    if (filters.model) {
        filtered = filtered.filter(r => r.model_used === filters.model);
    }
    if (filters.days) {
        const cutoff = Date.now() - (parseInt(filters.days) * 24 * 60 * 60 * 1000);
        filtered = filtered.filter(r => r.timestamp >= cutoff);
    }

    // Pagination
    const page = parseInt(filters.page) || 1;
    const limit = parseInt(filters.limit) || 50;
    const start = (page - 1) * limit;
    const end = start + limit;

    return {
        requests: filtered.slice(start, end),
        total: filtered.length,
        page,
        limit,
        pages: Math.ceil(filtered.length / limit)
    };
}

module.exports = {
    parseAllSessionJsonl,
    aggregateRequests,
    getMetrics,
    getRequests,
    calculateCost,
    classifyRequest,
    PRICING
};

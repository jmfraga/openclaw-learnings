// Update Dashboard - Server Handlers
// Extract from hub/server.js - paste into your server
// PIN: change UPDATE_PIN to your own 4-digit code

const { exec } = require('child_process');
const { promisify } = require('util');
const execPromise = promisify(exec);

// ── Update Operation Lock ─────────────────────────────────────────────────────
let operationLock = null;
let operationLockTime = null;
const OPERATION_LOCK_TIMEOUT = 10 * 60 * 1000; // 10 minutes

function checkAndClearLock() {
    if (operationLock !== null && operationLockTime !== null) {
        if (Date.now() - operationLockTime > OPERATION_LOCK_TIMEOUT) {
            console.log(`[UPDATE] Lock timeout - clearing stale lock: ${operationLock}`);
            operationLock = null;
            operationLockTime = null;
        }
    }
}

function acquireLock(operation) {
    checkAndClearLock();
    if (operationLock !== null) return false;
    operationLock = operation;
    operationLockTime = Date.now();
    return true;
}

function releaseLock() {
    operationLock = null;
    operationLockTime = null;
}

// ── PIN Authentication ────────────────────────────────────────────────────────
const UPDATE_PIN = '1234';

function checkUpdatePin(req, res) {
    const pin = req.headers['x-update-pin'];
    if (!pin || pin !== UPDATE_PIN) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'PIN requerido', code: 'auth_required' }));
        return false;
    }
    return true;
}

// ── Body reader helper ────────────────────────────────────────────────────────
function readBody(req) {
    return new Promise((resolve) => {
        let body = '';
        req.on('data', chunk => { body += chunk.toString(); });
        req.on('end', () => {
            try { resolve(JSON.parse(body)); } catch { resolve({}); }
        });
    });
}

async function handleApiUpdateStatus(req, res) {
    try {
        console.log('[UPDATE] Checking version status...');
        
        // Get current version
        const currentVersion = await execPromise('openclaw --version')
            .then(result => result.stdout.trim())
            .catch(() => 'unknown');
        
        // Get latest version from npm
        const latestVersion = await execPromise('npm view openclaw version')
            .then(result => result.stdout.trim())
            .catch(() => 'unknown');
        
        const updateAvailable = currentVersion !== latestVersion && 
                               currentVersion !== 'unknown' && 
                               latestVersion !== 'unknown';
        
        // Check gateway status
        let gatewayStatus = { running: false };
        try {
            const gwStatus = await execPromise('systemctl --user is-active oc-gw.service')
                .then(r => r.stdout.trim() === 'active')
                .catch(() => false);
            
            if (gwStatus) {
                const gwInfo = await execPromise('systemctl --user show oc-gw.service --property=MainPID,ActiveState,ActiveEnterTimestamp')
                    .then(r => {
                        const lines = r.stdout.trim().split('\n');
                        const pid = lines[0].split('=')[1];
                        const uptime = lines[2].split('=')[1];
                        return { pid, uptime };
                    })
                    .catch(() => ({ pid: 'unknown', uptime: 'unknown' }));
                
                gatewayStatus = {
                    running: true,
                    pid: gwInfo.pid,
                    uptime: gwInfo.uptime
                };
            }
        } catch (e) {
            console.log('[UPDATE] Gateway status check failed:', e.message);
        }
        
        // Check last backup info (supports both .json and .tar.gz)
        let lastBackup = { exists: false };
        try {
            const backupDir = '~/.openclaw/backups';
            if (fs.existsSync(backupDir)) {
                const backups = fs.readdirSync(backupDir)
                    .filter(f => f.startsWith('openclaw-') && (f.endsWith('.json') || f.endsWith('.tar.gz')))
                    .sort()
                    .reverse();
                if (backups.length > 0) {
                    const latestBackupPath = path.join(backupDir, backups[0]);
                    const stat = fs.statSync(latestBackupPath);
                    const ageMs = Date.now() - stat.mtimeMs;
                    lastBackup = {
                        exists: true,
                        name: backups[0],
                        type: backups[0].endsWith('.tar.gz') ? 'tarball' : 'json',
                        modified: stat.mtime.toISOString(),
                        age_hours: Math.round(ageMs / 3600000),
                        age_minutes: Math.round(ageMs / 60000),
                        size_mb: (stat.size / 1048576).toFixed(2)
                    };
                }
            }
        } catch (e) {
            console.log('[UPDATE] Backup check failed:', e.message);
        }

        // Check last update timestamp
        let lastUpdate = null;
        try {
            const logFile = '~/.openclaw/logs/update-update.log';
            if (fs.existsSync(logFile)) {
                const stat = fs.statSync(logFile);
                lastUpdate = stat.mtime.toISOString();
            }
        } catch (e) {}

        const data = {
            current_version: currentVersion,
            latest_version: latestVersion,
            update_available: updateAvailable,
            gateway: gatewayStatus,
            last_update: lastUpdate,
            last_backup: lastBackup,
            timestamp: new Date().toISOString()
        };
        
        console.log(`[UPDATE] Status: current=${currentVersion}, latest=${latestVersion}, available=${updateAvailable}`);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data, null, 2));
    } catch (error) {
        console.error('[UPDATE] Error checking status:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
    }
}

async function handleApiUpdatePreflight(req, res) {
    try {
        console.log('[UPDATE] Running pre-flight checks...');
        const checks = [];
        
        // 1. Check disk space
        try {
            const df = await execPromise('df -h ~/.openclaw');
            const lines = df.stdout.split('\n');
            const dataLine = lines[1] || '';
            const parts = dataLine.split(/\s+/);
            const usePercent = parts[4] || '0%';
            const useValue = parseInt(usePercent);
            
            checks.push({
                name: 'disk_space',
                status: useValue < 90 ? 'pass' : (useValue < 95 ? 'warning' : 'fail'),
                message: `Disk usage: ${usePercent}`,
                details: { usage: usePercent }
            });
        } catch (error) {
            checks.push({
                name: 'disk_space',
                status: 'warning',
                message: 'Could not check disk space',
                details: { error: error.message }
            });
        }
        
        // 2. Check write permissions
        try {
            const testFile = '~/.openclaw/.write-test';
            await execPromise(`touch ${testFile} && rm ${testFile}`);
            checks.push({
                name: 'permissions',
                status: 'pass',
                message: 'Write permissions OK'
            });
        } catch (error) {
            checks.push({
                name: 'permissions',
                status: 'fail',
                message: 'No write permissions in .openclaw directory',
                details: { error: error.message }
            });
        }
        
        // 3. Check if git repo is clean (for workspace)
        try {
            const gitStatus = await execPromise('cd ~/.openclaw && git status --porcelain 2>/dev/null || echo "not_a_repo"');
            const output = gitStatus.stdout.trim();
            
            if (output === 'not_a_repo' || output === '') {
                checks.push({
                    name: 'git_status',
                    status: 'pass',
                    message: 'Git status clean or not a repository'
                });
            } else {
                checks.push({
                    name: 'git_status',
                    status: 'warning',
                    message: 'Uncommitted changes in .openclaw directory',
                    details: { changes: output }
                });
            }
        } catch (error) {
            checks.push({
                name: 'git_status',
                status: 'warning',
                message: 'Could not check git status',
                details: { error: error.message }
            });
        }
        
        // 4. Check if gateway service is running (via systemctl, not process grep)
        try {
            const gwActive = await execPromise('systemctl --user is-active oc-gw.service')
                .then(r => r.stdout.trim() === 'active')
                .catch(() => false);
            checks.push({
                name: 'gateway_running',
                status: gwActive ? 'pass' : 'warning',
                message: gwActive ? 'Gateway is running (oc-gw.service)' : 'Gateway is not running'
            });
        } catch (error) {
            checks.push({
                name: 'gateway_running',
                status: 'warning',
                message: 'Gateway is not running'
            });
        }
        
        // 5. Check active sessions
        try {
            const sessionsOut = await execPromise('openclaw status 2>/dev/null | grep -ci "active" || echo 0')
                .then(r => parseInt(r.stdout.trim()) || 0)
                .catch(() => 0);
            checks.push({
                name: 'active_sessions',
                status: sessionsOut > 0 ? 'warning' : 'pass',
                message: sessionsOut > 0 ? `${sessionsOut} sesión(es) activa(s) detectada(s)` : 'No hay sesiones activas',
                details: { active_count: sessionsOut }
            });
        } catch (error) {
            checks.push({
                name: 'active_sessions',
                status: 'warning',
                message: 'No se pudo verificar sesiones activas',
                details: { error: error.message }
            });
        }

        // 6. Check recent backup (< 1 hour)
        try {
            const backupDir = '~/.openclaw/backups';
            let recentBackupFound = false;
            if (fs.existsSync(backupDir)) {
                const backups = fs.readdirSync(backupDir)
                    .filter(f => f.startsWith('openclaw-') && (f.endsWith('.json') || f.endsWith('.tar.gz')))
                    .sort().reverse();
                if (backups.length > 0) {
                    const stat = fs.statSync(path.join(backupDir, backups[0]));
                    const ageMs = Date.now() - stat.mtimeMs;
                    recentBackupFound = ageMs < 3600000; // 1 hour
                    checks.push({
                        name: 'recent_backup',
                        status: recentBackupFound ? 'pass' : 'warning',
                        message: recentBackupFound
                            ? `Backup reciente encontrado (${Math.round(ageMs / 60000)} min)`
                            : `Último backup hace ${Math.round(ageMs / 3600000)}h - considera hacer uno nuevo`,
                        details: { backup: backups[0], age_minutes: Math.round(ageMs / 60000) }
                    });
                } else {
                    checks.push({
                        name: 'recent_backup',
                        status: 'warning',
                        message: 'No se encontraron backups - ejecuta uno antes de actualizar'
                    });
                }
            } else {
                checks.push({
                    name: 'recent_backup',
                    status: 'warning',
                    message: 'Directorio de backups no encontrado'
                });
            }
        } catch (error) {
            checks.push({
                name: 'recent_backup',
                status: 'warning',
                message: 'No se pudo verificar backups recientes',
                details: { error: error.message }
            });
        }

        // 7. Check available memory (>500MB required)
        try {
            const freeOut = await execPromise('free -m').then(r => r.stdout);
            const lines = freeOut.split('\n');
            const memLine = lines.find(l => l.startsWith('Mem:')) || '';
            const parts = memLine.split(/\s+/);
            const availMb = parseInt(parts[6]) || parseInt(parts[3]) || 0;
            checks.push({
                name: 'memory',
                status: availMb >= 500 ? 'pass' : 'warning',
                message: availMb >= 500
                    ? `Memoria disponible: ${availMb} MB`
                    : `Memoria disponible baja: ${availMb} MB (recomendado >500 MB)`,
                details: { available_mb: availMb }
            });
        } catch (error) {
            checks.push({
                name: 'memory',
                status: 'warning',
                message: 'No se pudo verificar memoria disponible',
                details: { error: error.message }
            });
        }

        // 8. Check CPU load
        try {
            const loadAvgRaw = fs.readFileSync('/proc/loadavg', 'utf8').trim();
            const load1 = parseFloat(loadAvgRaw.split(' ')[0]);
            const numCpus = os.cpus().length;
            checks.push({
                name: 'cpu_load',
                status: load1 <= numCpus ? 'pass' : 'warning',
                message: load1 <= numCpus
                    ? `Carga CPU normal: ${load1.toFixed(2)} (${numCpus} CPUs)`
                    : `Carga CPU alta: ${load1.toFixed(2)} > ${numCpus} CPUs`,
                details: { load1, num_cpus: numCpus }
            });
        } catch (error) {
            checks.push({
                name: 'cpu_load',
                status: 'warning',
                message: 'No se pudo verificar carga CPU',
                details: { error: error.message }
            });
        }

        const allPassed = checks.every(c => c.status === 'pass');
        const hasFailed = checks.some(c => c.status === 'fail');
        
        const data = {
            ready: allPassed,
            status: hasFailed ? 'fail' : (allPassed ? 'ready' : 'warning'),
            checks,
            timestamp: new Date().toISOString()
        };
        
        console.log(`[UPDATE] Pre-flight complete: ${data.status}`);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data, null, 2));
    } catch (error) {
        console.error('[UPDATE] Error in pre-flight checks:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
    }
}

async function handleApiUpdateBackup(req, res) {
    if (req.method !== 'POST') {
        res.writeHead(405, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Method not allowed' }));
        return;
    }

    if (!acquireLock('backup')) {
        res.writeHead(409, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Operación en curso', operation: operationLock }));
        return;
    }

    try {
        console.log('[UPDATE] Creating comprehensive tarball backup...');

        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupDir = '~/.openclaw/backups';
        const backupPath = `${backupDir}/openclaw-backup-${timestamp}.tar.gz`;

        // Ensure backup directory exists
        if (!fs.existsSync(backupDir)) {
            fs.mkdirSync(backupDir, { recursive: true });
        }

        const tarCmd = [
            'tar czf', backupPath,
            '-C ~/.openclaw',
            'openclaw.json',
            'credentials/',
            'workspace-*/SOUL.md',
            'workspace-*/IDENTITY.md',
            'workspace-*/MEMORY.md',
            'workspace-*/USER.md',
            'workspace-*/TOOLS.md',
            '2>/dev/null || true'
        ].join(' ');

        await execPromise(tarCmd, { timeout: 60000 });

        const backupExists = fs.existsSync(backupPath);
        let backupSizeMb = '0';
        if (backupExists) {
            const stat = fs.statSync(backupPath);
            backupSizeMb = (stat.size / 1048576).toFixed(2);
        }

        // Write backup log
        const logsDir = '~/.openclaw/logs';
        if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, { recursive: true });
        const logFilePath = path.join(logsDir, 'update-backup.log');
        const logContent = [
            `Backup created: ${backupPath}`,
            `Timestamp: ${new Date().toISOString()}`,
            `Type: tarball (.tar.gz)`,
            `Size: ${backupSizeMb} MB`,
            `Includes: openclaw.json, credentials/, workspace-*/SOUL.md, IDENTITY.md, MEMORY.md, USER.md, TOOLS.md`,
            `Success: ${backupExists}`
        ].join('\n') + '\n';
        fs.writeFileSync(logFilePath, logContent);

        console.log(`[UPDATE] Backup created: ${backupPath} (${backupSizeMb} MB)`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: backupExists,
            backupPath,
            size_mb: backupSizeMb,
            type: 'tarball',
            log_file: logFilePath,
            timestamp: new Date().toISOString()
        }, null, 2));
    } catch (error) {
        console.error('[UPDATE] Error creating backup:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message, success: false }));
    } finally {
        releaseLock();
    }
}

async function handleApiUpdateRun(req, res) {
    if (req.method !== 'POST') {
        res.writeHead(405, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Method not allowed' }));
        return;
    }

    // Read body to check for dry_run flag
    const body = await readBody(req);
    const isDryRun = body.dry_run === true;

    if (isDryRun) {
        // Dry-run: just check versions, no actual update
        try {
            console.log('[UPDATE] Dry-run requested - checking versions only...');
            const currentVersion = await execPromise('openclaw --version')
                .then(r => r.stdout.trim()).catch(() => 'unknown');
            const latestVersion = await execPromise('npm view openclaw version')
                .then(r => r.stdout.trim()).catch(() => 'unknown');

            console.log(`[UPDATE] Dry-run: current=${currentVersion}, latest=${latestVersion}`);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                success: true,
                dry_run: true,
                would_update_to: latestVersion,
                current: currentVersion,
                message: `Dry-run: would update from ${currentVersion} to ${latestVersion}`,
                timestamp: new Date().toISOString()
            }, null, 2));
        } catch (error) {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: error.message, success: false, dry_run: true }));
        }
        return;
    }

    if (!acquireLock('update')) {
        res.writeHead(409, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Operación en curso', operation: operationLock }));
        return;
    }

    try {
        console.log('[UPDATE] Starting update process...');

        const logs = [];
        const logLine = (msg) => {
            logs.push(msg);
            console.log(`[UPDATE] ${msg}`);
        };

        const logsDir = '~/.openclaw/logs';
        if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, { recursive: true });
        const logFile = path.join(logsDir, 'update-update.log');

        try {
            const beforeVersion = await execPromise('openclaw --version')
                .then(r => r.stdout.trim()).catch(() => 'unknown');
            logLine(`Current version: ${beforeVersion}`);

            logLine('Running npm update -g openclaw...');
            const updateResult = await execPromise('npm update -g openclaw 2>&1', { timeout: 300000 });
            logLine(updateResult.stdout.trim() || 'npm update completed');

            const afterVersion = await execPromise('openclaw --version')
                .then(r => r.stdout.trim()).catch(() => 'unknown');
            logLine(`New version: ${afterVersion}`);

            logLine('Restarting gateway via systemctl...');
            await execPromise('systemctl --user restart oc-gw.service', { timeout: 30000 });
            logLine('Gateway restarted successfully');

            await new Promise(resolve => setTimeout(resolve, 5000));
            const gwActive = await execPromise('systemctl --user is-active oc-gw.service')
                .then(r => r.stdout.trim() === 'active')
                .catch(() => false);
            logLine(`Gateway status after restart: ${gwActive ? 'active' : 'NOT ACTIVE'}`);

            const success = afterVersion !== 'unknown' && gwActive;
            fs.writeFileSync(logFile, logs.join('\n') + '\n');

            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                success,
                new_version: afterVersion,
                old_version: beforeVersion,
                message: success ? `Updated from ${beforeVersion} to ${afterVersion}` : 'Update completed with warnings',
                log_file: logFile,
                logs,
                timestamp: new Date().toISOString()
            }, null, 2));
        } catch (updateError) {
            logLine(`ERROR: ${updateError.message}`);
            fs.writeFileSync(logFile, logs.join('\n') + '\n');

            res.writeHead(200, { 'Content-Type': 'application/json' });

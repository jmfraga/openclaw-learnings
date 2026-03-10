# MCP Google Workspace — Auth Failure Patterns & Diagnostics

## Overview

**MCP Google Workspace** is an MCP (Model Context Protocol) server that provides access to Google Workspace APIs (Gmail, Calendar, Drive, etc.) for agents.

**This document:** Patterns for debugging auth failures and the critical distinction between "healthy" (connectivity) and "authenticated" (valid token).

---

## The Core Problem

### Symptom
All API calls fail with:
```
invalid_grant: Token has been expired or revoked
```

### Why It Happens
- Google OAuth tokens have **expiration times** (typically 1 hour for short-lived tokens)
- Service account credentials can be invalidated if:
  - Token lifetime exceeded
  - Credentials rotated/revoked on Google Cloud Console
  - User granted/revoked consent
  - Machine clock is out of sync

### The Trap
```bash
mcporter list google-workspace
# Output: Status: healthy ✓
```

**This does NOT mean auth is working!**

`mcporter list` only checks:
- Can I connect to the MCP server?
- Is the process running?
- Does it respond to basic requests?

It does **NOT test:**
- Is the OAuth token valid?
- Can I actually call Google APIs?
- Are credentials still authorized?

---

## Correct Diagnostic Procedure

### Step 1: Check Basic Connectivity
```bash
mcporter list google-workspace
```
- Should show: Status: healthy (process is running)
- If not: MCP server is down, restart it

### Step 2: Test Auth with Real API Call ⚠️ (Required)
```bash
mcporter call google-workspace.calendar_get_events \
  --args '{"time_min":"2026-01-01T00:00:00Z","time_max":"2026-12-31T23:59:59Z"}'
```

**Example successful response:**
```json
[
  {
    "id": "event123",
    "summary": "Team Meeting",
    "start": { "dateTime": "2026-03-10T14:00:00Z" },
    "end": { "dateTime": "2026-03-10T15:00:00Z" }
  }
]
```

**Example failure (bad auth):**
```
Error: invalid_grant: Token has been expired or revoked
```

### Step 3: If Auth Fails, Reset
```bash
mcporter auth google-workspace --reset
```

This will:
1. Invalidate the old token
2. Prompt you to re-authenticate via Google's OAuth flow
3. Fetch and cache a new token
4. Save credentials to mcporter's secure storage

### Step 4: Verify Auth Works
```bash
mcporter call google-workspace.calendar_get_events \
  --args '{"time_min":"2026-01-01T00:00:00Z","time_max":"2026-12-31T23:59:59Z"}'
```

Should now return events (or empty list if no events in that range).

---

## Why "Healthy" ≠ "Authenticated"

### Health Check (what `mcporter list` does)
```
✅ Connection to MCP process: OK
✅ Process responding: OK
✅ Config file readable: OK
→ Status: "healthy"
```

### Authentication Check (what you must do manually)
```
✅ OAuth token valid? ⬅️ Only real API call can answer this
✅ Google account still authorized? ⬅️ Real API call
✅ Token not expired? ⬅️ Real API call
```

**Analogy:** A car battery is "healthy" (charges, powers lights) but the engine may still not start (fuel pump broken).

---

## Common Scenarios

### Scenario 1: Daily Reset
**Problem:** Calls worked yesterday, fail today.

**Cause:** OAuth token expires (typical: 1 hour for short-lived, 3-6 months for service accounts).

**Solution:**
```bash
mcporter auth google-workspace --reset
# Follow OAuth flow → new token cached
mcporter call google-workspace.calendar_get_events --args '...'
```

### Scenario 2: Multiple Machines
**Problem:** Auth works on Machine A, fails on Machine B.

**Cause:** Each machine has separate token cache. Machine B never authenticated.

**Solution:**
```bash
# On Machine B:
mcporter auth google-workspace
# Complete OAuth flow
```

### Scenario 3: Service Account Rotation
**Problem:** Using service account JSON key; keys were rotated on Google Cloud Console.

**Cause:** Old key is now invalid.

**Solution:**
1. Download new service account JSON from Google Cloud Console
2. Update mcporter config:
```bash
mcporter config google-workspace --set-key path/to/new-service-account.json
```
3. Reset auth:
```bash
mcporter auth google-workspace --reset
```
4. Test:
```bash
mcporter call google-workspace.calendar_get_events --args '...'
```

### Scenario 4: System Clock Skew
**Problem:** MCP server is on a machine with wrong system time.

**Cause:** OAuth signatures depend on accurate timestamps. If clock is >5 min off, tokens are rejected.

**Solution:**
```bash
# Check system time
date
# If wrong, sync:
sudo ntpdate -s time.nist.gov  # or similar for your OS
# Then reset auth
mcporter auth google-workspace --reset
```

---

## Debugging Checklist

**When calls to Google Workspace fail:**

- [ ] Can other MCP servers connect? (test `mcporter list` on another server)
  - If yes: problem is specific to google-workspace config
  - If no: problem is network/mcporter infrastructure
  
- [ ] Did auth work before?
  - If yes, likely token expired → `mcporter auth --reset`
  - If no, credentials may be invalid → check config file path
  
- [ ] Is system time correct?
  - Run `date` and compare with world time
  - If skewed: sync time, then reset auth
  
- [ ] Is the Google account still authorized?
  - Try the same operation in Google Calendar web UI
  - If that fails too: account/permission issue (contact admin)
  
- [ ] Is mcporter.json config pointing to the right credentials?
  ```bash
  jq '.servers.google-workspace' ~/.mcporter/config.json
  ```
  - Should show path to valid credentials file

---

## Monitoring & Prevention

### Auto-Detect Expired Tokens
Wrap calls in a handler:
```javascript
async function callGoogleWorkspace(method, args) {
  try {
    return await mcporter.call(`google-workspace.${method}`, args);
  } catch (error) {
    if (error.message.includes('Token has been expired')) {
      console.log('Token expired, attempting reset...');
      await mcporter.auth('google-workspace', { reset: true });
      // Retry after reset
      return await mcporter.call(`google-workspace.${method}`, args);
    }
    throw error;
  }
}
```

### Log Auth Events
- When `mcporter auth --reset` is called
- When tokens are cached (timestamp logged)
- When calls fail with `invalid_grant` (alert immediately)

### Periodic Health Checks
```bash
# Cron job: every 6 hours
0 */6 * * * mcporter call google-workspace.calendar_get_events \
  --args '{"time_min":"2026-01-01T00:00:00Z","time_max":"2026-12-31T23:59:59Z"}' \
  || { echo "Google Workspace auth failed"; mcporter auth google-workspace --reset; }
```

---

## Key Takeaways

1. **`mcporter list` shows connectivity, NOT authentication**
   - A "healthy" server can still have expired tokens

2. **Always test with a real API call**
   ```bash
   mcporter call google-workspace.<some-method> --args <args>
   ```

3. **Token expiration is normal; reset is fast**
   ```bash
   mcporter auth google-workspace --reset
   ```

4. **Watch for `invalid_grant` errors**
   - This is the standard "auth failed" error from Google
   - Always trigger a reset when you see it

5. **Multi-machine deployments need per-machine auth**
   - Each machine needs its own token cache
   - Config can be shared; tokens cannot

---

## Related

- **MCP Documentation:** https://modelcontextprotocol.io/
- **Google Workspace Admin:** https://admin.google.com
- **Google OAuth Scopes:** https://developers.google.com/identity/protocols/oauth2/scopes
- **Service Account Setup:** https://cloud.google.com/docs/authentication#service_accounts


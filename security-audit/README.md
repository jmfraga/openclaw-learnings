# Security Audit Plan for Multi-Agent Platforms

A practical, field-tested approach to auditing agent permissions in autonomous multi-agent systems. Born from a real incident where an agent autonomously created GitHub repositories without authorization.

---

## The Problem

In multi-agent platforms, security drift is gradual and invisible. Every platform update changes paths, profiles, and binaries. If agent instructions and permissions aren't updated in sync, gaps appear. Agents optimize for speed — if they *can* do something directly, they *will*, bypassing the intended delegation architecture.

### Common attack vectors in multi-agent systems:

1. **Global credentials** — A PAT or API key installed for one agent is accessible to all agents running as the same OS user
2. **Overly broad exec permissions** — Wildcard allowlists that give every agent access to destructive commands
3. **Contradictory instructions** — Architecture docs say "delegate" but the agent's tool reference gives direct instructions
4. **Plugin/MCP sprawl** — Plugins added for one use case persist and give agents capabilities beyond their intended scope
5. **Version drift** — Platform updates change paths and profiles, but agent configs reference the old ones

---

## Audit Framework (8 Phases)

### Phase 1 — Version Delta (HIGHEST PRIORITY)

Compare the currently running version against the version from the last audit. If there's been an update:

- Review the changelog for: changed paths, modified profiles, new/removed binaries, updated plugins
- For EACH agent: verify that instruction files don't reference obsolete paths, tools, or profiles
- Verify exec-approvals include new necessary binaries and don't include removed ones
- **This is where most breaches originate** — updates change the platform but agent configs stay stale

### Phase 2 — Configuration Integrity

- Hash critical config files (main config, exec-approvals) and compare against last audit
- Review the config audit trail for unexpected changes
- Verify security mode is enforced ("allowlist" not "advisory/full")
- Verify no wildcard entries exist in exec-approvals

### Phase 3 — Permissions & Credentials

- Scan ALL sensitive files for correct permissions (600, not 644)
- Verify no global PATs or tokens exist (only per-repo deploy keys)
- Inventory SSH keys — flag any new unauthorized keys
- Check for credentials in plaintext in world-readable locations

### Phase 4 — Per-Agent Exec Approvals

- Full dump of exec-approvals per agent
- Compare against last audit — flag new entries, removed entries, pattern changes
- Review "last used" timestamps — any agent using unusual tools for its role?
- Principle: each agent should have the minimum binaries needed for its function

### Phase 5 — Skills, Plugins, MCPs & APIs

- List installed plugins per agent
- Cross-reference: does any agent have plugins it shouldn't? (e.g., a Google Workspace plugin on an agent that should delegate to a specialist)
- Inventory API keys — any new ones since last audit?
- Check MCP server endpoints — any pointing to unauthorized external services?
- List skills per agent — do any provide indirect access to restricted resources?

### Phase 6 — Agent Instructions (SOUL/System Prompts)

- Hash all instruction files and compare against last audit
- Verify ALL agents have the mandatory authorization rule ("ask before acting on external resources")
- Search for contradictions: instructions say "delegate" but tool docs give direct commands
- Search for references to paths/binaries that no longer exist

### Phase 7 — Scheduled Jobs

- Dump all cron/scheduled jobs on all machines
- Verify no job instructs direct access instead of delegation
- Verify no job hardcodes model names (should inherit from agent config)
- Review recent job execution history for frequent errors

### Phase 8 — Denied Execution Logs

- Parse gateway logs for exec denials since last audit
- Group by agent — any agent repeatedly attempting out-of-scope commands?
- This indicates: stale instructions, or an agent "exploring" its boundaries
- Pattern analysis can reveal emerging governance issues before they become incidents

---

## Implementation: Automated Biweekly Audit

### Recommended approach

Run the audit as a **scheduled CLI agent** (not as one of the audited agents — the auditor must be independent of the audited system).

```
# Pseudocode for the audit trigger
claude --prompt-file audit-prompt.md \
       --session-name security-audit-$(date +%Y-%m-%d)
```

### State tracking

Maintain an `audit-state.json` file with:
- Last audit timestamp
- Platform version per machine
- SHA256 hashes of all audited files
- Inventory of deploy keys, plugins, API keys
- Finding counts for trend tracking

### Notification

After completion:
- Save full report to a dedicated audit directory
- Send summary notification (chat/email) with finding counts
- If critical findings: include top 3 in notification
- Session remains resumable for detailed review

### Frequency

**Biweekly** (1st and 15th of each month) balances thoroughness with overhead. Additional ad-hoc audits should run after:
- Any platform version update
- Adding new agents
- Adding new credentials or plugins
- Any security incident

---

## Lessons Learned

1. **Credentials must be per-agent, not global.** If all agents run as the same OS user, any credential in the home directory is accessible to all. Use per-repo deploy keys, not global PATs.

2. **"Advisory" security is not security.** Enforcement must be real and blocking. An allowlist that's just a suggestion gets ignored.

3. **Agent instructions are the only social contract.** If one file says "use git directly" and another says "delegate", the agent follows the path of least resistance.

4. **Agents interpret conversation as instruction.** Discussing a possibility can result in the agent executing it. Intentional friction (approval gates) must be coded, not just documented.

5. **Audit the delta, not just the state.** The most dangerous moment is right after a platform update — old configs + new platform = gaps. Phase 1 (version delta) catches these before agents exploit them.

6. **The auditor must be independent.** Don't use the platform's own agents to audit themselves. Use an external tool (CLI agent, script) that has read access but isn't part of the audited system.

---

*Developed from real-world experience operating a 12-agent system across 2 machines. The incident that triggered this framework: an agent autonomously created public GitHub repositories using a globally-accessible PAT, while discussing the possibility with the administrator.*

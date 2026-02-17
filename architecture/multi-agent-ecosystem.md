# Multi-Agent Ecosystem Architecture

**Document Version:** 1.0  
**Last Updated:** 2026-02-17  
**Status:** Production

## Overview

This document describes a production multi-agent architecture built on OpenClaw, featuring specialized agents that collaborate to handle diverse tasks across technical development, medical assistance, project management, and operational workflows.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         EXTERNAL INTERFACES                      │
│  Telegram • WhatsApp Groups • Google Workspace • GitHub         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                ┌────────────┴───────────┐
                │    PM (Orchestrator)    │
                │   Claude Sonnet 4.5     │
                │  Primary Coordinator    │
                └────┬─────────────┬──────┘
                     │             │
         ┌───────────┼─────────────┼──────────────┐
         │           │             │              │
    ┌────▼────┐ ┌───▼────┐  ┌────▼────┐    ┌────▼────┐
    │ Phoenix │ │ CHAPPiE│  │  Iris   │    │  Atlas  │
    │ Sonnet  │ │ Sonnet │  │ Sonnet  │    │  Haiku  │
    │Strategy │ │DevOps  │  │Medical  │    │Knowledge│
    └─────────┘ └────┬───┘  └────┬────┘    └─────────┘
                     │           │
                ┌────▼────┐ ┌───▼────┐
                │  Argus  │ │ Quill  │
                │  Haiku  │ │ Haiku  │
                │Security │ │Content │
                └─────────┘ └────────┘
```

## Agent Family

### 1. **PM (Project Manager)**
- **Model:** Claude Sonnet 4.5
- **Role:** Central orchestrator and coordinator
- **Responsibilities:**
  - Primary interface for user interactions
  - Delegates tasks to specialized agents
  - Coordinates cross-functional workflows
  - Maintains project context and continuity
  - Escalates complex decisions to user
- **Channels:** Telegram (primary), WhatsApp groups, subagent delegation
- **Decision Authority:** High - can spawn and coordinate all other agents

### 2. **Phoenix (Strategic Advisor)**
- **Model:** Claude Sonnet 4.5
- **Role:** High-level strategic thinking and complex problem-solving
- **Responsibilities:**
  - Business strategy and planning
  - Complex architectural decisions
  - Research and analysis
  - Long-form strategic recommendations
  - Public-facing content creation (landing pages, public sites)
- **Delegation Pattern:** Called by PM for strategic matters
- **Why Sonnet:** Requires sophisticated reasoning and strategic depth
- **Integrations:** GitHub (individual SSH key for public pages and landing pages)

### 3. **CHAPPiE (Technical Operations)**
- **Model:** Claude Sonnet 4.5
- **Role:** DevOps, development, and technical execution
- **Responsibilities:**
  - Code development and modifications
  - Git operations and version control
  - System configuration and deployment
  - Infrastructure management
  - Technical documentation
- **Delegation Pattern:** PM delegates technical implementation tasks
- **Why Sonnet:** Complex technical reasoning, code generation, multi-step workflows
- **Integrations:** GitHub, local repositories, system tools

### 4. **Iris (Medical Intelligence)**
- **Model:** Claude Sonnet 4.5
- **Sub-variants:**
  - **Iris Assistant:** General medical coordination
  - **Iris Med:** Clinical decision support
- **Role:** Medical information and healthcare workflows
- **Responsibilities:**
  - Medical information synthesis
  - Healthcare workflow coordination
  - Patient interaction support (anonymized)
  - Medical research and literature review
- **Delegation Pattern:** PM routes medical queries to Iris
- **Why Sonnet:** Medical accuracy and nuanced clinical reasoning critical
- **Security:** Strict PHI/PII filtering, no patient identifiers stored

### 5. **Atlas (Knowledge Management)**
- **Model:** Claude Haiku
- **Role:** Information retrieval and knowledge organization
- **Responsibilities:**
  - Quick fact-checking and lookups
  - Document organization
  - Simple data transformations
  - Routine information gathering
- **Delegation Pattern:** Called for lightweight knowledge tasks
- **Why Haiku:** Fast, cost-effective for simple queries

### 6. **Argus (Security & Monitoring)**
- **Model:** Claude Haiku
- **Role:** Security monitoring and compliance checks
- **Responsibilities:**
  - Log monitoring and analysis
  - Security incident detection
  - Compliance verification
  - Access pattern analysis
- **Delegation Pattern:** Periodic checks, triggered by PM or automated
- **Why Haiku:** Pattern matching and rule-based checks don't require Sonnet

### 7. **Quill (Content Creation)**
- **Model:** Claude Haiku
- **Role:** Content generation and documentation
- **Responsibilities:**
  - Draft emails and messages
  - Meeting notes and summaries
  - Simple documentation updates
  - Social media content
- **Delegation Pattern:** PM delegates routine writing tasks
- **Why Haiku:** Sufficient for most writing; Sonnet for complex narratives

## Communication Channels

### Primary Channels

1. **Telegram**
   - Direct human ↔ agent interaction
   - Agent notifications and proactive updates
   - Inline keyboards for confirmations
   - Used by: PM, CHAPPiE, Phoenix, Iris

2. **WhatsApp Groups**
   - Multi-party collaboration
   - Group coordination and updates
   - Agents participate as team members
   - Pattern: Selective participation, not reactive to every message

3. **Subagent Delegation (Internal)**
   - PM spawns specialized agents as subagents
   - Push-based completion (no polling)
   - Isolated context for focused work
   - Auto-announcement of results back to parent

### Integration Channels

4. **Google Workspace (via mcporter)**
   - Gmail access for email monitoring
   - Calendar integration for scheduling
   - Google Docs/Drive for document collaboration

5. **GitHub**
   - Repository management
   - Issue tracking
   - Code review and collaboration
   - Managed primarily by CHAPPiE

## Common Workflows

### Workflow 1: Technical Change Request

```
1. User → PM: "Update the authentication module"
2. PM analyzes scope and complexity
3. PM → CHAPPiE (subagent): Technical implementation
4. CHAPPiE:
   - Reads current code
   - Makes modifications
   - Runs tests
   - Commits changes
   - Reports back
5. PM → User: Confirmation with summary
```

### Workflow 2: Strategic Planning

```
1. User → PM: "Evaluate expansion strategy"
2. PM → Phoenix (subagent): Strategic analysis
3. Phoenix:
   - Research and analysis
   - Competitive landscape review
   - Recommendation document
4. Phoenix → PM: Strategic brief
5. PM → User: Synthesized recommendations with next steps
```

### Workflow 3: Medical Information Query

```
1. User → PM: Medical question
2. PM → Iris Med (subagent): Clinical analysis
3. Iris Med:
   - Literature review
   - Evidence synthesis
   - Safety considerations
4. Iris Med → PM: Medical brief
5. PM → User: Information with appropriate disclaimers
```

### Workflow 4: Routine Monitoring

```
1. Heartbeat timer → PM
2. PM → Argus: Check system logs
3. PM → Atlas: Check calendar/email
4. If notable:
   PM → User: Proactive notification
5. Else:
   Silent continuation (HEARTBEAT_OK)
```

## Delegation Patterns

### Decision Tree: When to Delegate

```
PM receives request
│
├─ Complex strategy? → Phoenix (Sonnet)
├─ Technical implementation? → CHAPPiE (Sonnet)
├─ Medical query? → Iris (Sonnet)
├─ Security concern? → Argus (Haiku)
├─ Simple fact-check? → Atlas (Haiku)
├─ Content draft? → Quill (Haiku)
└─ Ambiguous? → PM handles directly or asks user
```

### Delegation Principles

1. **Specialization over generalization:** Route to specialist when domain expertise needed
2. **Model matching:** Sonnet for reasoning, Haiku for pattern-matching
3. **Isolation for focus:** Subagents get clean context without main session noise
4. **Push-based completion:** No polling; results auto-announce
5. **User transparency:** PM informs user when delegating critical tasks

## Model Assignment Strategy

### Claude Sonnet 4.5 (Flagship)

**Agents:** PM, Phoenix, CHAPPiE, Iris  
**Rationale:**
- Complex multi-step reasoning required
- High-stakes decisions (medical, security, code)
- Creative problem-solving
- Long-form synthesis and analysis
- User-facing coordination requiring context awareness

**Cost-benefit:** Higher cost justified by quality requirements

### Claude Haiku (Efficient)

**Agents:** Atlas, Argus, Quill  
**Rationale:**
- Rule-based or pattern-matching tasks
- Simple CRUD operations
- Fast response time preferred
- High-frequency/low-complexity queries
- Cost optimization for routine tasks

**Cost-benefit:** 10-20x cheaper, sufficient for deterministic work

## Escalation Rules

### Auto-Escalation Triggers

1. **Ambiguity:** Agent uncertain about intent → Escalate to PM or user
2. **Safety:** Potential data loss, destructive operation → Require confirmation
3. **Privacy:** Personal data handling unclear → Ask before proceeding
4. **Authority:** Decision outside agent's scope → Escalate to PM
5. **Failure:** Task failed after retry → Report to PM with diagnostics

### Escalation Path

```
Specialized Agent → PM → User
     (Haiku)      (Sonnet)  (Human)
```

**Principle:** Agents never guess on high-stakes decisions. Ask > assume.

## Key Integrations

### 1. Google Workspace (via mcporter)

**Purpose:** Email and calendar management  
**Agents using:** PM, Atlas  
**Capabilities:**
- Email monitoring and triage
- Calendar event checking
- Draft email composition (Quill → PM → send)
- Document access (read-only recommended)

**Security:** OAuth tokens stored securely, read scopes preferred

### 2. GitHub

**Purpose:** Code and project management  
**Agents using:** CHAPPiE (primary), Phoenix, PM  
**Access Model:** Individual SSH keys per agent for security and audit trail

**Agent-specific usage:**
- **CHAPPiE:** Primary technical implementation (`chappie_github` SSH key)
  - Code development and modifications
  - Repository management
  - Technical documentation
- **Phoenix:** Public-facing content (individual SSH key)
  - Landing pages and public sites
  - Marketing and strategic content
  - Public documentation

**Capabilities:**
- Clone, commit, push repositories
- Issue creation and management
- Pull request operations
- Branch management

**Security:** Each agent has dedicated SSH keys for isolation and accountability

### 3. WhatsApp Groups

**Purpose:** Team collaboration and coordination  
**Agents using:** PM, CHAPPiE, Iris (context-dependent)  
**Capabilities:**
- Group message participation
- File sharing
- Selective responses (not reactive to every message)

**Privacy:** No logging of other participants' messages, generic references only

### 4. Telegram

**Purpose:** Primary user interface  
**Agents using:** All agents (via PM coordination)  
**Capabilities:**
- Rich message formatting
- Inline keyboards for confirmations
- Reactions (emoji) for lightweight acknowledgment
- Direct and group chat modes

**Pattern:** PM as primary interface, other agents via subagent delegation

## Security & Privacy Principles

### Data Handling

1. **No PII/PHI in logs:** Patient identifiers, phone numbers, emails redacted
2. **Generic placeholders:** "Patient A," "Company X," "Group Y"
3. **Credential isolation:** Tokens in secure storage, never in code/docs
4. **Path sanitization:** Use `~/` or relative paths, not absolute system paths

### Agent Boundaries

1. **Least privilege:** Agents access only what they need
2. **Confirmation for destructive ops:** `trash` over `rm`, ask before delete
3. **No cross-context leaking:** MEMORY.md only loaded in private sessions
4. **Group chat discretion:** Don't share private user data in public channels

### Audit Trail

1. **Daily logs:** `memory/YYYY-MM-DD.md` for each agent
2. **Git history:** All code changes tracked with meaningful commits
3. **Escalation logging:** High-stakes decisions recorded

## Operational Patterns

### Heartbeat System (Proactive Monitoring)

**Agent:** PM (can delegate to Atlas/Argus)  
**Frequency:** ~30 minutes  
**Checks:**
- Email inbox (urgent messages)
- Calendar (upcoming events <24h)
- System health (if applicable)
- Pending tasks

**Response:**
- `HEARTBEAT_OK` if nothing notable
- Proactive message if attention needed
- Batch updates to avoid notification spam

**Quiet hours:** 23:00-08:00 local time (urgent only)

### Memory Management

**Per-agent workspace:** `~/.openclaw/workspace-{agent}/`  
**Daily logs:** `memory/YYYY-MM-DD.md`  
**Long-term memory:** `MEMORY.md` (main session only)  
**Maintenance:** Periodic review and consolidation during heartbeats

### Cron vs. Heartbeat Decision

- **Cron:** Exact timing, isolated execution, specific scheduled tasks
- **Heartbeat:** Flexible timing, batch checks, conversational context needed

## Best Practices

### For Agent Developers

1. **Read AGENTS.md first:** Understand identity and constraints
2. **Document in TOOLS.md:** Keep environment-specific notes
3. **Write things down:** No "mental notes" – files are memory
4. **Commit often:** Small, meaningful commits with clear messages
5. **Respect quiet time:** Don't spam users at night

### For Users

1. **Direct delegation:** Specify agent if you have preference ("CHAPPiE, update X")
2. **Trust the routing:** PM will delegate appropriately if not specified
3. **Override freely:** "No, I want Sonnet for this" is always valid
4. **Feedback loop:** Tell agents when routing was wrong – they learn

### For Multi-Agent Coordination

1. **Push > Poll:** Wait for auto-announcements, don't poll status
2. **Clean context:** Subagents get focused context, not full history
3. **Single responsibility:** One subagent, one task
4. **Report back clearly:** Final message should summarize for parent

## Limitations & Future Work

### Current Limitations

1. **No agent-to-agent direct messaging:** All via PM coordination
2. **Manual model selection:** No automatic Sonnet↔Haiku switching mid-task
3. **Limited memory sharing:** Agents don't share context automatically
4. **No recursive subagent spawning:** Subagents can't spawn sub-subagents

### Future Enhancements

- **Dynamic model switching:** Start with Haiku, escalate to Sonnet if needed
- **Shared knowledge base:** Common memory layer for all agents
- **Agent-to-agent communication:** Direct delegation without PM middleman
- **Learning from interactions:** Improve routing based on past success/failure

## Conclusion

This multi-agent architecture demonstrates how specialized AI agents can collaborate effectively while maintaining security, privacy, and user control. The combination of Sonnet (reasoning-heavy) and Haiku (efficiency-focused) agents provides a balanced approach to cost and capability.

**Key success factors:**
- Clear agent specialization
- Thoughtful model selection
- User transparency and control
- Strong privacy boundaries
- Push-based coordination (no polling)

---

**Questions or contributions?** This is a living document. Feedback welcome via GitHub issues.

**License:** CC BY 4.0 (share freely, attribute source)

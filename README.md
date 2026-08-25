# Vera-Agent

> **Autonomous engineering agent package for [OpenCode](https://opencode.ai) — model-agnostic, self-learning, security-aware.**
>
> 🇹🇷 Türkçe: [README.tr.md](README.tr.md) · 🇩🇪 Deutsch: [README.de.md](README.de.md)
> ⚖️ Licensing: [LICENSE](LICENSE) · [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)

**Vera** is a custom primary agent for OpenCode that behaves the same on any model — from
9B local models in LM Studio or Ollama to frontier APIs. Discipline comes from mechanical
decision trees and mandatory checklists, not from model intelligence. It ships with a
three-layer learning system, a full model manager, and an optional 141-skill arsenal.

---

## ✨ Features

### 🧠 The Agent Brain (`agent/vera-agent.md`)
- **STEP 0 orientation** — every task starts with: memory lookup → playbook read → skill scan → dependency pulse
- **Mechanical decision trees** — skill selection and tool usage as IF/THEN rules, no vibes
- **Mandatory verification checklist** — build, lint, tests, visual checks; "done" without evidence is failure
- **Model adaptivity** — weak models lean harder on checklists, strong models get freedom; discipline unchanged
- **Security instincts** — secrets are radioactive; unprompted vulnerability flagging; authorized-targets-only pentesting
- **Self-development system** — user corrections become permanent artifacts, post-mortems after failures, self-critique gate before delivery

### 📚 Three-Layer Learning System
| Layer | What it learns | Where |
|---|---|---|
| **ACE Playbook** (`.vera/playbook.md`) | Project strategies with `helpful/harmful` counters, delta-only updates (ICLR 2026 method) | per project |
| **Memory MCP** (knowledge graph) | Durable facts about you and your environments | global |
| **Skill evolution** (`skill-evolver` + GEPA loop plugin*) | Domain procedures refined from failure traces | global |

*\* optional extra during install*

### 🎛️ Model Manager (`vera-models.sh` + `/vera-models` command)
- **Mandatory install step** with three doors: automatic / manual wizard / skip-with-reminder
- Provider discovery: **LM Studio**, **Ollama**, any config provider, all opencode-authenticated providers (validation runs through `opencode run`, so every API dialect works)
- **Full role matrix**: assign models to Vera, small_model, explore, librarian, oracle, frontend-engineer, …
- Smoke-test validation loop — a failing role is re-selected until it passes (240 s cold-load timeout)
- Context-length comparison against role requirements (local-model lifesaver)
- Single-endpoint guard: everything on one local server → background concurrency auto-lowered
- Profiles: `free-local`, `hybrid`, `premium`, custom — API keys never stored in profiles
- `--doctor` (full health exam + rollback suggestion), `--status`, `--rollback`, `--dry-run`
- Optional **night shift**: 02:00 light profile ↔ 08:00 day profile (systemd timers, quota saver)

### 🛡️ Safety
- Permission shield: destructive commands denied, sudo/force-push ask, rest allowed
- Untrusted code runs inside OpenSandbox containers — never on host
- Pentest/redteam skills activate only for authorized targets

### ⚔️ Full Arsenal (optional, bundled — 141 skills)
Security chain (~48), language/framework experts (~25), AI/NLP + RAG, Figma→UI,
Playwright testing, OSINT research set, `karpathy-guidelines` discipline, and more.
Installer asks: activate now → all live; decline → stored inertly in a reserve folder,
one command (`enable-arsenal.sh`) enables them later.

---

## 🚀 Installation

### 🖥️ Method A — Manual (terminal)

```bash
git clone https://github.com/adlerasi/getvera.git
cd getvera
bash getvera.sh                            # interactive wizard: extras + arsenal + model assignments
bash getvera.sh --all --with-opensandbox   # or fully automatic: everything, zero questions
```

Restart opencode → press **Tab** → select **vera-agent** → give it a goal.
Requirements: Linux/macOS (Windows → WSL2), Node.js 18+.
Full guide & troubleshooting: [KURULUM.md](KURULUM.md) · flags: `bash getvera.sh --help`

### 🤖 Method B — From within opencode (agent-assisted)

No terminal gymnastics needed. Open opencode anywhere and paste this to your current agent:

> Install https://github.com/adlerasi/getvera for me: clone it into ~/getvera,
> run `bash getvera.sh` and go through its questions together with me,
> afterwards run `vera-models.sh --doctor` and help me assign models per role.

Your running agent does the cloning and installation *with* you; Vera's model manager
finishes the setup. Works from any harness (opencode, Claude Code, Cursor, …).

### 📦 Alternative: release tarball

Grab `verapack.tar.gz` from [Releases](https://github.com/adlerasi/getvera/releases)
and follow Method A starting at the `tar xzf` step.


## ✅ Verify

```bash
ls ~/.config/opencode/agent/vera-agent.md ~/.agents/skills/ace-playbook/SKILL.md
bash ~/.config/opencode/vera-models.sh --status
```

Start opencode → press **Tab** → select **vera-agent** → give it a goal.
Magic triggers inside sessions: *"remember this"*, *"ulw:"* style delegation, night-shift reports in memory.

## 🗑️ Uninstall

```bash
bash uninstall.sh   # removes Vera components; your own providers/plugins stay intact
```

## ⚖️ License & Notices

This is an **individual, non-commercial project**. Own code/docs: MIT ([LICENSE](LICENSE)).
The bundled `arsenal/` skills belong to their original authors — full source/license
mapping in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md), which also lists the few
unlicensed items included for personal use only (removable at any time).

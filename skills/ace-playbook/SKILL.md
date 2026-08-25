---
name: ace-playbook
description: "Maintains per-project evolving playbooks using ACE (Agentic Context Engineering) methodology: itemized strategy bullets with helpful/harmful counters, delta-only updates to prevent context collapse, and grow-and-refine pruning. Use when starting work in any project (read playbook first), after completing tasks (reflector pass), or when user mentions 'playbook', 'lessons learned', or 'project learnings'. Based on ICLR 2026 ACE paper."
---

# ACE Playbook System

You maintain an **evolving playbook** per project — a structured memory of strategies that learns at the bullet level, not the file level. This implements the ACE framework (ICLR 2026): incremental delta updates prevent context collapse; helpful/harmful counters make learning measurable.

## File Location & Format

One playbook per project root: `<project-root>/.vera/playbook.md`

```markdown
# Vera Playbook — <project-name>

## STRATEGIES & INSIGHTS
[str-00001] helpful=5 harmful=0 :: Always run typecheck before tests; tsc catches 80% of failures faster here.

## MISTAKES TO AVOID
[mis-00002] helpful=3 harmful=1 :: Do NOT run test suites in parallel — they share one SQLite fixture DB.

## TOOLS & PATTERNS
[too-00003] helpful=2 harmful=0 :: This repo uses pnpm, never npm. Lockfile: pnpm-lock.yaml.

## PROJECT FACTS
[fct-00004] helpful=0 harmful=0 :: Postgres runs on port 5433 (not default 5432).
```

Bullet anatomy: `[section-prefix-NNNNN] helpful=N harmful=M :: specific, actionable advice`

Section prefixes: `str` (strategies), `mis` (mistakes), `too` (tools/patterns), `fct` (facts). IDs are global-incrementing across sections, never reused.

## The Three Laws (mechanical — no judgment)

### LAW 1 — DELTA ONLY
Never rewrite the whole playbook. Updates are localized edits only:
- Append new bullets (next free ID)
- Increment counters on existing bullets
- Prune a bullet ONLY under Law 3 conditions
A full-file rewrite that drops any surviving bullet is a critical failure (context collapse).

### LAW 2 — REFLECTOR PASS AFTER EVERY COMPLETED TASK
After finishing any non-trivial task, run this exact sequence:
1. Re-read playbook.
2. For each bullet you (consciously or not) followed: did it help or mislead? → `+1` to `helpful` or `harmful`.
3. Did the task reveal a NEW reusable lesson (took >2 attempts, surprised you, cost rework)? → append ONE new bullet. Specificity beats abstraction: "run `pnpm test --filter auth` first" > "test early".
4. No changes needed? → leave file untouched. Zero-diff passes are valid and common.

### LAW 3 — GROW-AND-REFINE (triggered, not scheduled)
Run pruning ONLY when a section exceeds 20 bullets OR total file exceeds 300 lines:
- Merge near-duplicate bullets into the older ID (sum their counters).
- Delete bullets with `harmful >= 3 AND helpful == 0`.
- Demote-to-fact: stale strategy that became permanent truth → move to PROJECT FACTS.
Log nothing — pruning is silent maintenance.

## Scope Boundary — Playbook vs Memory MCP vs Skills

| Artifact | Holds | Lifetime |
|---|---|---|
| `.vera/playbook.md` | Project-specific strategies, pitfalls, patterns | Per project |
| memory MCP (knowledge graph) | Cross-project durable facts about user/environment | Global |
| skills (`~/.agents/skills/`) | General domain procedures | Global |

When a playbook bullet proves true across ≥3 different projects → promote it: propose distilling into a global skill via skill-evolver. When memory holds something project-specific → move it into the playbook as a fact bullet.

## Quality Bar for New Bullets

A bullet earns its ID only if it is:
- **Evidence-backed**: derived from something that actually happened this session (a failure, a surprise, a repeated action)
- **Actionable**: a future session could act on it without asking questions
- **Specific**: concrete commands/paths/numbers preferred over principles
Reject vague lessons ("be careful with types") — they are noise that dilutes counters.

## Anti-Patterns

- ❌ Rewriting the playbook wholesale after each task
- ❌ Appending bullets for routine successes (counter-inflation makes signals meaningless)
- ❌ Deleting a harmful-but-high-helpful bullet (mixed signal = keep, it's informative)
- ❌ Storing cross-project facts here instead of memory MCP
- ❌ Creating a playbook for throwaway/one-session projects

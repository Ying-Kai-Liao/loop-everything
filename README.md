# loop-everything

A Claude Code skill that makes a repo **build itself**: it installs an
autonomous, self-waking build-loop system — a markdown loop registry that
agents work one verified unit at a time, a cron-woken GitHub Actions
runner, and the guardrails that make unattended agent work safe.

Consolidated from a loop system that has been running autonomously on a
production monorepo since 2026-07-15. The incident-derived rules
(untrusted completion checks, scope self-checks, fix-pass caps, handoff
protocol) are kept with their "why".

## What you get

- **Loop registry** (`loops/README.md`) — ordered table of work units,
  each with a gate, dependencies, verifier level, and status.
- **Human-only stage gates** (`GATES.md`) — loops read them, never write
  them; business decisions stay human.
- **Verifier ladder L0–L3** — compiles → tests-in-CI → hermetic behavior
  harness → prod smoke. "Done" requires evidence at the declared level.
- **Two-tier memory** — per-wake journal + promoted lessons file; the
  repo is the agent's memory, no conversation history needed.
- **Self-waking cloud runner** — a GitHub Actions workflow that snapshots
  PR/check state, runs one agent wake, then re-verifies the agent's
  claimed outcome against real GitHub state and fails the run on a lie.
- **Merge-on-green companion workflow** — green loop PRs merge between
  wakes; CI blind-spot paths get an extra status guard.
- **Steering protocol** — GitHub issues labeled `loop`, ack/waiting
  labels, safe-default questions, kill switch via one repo variable.

## Install

```bash
git clone https://github.com/Ying-Kai-Liao/loop-everything ~/.claude/skills/loop-everything
```

Then in any repo, tell Claude Code: **"install the loop system"** (or
"make this repo loop"). The skill walks the bootstrap: gather repo facts
→ scaffold `loops/` from `templates/` → seed verifier-first foundation
loops → labels, workflows, secrets (`claude setup-token` →
`CLAUDE_CODE_OAUTH_TOKEN`), kill-switch variable → first manual crank.

## Layout

```
SKILL.md                      # the skill: ten laws, bootstrap, ops
templates/
  loops/                      # registry, gates, verifiers, notes, spec + runner prompts
  workflows/                  # loop-runner.yml, loop-merge-green.yml
```

Every `{{PLACEHOLDER}}` token in `templates/` gets filled per-repo during
bootstrap; GitHub's own `${{ ... }}` expressions are left alone.

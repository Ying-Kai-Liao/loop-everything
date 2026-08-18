# loop-everything v2 — hub-and-spoke, ticket-first

**Date:** 2026-08-18
**Status:** Proposed (design). Nina is the first consumer.
**Goal in one line:** the manager files tickets in any repo and is
interrupted **only** when a decision, a credential, or an inspection is
genuinely theirs to make. Everything else — ack, plan, build, verify,
merge, deploy — is the loop's job, and the machinery is shared by every
repo, not copied into it.

---

## 1. Why v1 stops scaling

v1 (this repo, 2026-07-24) is a **copy-template installer**: it stamps
`loops/` + two workflows into a repo and walks away. Measured against the
Nina system it was consolidated from, 3½ weeks later:

| v1 template lacks (Nina has it) | why it exists |
|---|---|
| Parallel lanes + lane-claim protocol | night throughput |
| Stop hook (sentinel enforcement) + turn meter | wakes died at the cap with nothing pushed (#439, #540) |
| Model policy: Sonnet main loop, `smart` (Opus) for the hard 20% | cost / quality split |
| Fix-pass count + discard protocol state (`.loop/fixpasses-N`) | "one fix pass then discard" was un-enforceable without it |
| Network rule (no WebFetch → `loop-waiting`, don't ship degraded fallback) | silent degraded work |
| Self-hosted runner + `runner.temp` pnpm dest, `RUNNER_LOOP` valve | ~$65/mo → ~$4/mo Actions spend |
| Cost knobs (`LOOP_NIGHT_LANES`, cron as billing lever) | 2026-08-17 audit |
| `Driven-by:` provenance, `runner: SKIP` staleness, ~15 promoted lessons | cross-venue collisions |

Every repo installed from v1 forks at install time and never receives
any of that. **Drift is structural, not accidental** — the same failure
mode Nina's own product spec forbids ("per-tenant capability is data,
never per-tenant code"). v2 applies that rule to the loop itself.

Two more inefficiencies show up in Nina's journal, and both are places
where the *agent* is doing work the *harness* should do:

1. **Intake latency.** A ticket waits for the next scheduled wake to be
   acked (up to ~5h; NOTES: "issue intake is the bottleneck… eighteen sat
   un-acked for 5 days"). Un-acked issues are never eligible, so a wake
   that ships code but skips §B freezes the queue.
2. **Idle lanes.** Of the recent night-lane journal entries, six are
   `lane-N noop / recon: no eligible unit`. Lanes ≥1 spend real turns
   scanning issues, reading claim comments, and often find nothing —
   because lane count is a cron constant, and work assignment happens
   inside the model.

---

## 2. Design principles

1. **Hub owns the machinery, spokes own the facts.** Workflows, prompt,
   hooks, scripts live once in the hub and are versioned. A spoke repo
   carries a ~25-line caller workflow, `loops/loop.yml` (repo facts),
   and its own memory (`NOTES.md`, `journal/`). Improvements ship to
   every repo on a tag bump.
2. **Tickets are the queue.** Issues labeled `loop` are the primary work
   source. The registry (`loops/README.md`) becomes *optional* — a repo
   with a roadmap keeps one; a repo that is "just tickets" doesn't.
3. **The harness decides, the agent builds.** Eligibility, lane
   assignment, claims, check-state snapshots, sentinel verification —
   deterministic shell with the workflow token. The model receives "your
   unit is #N" and its context budget goes into the diff.
4. **Demand-driven, heartbeat-backed.** Wakes fire on events (an issue
   becomes eligible, a PR goes green/red) with a slow cron backstop —
   not the other way round.
5. **Interrupt budget.** The human sees exactly three signals, all
   @mentioned: `loop-waiting` (question, with a default that will be
   taken), `loop-needs-human` (blocked: credential / network / decision
   / inspection), `loop-ops` (the harness itself failed). Nothing else
   pings.
6. **Every v1 law survives.** Untrusted completion, one-fix-pass-then-
   discard, scope self-check, handoff drafts, explicit staging, gates
   human-only, loops never deploy — unchanged, just relocated to the
   hub.

---

## 3. Architecture

```
loop-everything (hub, public, tagged v2.x)
├── .github/workflows/
│   ├── loop-runner.yml         # reusable (workflow_call): plan → assign → iterate[lanes] → verify
│   ├── loop-intake.yml         # reusable: on issue labeled `loop` → ack/plan/questions in minutes
│   ├── loop-merge-green.yml    # reusable: merge green [loop] PRs, blind-spot guards from loop.yml
│   ├── loop-digest.yml         # reusable: daily/weekly "shipped / stuck / needs you"
│   └── hub-smoke.yml           # hub CI: lints scripts, runs runner against fixtures/
├── runner/
│   ├── wake.md                 # THE prompt (generic). Reads loops/loop.yml + NOTES.md at run time
│   ├── intake.md               # small-model ack prompt (read-only + comment)
│   ├── digest.md               # report prompt (generalised repo-report)
│   ├── claude-settings.json    # Stop sentinel hook + turn meter
│   └── hooks/{stop-sentinel,turn-meter}.sh
├── scripts/
│   ├── snapshot-state.sh       # open loop PRs + required-check state + fixpass counts → .loop/state.json
│   ├── pick-units.sh           # eligible units → lane assignment + claim comments (deterministic)
│   ├── verify-sentinel.sh      # untrusted completion check
│   ├── merge-green.sh          # merge rule + blind-spot statuses
│   └── bootstrap.sh            # labels, variables, secrets, issue template, (optional) runner registration
├── schema/loop.schema.json     # validates loops/loop.yml
├── templates/                  # spoke files: caller workflows, loop.yml, NOTES.md, issue template
└── SKILL.md                    # install/operate skill (thin: runs bootstrap.sh, explains loop.yml)

<any repo> (spoke)
├── .github/workflows/loop.yml          # ~25 lines: triggers + `uses: …/loop-runner.yml@v2` + secrets: inherit
├── .github/workflows/loop-merge.yml    # ~10 lines → hub reusable
├── .github/ISSUE_TEMPLATE/loop-task.md # auto-labels `loop`; Context / Direction / Done-when / Don't
├── loops/loop.yml                      # repo facts (the only per-repo config)
├── loops/NOTES.md, loops/journal/      # per-repo memory (unchanged from v1)
└── loops/README.md, GATES.md           # optional (roadmap-style repos only)
```

### 3.1 The spoke caller (all a repo needs)

```yaml
# .github/workflows/loop.yml
name: loop
on:
  schedule: [{ cron: "17 */6 * * *" }]        # heartbeat only — bookkeeping + backstop
  issues: { types: [labeled] }                 # `loop-ack` added by intake → a unit is eligible
  workflow_run: { workflows: [CI], types: [completed] }   # red PR → fix pass; green → merge (via merge-green)
  workflow_dispatch: { inputs: { lanes: { default: "1" } } }
concurrency: { group: loop-runner, cancel-in-progress: false }   # coalesces bursts: 1 running + 1 pending
permissions: { contents: write, pull-requests: write, issues: write, actions: read, checks: read, id-token: write }
jobs:
  loop:
    if: ${{ vars.LOOP_RUNNER_ENABLED != 'false' && (github.event_name != 'issues' || github.event.label.name == 'loop-ack') }}
    uses: Ying-Kai-Liao/loop-everything/.github/workflows/loop-runner.yml@v2
    with: { lanes: ${{ inputs.lanes || vars.LOOP_LANES || '2' }} }
    secrets: inherit
```

`concurrency` with `cancel-in-progress: false` gives free coalescing:
GitHub keeps one running and at most one pending run per group, so a
burst of five ticket acks yields two wakes, not five.

### 3.2 `loops/loop.yml` — repo facts, schema-validated

```yaml
version: 2
human: "@Ying-Kai-Liao"                 # @mentions notify; labels don't
required_check: validate                # branch-protection check the harness snapshots
branch_prefix: loop/                    # push scope for the agent token
model: claude-sonnet-4-6
max_turns: 150
lanes: { default: 2, max: 4 }
verify:                                 # the verifier ladder, concretely
  L0: "pnpm --filter @nina/shared build && pnpm --filter @nina/db build"
  L1: "pnpm --filter <pkg> test"
  L2: "pnpm --filter nina test:harness"
serial_paths:                           # two open PRs touching these conflict → lane 0 only, one at a time
  - packages/db/drizzle/**
  - worker/bot-template/VERSION
blind_spots:                            # CI passes but doesn't prove it → extra status required to merge
  - paths: ["web/**"]
    require_status: "vercel"
invariants:                             # prompt-injected "must not break" list, with the why (one line each)
  - "Any change under worker/bot-template/** bumps worker/bot-template/VERSION (rollout keys on it; #187)"
  - "After schema.ts changes run pnpm db:generate and commit .sql + meta/ + _journal.json together (#259)"
network: none                           # none | github | open — `none` routes web-needing units to loop-needs-human
escalation: { agent: smart, label: opus }   # optional Opus tag-in agent + forcing label
allowed_tools_extra: ["Bash(pnpm db:generate)"]
registry: loops/README.md               # optional; omit for ticket-only repos
```

Everything that made the Nina prompt un-portable — `@Ying-Kai-Liao`,
`pnpm`, VERSION bumps, Drizzle rules, `web/`+Vercel — is data here. The
hub prompt says *"apply the invariants and serial-path rules from
`loops/loop.yml`"* instead of naming any of them.

### 3.3 One wake, v2 (harness ↔ agent split)

```
plan (hosted, ~20s shell, hub scripts)
  snapshot-state.sh   → .loop/state.json  (open loop PRs, required-check state, fixpass counts, drafts)
  pick-units.sh       → .loop/plan.json:
                          bookkeeping[]  = red PRs (fix/discard), draft PRs (resume), stale claims
                          eligible[]     = issues loop+loop-ack, not loop-waiting, not claimed, not in an open PR,
                                           dependencies closed, serial-path units only for lane 0
                          lanes          = min(requested, |bookkeeping|>0 ? 1 : 0 + |eligible|)   ← never spawn an idle lane
                          assignment     = lane k → unit; claim comment "runner: lane k <run-url>" posted NOW
iterate[k] (self-hosted or hosted, matrix from plan)
  checkout spoke; checkout hub@ref into .loop/hub/
  claude-code-action  prompt = .loop/hub/runner/wake.md ; settings/hook paths under .loop/hub/
                      "You are lane k. Your unit is <#N | resume PR #M | fix pass PR #M>. Do not pick anything else."
  verify-sentinel.sh  (untrusted completion — unchanged)
  release claim if the wake ended NOOP/BLOCKED without a PR
```

Consequences:
- Lanes ≥1 no longer scan, claim, or NOOP; the model's turns go to the
  diff. Idle-lane wakes disappear by construction.
- The "Parallel lanes" section of the prompt (~60 lines of protocol the
  model had to obey) is deleted; the harness enforces it.
- Interactive-session claims (`runner: SKIP`) and staleness stay, read
  by `pick-units.sh` instead of the model.

### 3.4 Intake in minutes, not hours

`loop-intake.yml` triggers on `issues: labeled loop`. A **small, cheap,
read-only** agent run (Haiku/Sonnet, ~10 turns, tools: Read/Grep/`gh
issue view`, `gh issue comment`, `gh issue edit --add-label`) does what §B
did inside a wake: reads the issue and repo, comments a plan + verify
level + slice plan (if large), labels `loop-ack` — or asks questions
with a stated default and labels `loop-ack loop-waiting`. The
`loop-ack` label event then triggers a wake (§3.1). Ticket → ack ≤ 5 min;
ticket → branch pushed typically within the hour.

Answering on a `loop-waiting` issue removes nothing automatically; the
next intake run (triggered by `issue_comment` from the human) re-reads,
drops `loop-waiting`, and the wake fires. Unanswered questions take the
stated default after `waiting_grace` wakes (loop.yml, default 2).

### 3.5 The three interrupts, and one board

| label | meaning | who clears it |
|---|---|---|
| `loop-waiting` | a question with a default; answer or let the default stand | intake, on your comment |
| `loop-needs-human` | blocked: secret / network / business decision / "please inspect this before I continue" | you, by commenting; intake re-evaluates |
| `loop-ops` | the harness failed (wake died, secret missing, runner offline) | you |

Every one is @mentioned. Nothing else pings — merges, opens, NOOPs,
digests are silent.

**Cross-repo view:** a **user-level GitHub Project** ("Loop inbox") with
per-repo auto-add filters `label:loop`, three views: *Needs me* (any of
the three labels), *In flight* (open `loop` PRs, drafts = handoffs),
*Shipped this week*. Personal-account projects span repos, so this needs
no org. `bootstrap.sh` adds the repo to the project.

`loop-digest.yml` (generalised from Nina's `repo-report`) writes the
daily/weekly "shipped / stuck / needs you" per repo; a cross-repo digest
is a later hub feature (Phase 4).

### 3.6 Shared compute and shared limits

- **Runner:** the reusable workflow keeps `runs-on: ${{ vars.RUNNER_LOOP
  || 'ubuntu-latest' }}` (caller vars resolve in called workflows).
  Personal-account runners are per-repo, so `bootstrap.sh --runner`
  registers the same box to each spoke with a shared label (`loop`).
  Measured on Nina (2026-08-18): 2 concurrent lanes = 2.8 GB / ~5.4
  cores peak on the M4 — 4 concurrent jobs across all repos fits 16 GB.
- **Global lane cap = number of registered runner instances.** Actions
  `concurrency` is per-repo, but the box is not: N runner processes ⇒ at
  most N lanes across every spoke, which is also the natural cap on the
  shared Claude subscription's rate window. This is the one cross-repo
  coordination mechanism, and it needs no code.
- If the repos later move under an org: org runner groups + org secrets
  replace per-repo registration; nothing in the design changes.

---

## 4. Migration (Nina dogfoods every phase)

| phase | what | done when |
|---|---|---|
| **0 — hub v2** | Port Nina's *current* `loop-runner.yml`, `loop-merge-green.yml`, prompt, hooks into hub as reusable + `runner/`; extract Nina-specific text into `templates/loop.yml`; write `schema/`, `hub-smoke.yml` (fixture repo under `fixtures/`, `act`-free: shell scripts unit-tested with bats + a dispatch smoke against the hub itself). Tag `v2.0.0-rc1`. | hub-smoke green; a Nina wake dispatched via a *branch* caller (`@design/v2…`) succeeds with identical behaviour |
| **1 — Nina spoke** | Replace `.github/workflows/loop-runner.yml` with the caller; keep the old file renamed `loop-runner.legacy.yml` with `if: false` for one week (rollback = rename back). Same for merge-green. | 7 days / ~60 wakes on v2 with sentinel/merge/NOOP shape matching the prior week |
| **2 — harness picks, intake** | `pick-units.sh` assignment + claim; delete "Parallel lanes" from prompt; `loop-intake.yml`; event triggers in caller; three-label interrupt model (`loop-needs-human` added, `BLOCKED` sentinel maps to it). | idle-lane NOOP rate ≈ 0 across a week; median ticket→ack < 10 min |
| **3 — second spoke** | `bootstrap.sh` end-to-end on one more active repo (candidates by recent push: `storm-v2`, `Albert-Bus`, `dudu`); register the runner box to it. | first ticket there → merged PR with no hub or spoke code edits |
| **4 — inbox + digest** | User-level Project + auto-add; `loop-digest.yml` reusable; cross-repo weekly. | you steer two repos from one board for a week |

Rollback at every phase is a rename or a tag pin — the hub is public and
immutable per tag, so a spoke can sit on `@v2.0.0` forever if v2.1 hurts.

---

## 5. Decisions taken here (say so if you disagree)

1. **Reusable workflows over a composite action or a copied template.**
   Composite actions can't own the `plan → matrix → iterate` job graph;
   templates drift (§1). Reusable workflows are the only GitHub primitive
   that centralises a *job graph* while running in the caller's repo,
   with the caller's secrets/vars/runners.
2. **Prompt fetched from the hub at run time, not vendored.** A spoke that
   vendors `wake.md` is v1 again. Pinning by tag gives the same
   reproducibility.
3. **Registry becomes optional; tickets are primary.** Nina keeps its
   registry (roadmap-driven); a small repo is tickets-only. Same prompt.
4. **Harness picks work.** The model never decides *what* to build in a
   wake — only *how*. This is what makes lanes safe without protocol text
   and makes lane count follow demand.
5. **Sentinels stay as the agent's report, and the harness still
   distrusts them.** v2 adds mapping: `BLOCKED` → `loop-needs-human`
   label + @mention on the unit's issue, so a blocked wake is a
   push-notification, not a log line.
6. **No org migration required.** Per-repo runner registration + user
   project is enough for 2–5 repos; the design is org-ready when that
   changes.

## 6. Out of scope (deliberately)

- Cross-repo dependencies between tickets (repo A waits on repo B).
- A web UI. GitHub Projects + issues *are* the UI.
- Replacing `claude-code-action`; the hub wraps it.
- Per-tenant/`gtm` field loops — software loops only, as in v1.

## 7. Open questions for the manager (defaults in bold)

1. Second spoke for Phase 3: **`storm-v2`** (most recent non-Nina push) —
   or name one.
2. Intake model: **Sonnet** (same subscription, ~10 turns) vs Haiku via
   API key. Sonnet unless the OAuth token can't select it.
3. Heartbeat cadence once wakes are event-driven: **every 6h**.
4. Should `loop-needs-human` auto-expire back to eligible after N days
   with a stated default (like `loop-waiting`)? **No** — a blocked unit
   stays blocked until a human speaks; that's the point of the label.

# Loop Registry

<!-- TEMPLATE. The build side of {{PROJECT_NAME}}'s roadmap, engineered as
     loops: each with a goal, a gate, a trigger, an executor, and a
     verifier. -->

- **Cloud runner (self-waking):** [runner/cloud-runner-prompt.md](runner/cloud-runner-prompt.md) — `.github/workflows/loop-runner.yml`
- **Run build loops in-session:** [runner/build-loop-prompt.md](runner/build-loop-prompt.md)
- **Stage gates (human-only):** [GATES.md](GATES.md)
- **Verifier ladder L0–L3:** [VERIFIERS.md](VERIFIERS.md)
- **Loop memory:** [journal/](journal/) (per-wake entries) + [NOTES.md](NOTES.md) (promoted lessons)

## Human interface (autonomous mode)

Direction enters as **GitHub issues labeled `loop`**; discussion happens
in issue comments. The runner acks each issue with a plan (`loop-ack`),
asks questions with a stated default (`loop-waiting`), and treats human
comments as overriding the registry order. Comment on the issue or the
`[loop]` PR any time — the next wake reads it. Kill switch:
`gh variable set LOOP_RUNNER_ENABLED --body false`.

## Build loops (proactive)

Ordering = row order; a loop runs only if its gate is OPEN, its deps are
`done`, and its status is `ready` or `in-progress`.

| # | id | gate | deps | verify | status | source |
|---|----|------|------|--------|--------|--------|
| 1 | [F1-ci-tests](build/F1-ci-tests.md) | G0 | — | L1 | ready | {{SOURCE_DOC}} |
| 2 | [F2-verify-harness](build/F2-verify-harness.md) | G0 | F1 | L2 | ready | {{SOURCE_DOC}} |
<!-- Foundation first (verifiers before features), then feature loops.
     Gated future tracks may appear as index rows only — spec files are
     written when their gate opens (just-in-time rule). -->

## Watch loops (scheduled — laptop-independent)

| id | cadence | executor | status |
|----|---------|----------|--------|
| B0-cloud-runner | {{RUNNER_CRON}} | github-action | active |
| [V1-backlog-audit](watch/V1-backlog-audit.md) | weekly | scheduled-agent | defined |

## Registry rules (autonomous mode)

- `status:` here and in the spec file's front-matter must agree; both
  update **in the same PR as the work** (V1 audits this).
- Build-loop statuses: `gated | ready | in-progress | done`. Watch-loop
  statuses: `defined | active`.
- **The agent's "done" is a claim, not a fact.** Status changes require
  verifier evidence in the same-PR journal entry, and `main` requires the
  green `{{REQUIRED_CHECK}}` check (branch protection) — the runner
  merges its own `[loop]` PRs only when checks pass; a red PR gets one
  fix pass, then is discarded with its learnings journaled.
- Loops never edit GATES.md and never work a CLOSED gate — stage gates
  are the one human-only control (they encode business decisions, not
  code review).
- Issue-driven work (label `loop`) outranks registry row order — human
  direction wins.
- Merged work reaches production through the normal deploy pipeline;
  loops never deploy directly.
- A loop's `source:` doc is the definition of "correct" — if it changes,
  the loop spec must be re-checked (V1 flags this).

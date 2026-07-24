---
name: loop-everything
description: Use when the user wants a repo to build itself — bootstrap or operate an autonomous, self-waking build-loop system (loop registry, human-only stage gates, L0–L3 verifier ladder, journal memory, GitHub Actions cloud runner with untrusted completion checks). Trigger on "make this repo loop", "set up a build loop", "self-building repo", "install the loop system", "loop everything".
---

# Loop-Everything — make a repo build itself

Consolidated from the Behalve/Nina loop system (`Workspace/Nina/loops/`,
design: `docs/superpowers/specs/2026-07-07-gtm-loop-structure-design.md`),
which has been running autonomously since 2026-07-15. This skill installs
the same architecture into any repo: a markdown loop registry that agents
work one unit at a time, a self-waking GitHub Actions runner, and the
guardrails that make unattended agent work safe. For Nina-specific ops,
the `loop-work` skill is the operating manual; this skill is the
generalized installer + reference.

**The system in one sentence:** the repo *is* the agent's memory
(registry + journal + issues + git history); a cron-woken agent reads
state, does ONE verified unit of work, records state, and stops — and
every claim it makes is checked against external evidence by machinery it
cannot influence.

## The ten laws (why it doesn't go off the rails)

1. **"Done" is a claim, not a fact.** Only external evidence counts —
   test output, CI checks, transcripts — pasted into the journal. The
   workflow re-verifies the agent's final sentinel against real GitHub
   state and fails the run on a lie (untrusted completion check).
2. **One wake = one unit of work**, sized to one context window. A
   complete small slice beats a partial big one.
3. **Memory is the repo.** No conversation history: registry
   (`loops/README.md`), per-wake journal (`loops/journal/`), promoted
   lessons (`loops/NOTES.md`, ~100-line cap — a lesson hit twice gets one
   line), issues/PRs, git log. Journal ships in the SAME PR as the work.
4. **Human control = three levers only.** Stage gates (`GATES.md`,
   human-edited only, loops never write it), issue comments (label
   `loop`; human comments override the registry order), and the kill
   switch (`gh variable set LOOP_RUNNER_ENABLED --body false`).
5. **Red PR → one fix pass → discard.** A failing PR gets exactly one
   fix attempt; still red → close it, journal the learnings in a docs
   PR, reset the registry item. Never thrash; two failures on the same
   cause = BLOCKED, not retry #3.
6. **Unpushed work does not exist.** Mid-task stop = push everything
   coherent, mark the PR DRAFT, leave a comment starting `HANDOFF:`
   written for a stranger with zero memory. Any later wake (or human
   session) resumes from it; drafts are never merged.
7. **Stage explicit paths only** — never `git add -A`/`git add .`/
   `commit -a` — and scope-check `git diff --name-status` before every
   push. Any changed path outside the declared scope aborts the wake; a
   stray deletion is an automatic abort (this exact shape once shipped
   the deletion of two unrelated components past green CI).
8. **Verifier ladder, declared per loop** (L0 compiles → L1 tests in CI
   → L2 behavior harness → L3 prod smoke). An iteration below its
   declared level reports FAILED, never done. Claiming a level you
   didn't run is forbidden.
9. **Loops never deploy.** Merged work rides the normal deploy pipeline.
   Loops also never edit gates or `.github/workflows/**`.
10. **The agent's token cannot read checks.** Snapshot check state with
    the *workflow* token into `.loop/state.json` BEFORE the agent runs —
    via REST `check-runs?check_name=...` (GraphQL rollup fails on
    other apps' check suites). A companion workflow merges green loop
    PRs between wakes so nothing strands for hours.

## Anatomy

```
loops/
  README.md        # registry: ordered table — id | gate | deps | verify | status
  GATES.md         # stage gates, human-edited ONLY, opened via dated journal entry
  VERIFIERS.md     # L0–L3 ladder + this repo's concrete commands per level
  NOTES.md         # promoted lessons (read every wake; ~100-line cap)
  journal/         # one file per wake: attempt, evidence verbatim, learnings
  build/<id>.md    # one spec per loop: front-matter (goal/gate/verify/status/stop)
  watch/<id>.md    # scheduled audit loops (registry drift, CI green, prod smoke)
  runner/
    cloud-runner-prompt.md   # the wake procedure (the system's heart)
    build-loop-prompt.md     # in-session /loop variant (user present, per-iteration stop)
.github/workflows/
  loop-runner.yml        # cron wakes → snapshot state → agent → verify sentinel
  loop-merge-green.yml   # merges green non-draft [loop] PRs between wakes
```

Templates for every file are in this skill's `templates/` directory.
Fill every `{{...}}` token; leave GitHub's own `${{ ... }}` expressions
(leading `$`) alone.

## Bootstrap procedure (installing into a repo)

1. **Gather repo facts** (read the repo; ask only what you can't derive):
   - Build + test commands per package, and dependency build order.
   - CI workflow and the branch-protection-required check name
     (`{{REQUIRED_CHECK}}` — conventionally `validate`).
   - Paths CI does NOT fully cover (e.g. a frontend built only by
     Vercel) → these get an extra merge guard in `loop-merge-green.yml`.
   - Repo invariants an agent must not break (version bumps, committed
     migration chains, generated files) → the prompt's Invariants block.
   - Owner's GitHub handle (@mentions notify; labels don't).
   - Project stages, if any, for `GATES.md` (G0 open forever; the rest
     open only by human commit linking a dated decision entry).
2. **Scaffold `loops/`** from `templates/loops/`, filling placeholders.
3. **Seed the registry — verifiers before features.** The first loops
   are always foundation: F1 "CI actually runs tests and fails red"
   (self-proving: a deliberately broken test must fail CI), then F2 "a
   one-command hermetic behavior harness exists" (injected fakes, no DB,
   no keys — CI-safe). Every later loop's evidence depends on these.
   Feature loops come after, gated and dependency-ordered.
4. **Create labels:** `for l in loop loop-ack loop-waiting loop-ops; do
   gh label create "$l"; done`.
5. **Install workflows** from `templates/workflows/`. Then:
   - Secret: `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`;
     `ANTHROPIC_API_KEY` fallback).
   - Variable: `gh variable set LOOP_RUNNER_ENABLED --body true`.
   - Branch protection on main requiring `{{REQUIRED_CHECK}}`.
   - Scope the agent's push permission to `loop/*` branches if the
     token setup allows; the allowedTools list already restricts it.
6. **First crank:** `gh workflow run loop-runner`, read the wake summary
   in the run page. Expect the first wakes to discover sandbox/permission
   gaps — that's the system working; promote each into `NOTES.md`.
7. **Steer by filing issues** labeled `loop`, each with four parts:
   Context / Direction / Definition of done (verifiable, with commands
   and verifier level) / Scope guard ("do NOT..."). Sliced issues
   ("Slice 1/2/3") map 1:1 to runner wakes.

## Operating an installed loop

```bash
gh run list --workflow=loop-runner.yml --limit 10   # wake health
gh issue list --label loop --state open             # backlog / steering
gh issue list --label loop-waiting --state open     # runner asked a question — answer on the issue
gh issue list --label loop-ops --state open         # runner self-reported wake failures
gh pr list --label loop --state open                # in-flight; drafts = handoffs
gh variable set LOOP_RUNNER_ENABLED --body false    # KILL SWITCH
```

- Runner acks issues with `loop-ack` + a plan; ambiguity → question with
  a stated default + `loop-waiting` (it proceeds with the default on a
  later wake if you don't reply — safe-default, never stalls).
- **Interactive sessions coexist with the runner**: claim an issue/PR by
  commenting `runner: SKIP` (stale after 7 days of no activity); release
  claims when done. PR bodies end `Driven-by: cloud-runner` or
  `Driven-by: interactive-session` for provenance. Handoffs are
  symmetric — you may pick up the runner's draft PRs from their
  `HANDOFF:` comment, and leave it your own.
- Day-2 watch loops (from `templates/loops/watch-*.md`): weekly
  registry-drift audit (statuses agree, no gate violations, stuck >14d,
  source-doc drift), daily CI-green/prod-smoke. Report-only; they open
  drift issues, never fix.

## Venue choice

| | Cloud runner | In-session `/loop` | Agent fleet |
|---|---|---|---|
| When | user absent; backlog grind | user present, wants per-iteration review | many independent issues, user steering |
| Trigger | cron (e.g. `17 */5 * * *`) | paste `runner/build-loop-prompt.md` | one Agent per issue, worktree isolation |
| Merge | self-merges on green check | stops and reports each iteration | human reviews every diff |

Same registry, same journal, same rules — the registry doesn't care who
turns the crank.

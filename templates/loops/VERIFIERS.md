# Verifier Ladder — L0–L3

<!-- TEMPLATE. Fill the concrete commands for this repo. The ladder shape
     is fixed; the recipes are per-repo. -->

Every loop declares a minimum level in its `verify:` front-matter field.
An iteration that has not cleared its declared level reports **FAILED**,
never "done". Iteration reports end with verifier **evidence** (test
output, harness transcript, CI link) — claims without evidence don't
count.

## L0 — it compiles

Build the touched packages, in dependency order:

```bash
{{L0_COMMANDS}}
# e.g.  pnpm --filter @scope/shared build   # first — others depend on it
#       pnpm --filter <touched-service> build
```

Pass = exit 0 on all touched packages.

## L1 — logic is right

Unit tests for the changed behavior, green locally AND executed in CI:

```bash
{{L1_COMMANDS}}
# e.g.  pnpm --filter <package> test
```

Pass = new tests exist for the change, all tests green, and CI runs them
on the PR (this is what the F1 foundation loop makes true). An L1 claim
is backed by the PR's CI run, not just local output — `main` requires
the green `{{REQUIRED_CHECK}}` check.

## L2 — behavior is right

End-to-end behavior drive via the verify harness (built by the F2
foundation loop): a scripted scenario replayed against the **real
application logic in-process**, with assertions on the actual flow.
Design constraints that make it loop-usable:

- Scenarios are **declarative files** (`{ name, seed, steps, assert }`)
  so any loop can add one without touching harness code.
- Substrate is **injected fakes** (deterministic stand-ins for LLMs,
  clocks, external APIs) — a run needs **no DB, no API key, no
  service**: hermetic and CI-safe.
- Each run prints a deterministic transcript, writes it to
  `verify/out/<scenario>.txt`, and **exits 0 iff every assertion
  passed**. The transcript is the evidence artifact; paste it into the
  loop journal.
- The harness **self-proves** via two shipped scenarios: one known-good
  (exits 0) and one deliberately broken (exits 1).

```bash
{{L2_COMMANDS}}
# e.g.  npm run verify:l2 -- <scenario>
#       npm run verify:l2 -- --all
```

## L3 — prod is right

Post-deploy smoke on the test account ({{TEST_ACCOUNT}}). **Deploys are
human-gated — L3 runs only after a human deploy; it never triggers
one.** Minimum smoke: {{L3_SMOKE_STEPS}}
(e.g. login → connect → one real round-trip → the loop's
feature-specific check).

## Levels vs per-loop checks

This file defines the levels. Each loop's spec file lists the concrete
checks it must pass at its declared level. Both must pass. A loop may
declare a composite level (e.g. `L1 + L2 spot-drive`); each named level
must be satisfied.

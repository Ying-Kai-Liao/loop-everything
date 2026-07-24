---
# TEMPLATE — one file per loop under loops/build/ (or loops/watch/).
# Front-matter is the machine-readable contract; the body carries the
# concrete checks. Example values from Nina's F1-ci-tests.
id: F1-ci-tests
goal: >
  ONE falsifiable outcome + what it serves. e.g.: CI runs the unit-test
  suites of every touched package and fails red on a failing test.
  Serves: every later loop's L1 claim — the verifier foundation.
gate: G0                  # from GATES.md; loop may not start while CLOSED
trigger: proactive        # proactive | scheduled <cadence>
executor: github-action   # in-session | scheduled-agent | github-action
verify: L1 (self-proving — see checks)
deps: none                # other loop ids that must be `done` first
source: {{SOURCE_DOC}}    # the doc that defines "correct" for this loop
status: ready             # gated | ready | in-progress | done
stop: >
  Done-condition + halt-conditions. e.g.: Done when all checks pass.
  Halt and report if workflow edits are blocked by repo permissions, or
  if a decision needs a human.
---

# F1 — CI runs tests

## Why

<!-- The evidence this loop exists: the finding, the review, the metric.
     Cite dates and greps, not vibes. -->

## Scope

<!-- What's in, and explicitly what's OUT (YAGNI lines prevent runner
     sprawl — the same job as an issue's scope guard). -->

## Checks (all must pass to report done)

1. <!-- Concrete, falsifiable, with the evidence artifact named.
        e.g.: A PR touching a package runs that package's tests in CI —
        evidence: CI log link. -->
2. <!-- Self-proof where possible: a deliberately broken case must fail
        red — evidence: red run link. -->
3. <!-- Local reproduction command documented. -->

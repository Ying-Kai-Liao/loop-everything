# Build-loop runner — master /loop prompt (in-session venue)

Paste this to start (or resume) the build loop in a Claude Code session.
Runs with the session open (laptop or Claude Code web); it stops and
reports after every loop iteration for your review.

```
/loop Work the loop registry at loops/README.md. Pick the lowest-ordered
loop in the Build loops table whose gate is OPEN in loops/GATES.md,
whose deps are all done, and whose status is ready or in-progress. One
loop iteration: implement the next slice of the loop's goal → verify at
the loop's declared level per loops/VERIFIERS.md and the loop's own
Checks section → update the registry row and the loop spec's status in
the same branch → STOP and report with verifier evidence. Never: open
gates, deploy, edit GATES.md, or start a gated loop. If verification
fails twice on the same cause, halt and report instead of thrashing.
```

<!-- If the repo has a spec-driven workflow (OpenSpec etc.), replace
     "implement the next slice" with its commands, e.g.
     "/opsx:ff (or /opsx:continue) the change named in the loop's
     `openspec:` field → /opsx:apply". -->

## Per-iteration contract

- Branch → commit → PR before any deploy (standing repo rule; the loop
  itself never deploys).
- The registry row and spec-file `status:` update ship in the same PR as
  the work, so the backlog audit can diff reality against the registry.
- The iteration report ends with verifier **evidence** (test output, L2
  transcript, CI link) — not a claim.
- Marking a loop `done` and archiving its spec/change docs are TWO
  steps: the loop proposes `done` with evidence; archival happens on a
  later iteration (or by a human) after the merge proved out.

## Manual mode

No /loop required — run one iteration by hand with the same beats
(implement → verify → update statuses → report). The registry doesn't
care who turns the crank.

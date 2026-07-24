# Stage Gates

**Human-edited only. Loops READ this file; loops NEVER edit it.**

<!-- TEMPLATE. Map gates to the project's real stages (roadmap stages,
     funding milestones, validation checkpoints — whatever "you may now
     build the next tier" means for this project). G0 is permanently
     open; everything else starts CLOSED. -->

A gate opens only by a human commit editing this file, linking a dated
decision entry (e.g. `{{JOURNAL_DIR}}/YYYY-MM-DD-<slug>.md`) that records
why this stage's build work may start — commit-before-outcome
tamper-proofing. Closing a gate again (rollback) works the same way.

| Gate | Stage | State | Opened by (decision entry) | Opens track |
|---|---|---|---|---|
| G0 | Stage 0 — groundwork + verifiers | **OPEN** (permanent) | — | F, V |
| G1 | {{STAGE_1_NAME}} | CLOSED | | B |
| G2 | {{STAGE_2_NAME}} | CLOSED | | S |

## Gate-opening checklist (for the human)

1. Write a dated decision entry stating why this stage's build work may
   start. Commit it.
2. Edit the State cell to OPEN and put the entry filename in "Opened by".
3. For gated future tracks: draft the track's loop spec files in
   `loops/build/` in the same PR (they may not exist before this moment —
   just-in-time rule).
4. Commit. The build loop picks up newly-ready loops on its next wake.

## Rules

- G0 is permanently open; never close it.
- The immediate next stage's track may be pre-specced (spec files exist
  with status `gated`), but no code may exist for it. Later tracks exist
  only as index rows in `loops/README.md` until their gate opens — no
  spec files, no code.
- If a gate is closed while a loop of its track is in-progress, the loop
  halts at its next iteration boundary.

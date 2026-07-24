---
id: V1-backlog-audit
goal: >
  Registry, spec files, and gates never drift apart; stuck or gate-
  violating work is flagged weekly with evidence.
gate: G0
trigger: scheduled weekly
executor: scheduled-agent   # cloud routine (/schedule) or GitHub Action
verify: report-only
deps: none
status: defined             # defined | active — activation is an explicit human action
---

# V1 — backlog audit (the loop that watches the loops)

Report-only: change nothing. Open/refresh a GitHub issue titled
"loop-registry drift <date>" when drift is found.

## Checks (all five sections, each with evidence)

1. **Status agreement** — registry table vs each spec file's
   front-matter `status:`.
2. **Gate violations** — code, branches, or spec files existing for a
   track whose gate is CLOSED in `loops/GATES.md`.
3. **Stuck loops** — `in-progress` with no commits >14 days.
4. **Done-but-unarchived** — loops marked done whose spec/change docs
   were never archived on a later wake.
5. **Source drift** — a loop's `source:` doc modified more recently than
   the loop spec (the source defines "correct"; the spec must be
   re-checked).
6. **Schedule drift** — documented cadences vs actual workflow/routine
   definitions.

## Activation prompt (for /schedule or a cloud routine)

```
Run the V1-backlog-audit watch loop per loops/watch/V1-backlog-audit.md:
check status agreement (registry vs spec front-matter), gate violations,
stuck loops (in-progress, no commits >14 days), done-but-unarchived
changes, and source drift. Report all sections with evidence.
Report-only: change nothing. If drift is found, open/refresh a GitHub
issue titled "loop-registry drift <date>".
```

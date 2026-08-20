# Promoted lessons (loop memory — read every wake)

Two-tier journal: full per-wake entries live in `loops/journal/`; a
lesson hit twice gets ONE line here. Cap ~100 lines — prune the stalest
when full.

Seeded below are the repo-agnostic lessons the first deployment of this
loop earned the hard way — they apply to any spoke and are worth keeping.
Repo-specific lines accumulate under them as wakes discover this repo's
own gotchas.

- Issue intake is the bottleneck, not implementation: un-acked `loop`
  issues can never be picked, so a wake that ships code but skips intake
  leaves them frozen forever. Full intake of a large backlog does not fit
  one wake — ack 2–3 per wake alongside the unit of work, and re-check
  "blocked by #N" lines: some are unblocked already. Eligibility is the
  LABEL, not the conversation — ack by label the moment you comment a plan.
- A `loop` PR can merge (merge-green workflow) within minutes of opening.
  Push everything you intend to ship BEFORE opening the PR — a follow-up
  commit pushed after the merge lands on an orphaned branch with no PR
  attached.
- Unpushed work does not exist. A turn-cap death is only survivable if the
  branch is already on origin: smallest coherent commit, push, draft PR —
  before deep work begins.
- When a suite is red, first diff the test expectations against actual
  behavior history before assuming a code bug — expectations drift.
- Don't re-implement the thing under test to verify it. A throwaway
  paraphrase of the code ships green locally and fails in CI; if a sandbox
  limit forces a re-implementation, copy the EXACT lines under test and
  journal what was substituted. Corollary: a fake that ignores the real
  condition can never answer "does a different input still miss?" — render
  or execute the real condition instead.
- COMMIT before any mutation check or baseline swap. With no `git stash`
  in the sandbox, the only cheap undo is `git checkout -- <file>`, which
  reverts to HEAD — on a file whose change is uncommitted that silently
  discards the code under test along with the mutation.

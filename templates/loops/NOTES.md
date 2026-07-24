# Promoted lessons (loop memory — read every wake)

Two-tier journal: full per-wake entries live in `loops/journal/`; a
lesson hit twice gets ONE line here. Cap ~100 lines — prune the stalest
when full.

<!-- Starts empty. Seed lines appear as the first wakes discover this
     repo's gotchas. Nina's earned lines, for calibration of what belongs
     here (one line, cause → rule):
     - "pnpm build order matters: shared → db → services; vitest resolves
       workspace imports to dist/, so build before test."
     - "Cloud runner sandbox blocks shell rm/mv/cp/redirects even inside
       the repo — use `node -e` (fs.rmSync etc.) for file ops."
     - "When a suite is red, first diff test expectations against actual
       behavior history before assuming code bug."
     - "A fresh cloud checkout may have no node_modules and no network —
       then local L1 is impossible; rely on CI and say so." -->

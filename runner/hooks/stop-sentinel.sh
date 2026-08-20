#!/usr/bin/env bash
# Stop hook — cloud runner only (wired via .loop/hub/runner/claude-settings.json,
# passed with --settings by the reusable loop-runner workflow; interactive
# sessions never load it).
#
# Enforces the §G exit contract: the FINAL assistant message must carry a
# <loop-result>…</loop-result> sentinel. Two wakes of the original deployment
# (2026-07-28/29) ended without one and failed the untrusted completion check
# as noise (Nina #540). The check must read only the last assistant message —
# earlier transcript lines contain the sentinel examples from the prompt file
# itself.
#
# Blocks the stop at most once (stop_hook_active guard): the reminder below is
# fed back to the agent; if it still won't comply, the stop goes through and
# the workflow-level sentinel check remains the backstop.
set -uo pipefail

INPUT=$(cat)
STOP_ACTIVE=$(jq -r '.stop_hook_active // false' <<<"$INPUT")
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT")

[ "$STOP_ACTIVE" = "true" ] && exit 0
{ [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0

LAST_TEXT=$(jq -rs '
  [ .[] | select(.type == "assistant" and ((.isSidechain // false) | not)) ]
  | last
  | [ .message.content[]? | select(.type == "text") | .text ]
  | join("\n")' "$TRANSCRIPT" 2>/dev/null || true)

if grep -q '<loop-result>.*</loop-result>' <<<"$LAST_TEXT"; then
  exit 0
fi

cat >&2 <<'EOF'
Wake ended without the required sentinel. End your FINAL message with exactly
one sentinel line per §G of .loop/hub/runner/wake.md:
<loop-result>PR_OPENED #<n></loop-result> | <loop-result>PR_MERGED #<n></loop-result> |
<loop-result>FIX_PUSHED #<n></loop-result> | <loop-result>DISCARDED #<n></loop-result> |
<loop-result>HANDOFF #<n></loop-result> | <loop-result>NOOP: <why></loop-result> |
<loop-result>BLOCKED: <why></loop-result>
Report what ACTUALLY happened — the harness verifies sentinel claims against
GitHub state and fails the wake on a mismatch. If this wake did nothing,
<loop-result>NOOP: <why></loop-result> is the honest exit.
EOF
exit 2

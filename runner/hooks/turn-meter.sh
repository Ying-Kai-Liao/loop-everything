#!/usr/bin/env bash
# PostToolUse hook — cloud runner only (wired via .loop/hub/runner/claude-settings.json).
#
# Makes the invisible --max-turns budget visible. §D2 of wake.md says "commit
# at every coherent milestone", but the agent cannot see how close it is to
# the turn cap — two wakes of the original deployment (2026-07-28) died at the
# cap with nothing pushed (Nina #439). This counts main-loop assistant turns
# in the transcript after each tool call and injects a checkpoint warning into
# context once at ~60% and once at ~80% of the cap.
#
# The cap comes from the MAX_TURNS env var, exported by the reusable
# loop-runner workflow from loop.yml `max_turns` — the same value it passes
# to --max-turns. Default 150 if unset.
set -uo pipefail

INPUT=$(cat)
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT")
SESSION=$(jq -r '.session_id // "unknown"' <<<"$INPUT")
{ [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; } || exit 0

MAX_TURNS="${MAX_TURNS:-150}"
case "$MAX_TURNS" in (*[!0-9]*|'') MAX_TURNS=150 ;; esac
WARN_SOFT=$(( MAX_TURNS * 60 / 100 ))
WARN_HARD=$(( MAX_TURNS * 80 / 100 ))

TURNS=$( (jq -c 'select(.type == "assistant" and ((.isSidechain // false) | not)) | 1' "$TRANSCRIPT" 2>/dev/null || true) | wc -l | tr -d ' ')

STATE="${TMPDIR:-/tmp}/loop-turn-meter-${SESSION}"
LAST=$(cat "$STATE" 2>/dev/null || echo 0)

THRESHOLD=0
if [ "$TURNS" -ge "$WARN_HARD" ]; then THRESHOLD=$WARN_HARD
elif [ "$TURNS" -ge "$WARN_SOFT" ]; then THRESHOLD=$WARN_SOFT
fi
[ "$THRESHOLD" -gt "$LAST" ] || exit 0
echo "$THRESHOLD" > "$STATE"

if [ "$THRESHOLD" -eq "$WARN_HARD" ]; then
  MSG="Turn meter: ~${TURNS} of ${MAX_TURNS} max turns used. WIND DOWN NOW per §D2 of wake.md: commit and push every coherent change to your loop branch, open or keep the draft PR with a HANDOFF: comment, then end with the sentinel. Do not start new work — a turn-cap death discards everything unpushed."
else
  MSG="Turn meter: ~${TURNS} of ${MAX_TURNS} max turns used. If your branch is not pushed to origin yet, checkpoint now per §D2 of wake.md: smallest coherent commit, git push origin <branch>, draft PR. Prefer a clean HANDOFF over racing the cap."
fi

jq -cn --arg msg "$MSG" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'

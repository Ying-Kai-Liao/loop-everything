#!/usr/bin/env bash
# verify-sentinel.sh — untrusted completion check.
#
# "The agent's done is a claim, not a fact." Verify the sentinel's claim
# against GitHub state; fail the run on a lie or a missing report.
#
# Usage: verify-sentinel.sh <execution-file>
# Env:   GH_TOKEN  workflow token (read PR state)
#        REPO      owner/name of the spoke repo
set -uo pipefail

: "${GH_TOKEN:?verify-sentinel: GH_TOKEN is required}"
: "${REPO:?verify-sentinel: REPO is required}"
EXEC_FILE="${1:?verify-sentinel: execution file argument required}"

SENTINEL=$(grep -o '<loop-result>[^<]*</loop-result>' "$EXEC_FILE" | tail -1 || true)
echo "sentinel: ${SENTINEL:-none}"
if [ -z "$SENTINEL" ]; then
  echo "::error::Agent finished without a <loop-result> sentinel"
  exit 1
fi
case "$SENTINEL" in
  *PR_OPENED*|*PR_MERGED*|*FIX_PUSHED*|*DISCARDED*|*HANDOFF*)
    NUM=$(echo "$SENTINEL" | grep -o '#[0-9]*' | tr -d '#' || true)
    if [ -z "$NUM" ] || ! gh pr view "$NUM" --repo "$REPO" --json number >/dev/null 2>&1; then
      echo "::error::Sentinel claims PR activity on #$NUM but that PR does not exist"
      exit 1
    fi
    if echo "$SENTINEL" | grep -q PR_MERGED; then
      STATE=$(gh pr view "$NUM" --repo "$REPO" --json state --jq .state)
      if [ "$STATE" != "MERGED" ]; then
        echo "::error::Sentinel claims PR #$NUM merged but state is $STATE"
        exit 1
      fi
    fi
    ;;
  *NOOP*|*BLOCKED*)
    ;;
esac

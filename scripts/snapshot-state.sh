#!/usr/bin/env bash
# snapshot-state.sh — snapshot in-flight loop state into .loop/ for the agent.
#
# The agent's GitHub App token cannot read checks/Actions state (found by
# Nina's first wake, 2026-07-15). Snapshot everything it needs for routing
# here, with the workflow token. Only lane 0 waits for pending checks to
# settle or pulls failure logs — lanes >= 1 never merge or fix-pass, they
# only need branch awareness.
#
# REST only — GraphQL statusCheckRollup fails on check runs owned by other
# apps (Vercel/GitGuardian): "not accessible by integration".
#
# Inputs (env, passed explicitly by the workflow — no GitHub-expression
# interpolation inside this script):
#   GH_TOKEN        workflow token (read access to checks/Actions)
#   REPO            owner/name of the SPOKE repo
#   LANE            this lane's number (0-based)
#   REQUIRED_CHECK  branch-protection check name from loop.yml
#
# Writes: .loop/state.json, .loop/prs.json, .loop/failed-<n>.log,
# .loop/fixpasses-<n>. All under .loop/ — runtime state, never committed.
set -euo pipefail

: "${GH_TOKEN:?snapshot-state: GH_TOKEN is required}"
: "${REPO:?snapshot-state: REPO is required}"
: "${LANE:?snapshot-state: LANE is required}"
: "${REQUIRED_CHECK:?snapshot-state: REQUIRED_CHECK is required}"

mkdir -p .loop
SETTLE=20
[ "$LANE" != "0" ] && SETTLE=1

gh pr list --repo "$REPO" --state open --label loop \
  --json number,title,headRefName,headRefOid,isDraft > .loop/prs.json
echo "[]" > .loop/state.json

for n in $(jq -r '.[].number' .loop/prs.json); do
  sha=$(jq -r ".[] | select(.number==$n) | .headRefOid" .loop/prs.json)
  branch=$(jq -r ".[] | select(.number==$n) | .headRefName" .loop/prs.json)
  isdraft=$(jq -r ".[] | select(.number==$n) | .isDraft" .loop/prs.json)
  title=$(jq -r ".[] | select(.number==$n) | .title" .loop/prs.json)
  # Wait (bounded ~10 min, lane 0 only) for the required check to settle.
  concl="pending"
  for i in $(seq 1 "$SETTLE"); do
    concl=$(gh api "/repos/$REPO/commits/$sha/check-runs?check_name=$REQUIRED_CHECK" \
      --jq 'if (.check_runs|length)==0 then "none" elif .check_runs[0].status=="completed" then .check_runs[0].conclusion else "pending" end' \
      2>/dev/null || echo "none")
    [ "$concl" != "pending" ] && break
    [ "$SETTLE" = "1" ] && break
    sleep 30
  done
  jq --argjson n "$n" --arg t "$title" --arg b "$branch" --argjson d "$isdraft" --arg v "$concl" \
     '. += [{number:$n,title:$t,headRefName:$b,isDraft:$d,required_check:$v}]' \
     .loop/state.json > .loop/tmp.json && mv .loop/tmp.json .loop/state.json
  if [ "$concl" = "failure" ] && [ "$LANE" = "0" ]; then
    # Resolve the failing Actions run from the check run itself
    # (details_url is .../actions/runs/<id>/...) instead of assuming a
    # CI workflow name — that assumption was Nina-specific.
    rid=$(gh api "/repos/$REPO/commits/$sha/check-runs?check_name=$REQUIRED_CHECK" \
      --jq '.check_runs[0].details_url // ""' 2>/dev/null \
      | grep -o '/actions/runs/[0-9]*' | grep -o '[0-9]*' || true)
    [ -n "$rid" ] && gh run view "$rid" --repo "$REPO" --log-failed 2>/dev/null | tail -200 > ".loop/failed-$n.log" || true
    gh pr view "$n" --repo "$REPO" --json commits \
      --jq '[.commits[].messageHeadline] | map(select(startswith("loop: fix pass"))) | length' \
      > ".loop/fixpasses-$n" || echo 0 > ".loop/fixpasses-$n"
  fi
done

cat .loop/state.json

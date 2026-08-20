#!/usr/bin/env bash
# merge-green.sh — merge green [loop] PRs (the runner's exact merge rule:
# open, non-draft, `loop` label, branch under branch_prefix, required
# check green), plus per-repo blind-spot guards from loop.yml.
#
# Blind spots: CI passes but doesn't prove it — e.g. Nina's `validate`
# typechecks web/ but does not build it, and the #191/#195 incident
# shipped a web breakage past a green validate. loop.yml `blind_spots`
# maps path globs to a required commit-status substring, checked here.
#
# Inputs (env, passed explicitly by the workflow):
#   GH_TOKEN         deploy-capable PAT (LOOP_MERGE_PAT) — used ONLY for
#                    the merge; see the #401 comment in the workflow.
#   READ_TOKEN       the default workflow token — check/status reads stay
#                    here because fine-grained PATs cannot call the Checks
#                    API at all (documented GitHub gap).
#   REPO             owner/name of the spoke repo
#   REQUIRED_CHECK   branch-protection check name from loop.yml
#   BRANCH_PREFIX    loop branch prefix from loop.yml (default loop/)
#   BLIND_SPOTS_JSON JSON array of {paths: [glob], require_status: substr}
set -uo pipefail

: "${GH_TOKEN:?merge-green: GH_TOKEN is required}"
: "${READ_TOKEN:?merge-green: READ_TOKEN is required}"
: "${REPO:?merge-green: REPO is required}"
: "${REQUIRED_CHECK:?merge-green: REQUIRED_CHECK is required}"
BRANCH_PREFIX="${BRANCH_PREFIX:-loop/}"
BLIND_SPOTS_JSON="${BLIND_SPOTS_JSON:-[]}"

# NOTE: `gh pr checks` / GraphQL statusCheckRollup are unusable on the
# default Actions token ("Resource not accessible by integration" when the
# rollup contains other apps' check suites — Vercel, GitGuardian). Same
# limitation loop-runner hit; use the same REST endpoints it uses.
prs=$(gh pr list --repo "$REPO" --label loop --state open \
  --json number,isDraft,headRefName \
  --jq ".[] | select(.isDraft | not) | select(.headRefName | startswith(\"$BRANCH_PREFIX\")) | .number")
if [ -z "$prs" ]; then
  echo "No candidate loop PRs."
  exit 0
fi

for n in $prs; do
  echo "--- PR #$n"
  sha=$(gh pr view "$n" --repo "$REPO" --json headRefOid --jq .headRefOid)
  # The branch-protection-required check, via REST, on READ_TOKEN:
  # pointing these reads at the PAT would 403 -> "api_error" -> silently
  # skip every PR.
  concl=$(GH_TOKEN="$READ_TOKEN" gh api "repos/$REPO/commits/$sha/check-runs?check_name=$REQUIRED_CHECK" \
    --jq '[.check_runs[] | select(.status == "completed")] | sort_by(.started_at) | last | .conclusion // "missing"' 2>/dev/null || echo "api_error")
  if [ "$concl" != "success" ]; then
    echo "$REQUIRED_CHECK is '$concl' — skipping #$n."
    continue
  fi

  # Blind-spot guards: if the PR touches guarded paths, additionally
  # require the matching commit status green.
  spot_count=$(jq 'length' <<<"$BLIND_SPOTS_JSON")
  if [ "$spot_count" -gt 0 ]; then
    files=$(gh pr diff "$n" --repo "$REPO" --name-only)
    blocked=""
    for i in $(seq 0 $((spot_count - 1))); do
      require=$(jq -r ".[$i].require_status" <<<"$BLIND_SPOTS_JSON")
      touched=""
      while IFS= read -r glob; do
        while IFS= read -r f; do
          # [[ == ]] pattern match: `*` crosses `/`, so `web/**` and
          # `web/*` both match nested files — good enough for guards.
          # shellcheck disable=SC2254
          if [[ "$f" == $glob ]]; then touched=1; break; fi
        done <<<"$files"
        [ -n "$touched" ] && break
      done < <(jq -r ".[$i].paths[]" <<<"$BLIND_SPOTS_JSON")
      [ -z "$touched" ] && continue
      status=$(GH_TOKEN="$READ_TOKEN" gh api "repos/$REPO/commits/$sha/status" \
        --jq "[.statuses[] | select(.context | test(\"$require\"; \"i\")) | .state] | if length == 0 then \"missing\" elif all(. == \"success\") then \"success\" else \"not_green\" end" 2>/dev/null || echo "api_error")
      if [ "$status" != "success" ]; then
        echo "Touches blind-spot paths but '$require' status is '$status' — skipping #$n."
        blocked=1
        break
      fi
    done
    [ -n "$blocked" ] && continue
  fi

  if gh pr merge "$n" --repo "$REPO" --squash --delete-branch; then
    echo "Merged #$n."
  else
    # Conflict or protection race — the runner's next wake handles it
    # via its existing fix/discard protocol.
    echo "Merge failed for #$n — leaving it for the runner."
  fi
done

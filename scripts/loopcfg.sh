#!/usr/bin/env bash
# loopcfg.sh — parse a spoke's loops/loop.yml to JSON on stdout, with the
# v2 contract defaults applied. Every other hub script and workflow step
# consumes this via jq; nothing else parses YAML.
#
# No yq: python3 + PyYAML are preinstalled on GitHub-hosted runners and on
# the self-hosted Mac runner, yq is not.
#
# Usage: loopcfg.sh [path/to/loop.yml]   (default: loops/loop.yml)
set -euo pipefail

FILE="${1:-loops/loop.yml}"
if [ ! -f "$FILE" ]; then
  echo "loopcfg: $FILE not found" >&2
  exit 1
fi

python3 - "$FILE" <<'PY'
import json, sys
import yaml

with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f) or {}

if not isinstance(cfg, dict):
    print("loopcfg: top level of loop.yml must be a mapping", file=sys.stderr)
    sys.exit(1)

# Contract defaults (schema/loop.schema.json is the source of truth for
# shape; this only fills in the documented defaults so consumers can use
# plain jq lookups without alternatives).
cfg.setdefault("branch_prefix", "loop/")
cfg.setdefault("model", "claude-sonnet-4-6")
cfg.setdefault("max_turns", 150)
lanes = cfg.setdefault("lanes", {})
if isinstance(lanes, dict):
    lanes.setdefault("default", 1)
    lanes.setdefault("max", 4)
cfg.setdefault("serial_paths", [])
cfg.setdefault("blind_spots", [])
cfg.setdefault("invariants", [])
cfg.setdefault("network", "none")
cfg.setdefault("allowed_tools_extra", [])
cfg.setdefault("setup", [])
cfg.setdefault("registry", None)

json.dump(cfg, sys.stdout)
PY

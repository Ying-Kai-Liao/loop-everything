#!/usr/bin/env bash
# validate-loop.sh — validate a spoke's loops/loop.yml against
# schema/loop.schema.json.
#
# Works on a stock ubuntu-latest runner without pip installs: python3 +
# PyYAML are preinstalled; `jsonschema` may or may not be. If it is, the
# full draft-2020-12 schema is enforced; otherwise a minimal structural
# check covers the required fields and core types.
#
# Usage: validate-loop.sh [path/to/loop.yml] [path/to/loop.schema.json]
set -euo pipefail

FILE="${1:-loops/loop.yml}"
SCHEMA="${2:-$(dirname "$0")/../schema/loop.schema.json}"

if [ ! -f "$FILE" ]; then
  echo "validate-loop: $FILE not found" >&2
  exit 1
fi

python3 - "$FILE" "$SCHEMA" <<'PY'
import json, sys
import yaml

path, schema_path = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = yaml.safe_load(f)

def fail(msg):
    print(f"validate-loop: {path}: {msg}", file=sys.stderr)
    sys.exit(1)

if not isinstance(cfg, dict):
    fail("top level must be a mapping")

try:
    import jsonschema
except ImportError:
    jsonschema = None

if jsonschema is not None:
    with open(schema_path) as f:
        schema = json.load(f)
    try:
        jsonschema.validate(cfg, schema)
    except jsonschema.ValidationError as e:
        fail(f"schema violation at /{'/'.join(map(str, e.absolute_path))}: {e.message}")
    print(f"validate-loop: {path} OK (jsonschema)")
    sys.exit(0)

# Fallback: minimal structural check mirroring the schema's required
# fields and core types. Keep in sync with schema/loop.schema.json.
for key in ("version", "human", "required_check", "verify"):
    if key not in cfg:
        fail(f"missing required field '{key}'")
if cfg["version"] != 2:
    fail("'version' must be 2")
if not (isinstance(cfg["human"], str) and cfg["human"].startswith("@") and len(cfg["human"]) > 1):
    fail("'human' must be a GitHub handle string starting with '@'")
if not (isinstance(cfg["required_check"], str) and cfg["required_check"]):
    fail("'required_check' must be a non-empty string")
verify = cfg["verify"]
if not (isinstance(verify, dict) and "L0" in verify):
    fail("'verify' must be a mapping with at least L0")
if not all(isinstance(v, str) for v in verify.values()):
    fail("'verify' values must be shell-command strings")
if "network" in cfg and cfg["network"] not in ("none", "github", "open"):
    fail("'network' must be one of none|github|open")
for key in ("serial_paths", "invariants", "allowed_tools_extra", "setup"):
    if key in cfg and not (isinstance(cfg[key], list) and all(isinstance(x, str) for x in cfg[key])):
        fail(f"'{key}' must be a list of strings")
if "max_turns" in cfg and not isinstance(cfg["max_turns"], int):
    fail("'max_turns' must be an integer")
if "lanes" in cfg:
    lanes = cfg["lanes"]
    if not isinstance(lanes, dict) or not all(
        isinstance(lanes.get(k, 1), int) for k in ("default", "max")
    ):
        fail("'lanes' must be a mapping with integer default/max")
if "blind_spots" in cfg:
    for i, spot in enumerate(cfg["blind_spots"] or []):
        if not (isinstance(spot, dict)
                and isinstance(spot.get("paths"), list) and spot["paths"]
                and all(isinstance(p, str) for p in spot["paths"])
                and isinstance(spot.get("require_status"), str) and spot["require_status"]):
            fail(f"'blind_spots[{i}]' must be {{paths: [glob...], require_status: str}}")
if "escalation" in cfg:
    esc = cfg["escalation"]
    if not (isinstance(esc, dict)
            and isinstance(esc.get("agent"), str)
            and isinstance(esc.get("label"), str)):
        fail("'escalation' must be {agent: str, label: str}")

print(f"validate-loop: {path} OK (structural fallback)")
PY

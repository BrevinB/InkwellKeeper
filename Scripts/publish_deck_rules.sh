#!/bin/bash
#
# Publishes deck-construction rules (Core rotation + ban lists) to CloudKit so shipped apps pick
# them up without an app release. The values are extracted straight from the baked-in defaults in
# LorcanaSetRegistry.swift — the repo stays the single source of truth.
#
# Rotation / ban procedure:
#   1. Update defaultCoreLegalSets / defaultCoreBannedCards / defaultInfinityBannedCards in
#      Inkwell Keeper/Models/LorcanaSetRegistry.swift (set names must match the bundled data —
#      LorcanaSetRegistryTests checks this; run the tests).
#   2. Scripts/publish_deck_rules.sh --dry-run     # check what would be published
#   3. Scripts/publish_deck_rules.sh               # development — check a debug build picks it up
#   4. Scripts/publish_deck_rules.sh production    # every shipped app (3.4.1+) on next launch
#
# One-time setup: same CloudKit tokens as publish_rules_digest.sh (management + user token, both
# saved with `xcrun cktool save-token`; user tokens expire fast — refresh with
# `xcrun cktool save-token --type user`).
#
# Production note: the DeckRules record type must exist in production first. This script creates
# it in DEVELOPMENT automatically; promoting schema to production is dashboard-only (CloudKit
# Console → your container → Deploy Schema Changes). Do that once, then rerun with `production`.
#
# Empty lists: CloudKit may not store an empty list, so an empty ban list is left OUT of the
# record — the app then keeps its baked-in list for that field. Un-banning everything therefore
# still needs an app update (or a placeholder entry that matches no card).
#
# Usage:
#   Scripts/publish_deck_rules.sh [development|production] [--dry-run]

set -euo pipefail

TEAM_ID="YFXZ6WNN53"
CONTAINER_ID="iCloud.co.brevinb.Inkwell-Keeper"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_FILE="$REPO_ROOT/Inkwell Keeper/Models/LorcanaSetRegistry.swift"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

DRY_RUN=0
ENVIRONMENT="development"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    development|production) ENVIRONMENT="$arg" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# --- 1. Extract the defaults from the Swift source -----------------------------------------

python3 - "$SOURCE_FILE" > "$WORK_DIR/fields.json" << 'PYEOF'
import json, re, sys

source = open(sys.argv[1]).read()

def extract(name):
    match = re.search(r"static let " + name + r"\s*:[^=]*=\s*\[(.*?)\]", source, re.S)
    if not match:
        sys.exit(f"ERROR: couldn't find {name} in LorcanaSetRegistry.swift")
    return re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(1))

core_sets = extract("defaultCoreLegalSets")
if not core_sets:
    sys.exit("ERROR: defaultCoreLegalSets is empty — refusing to publish (the app ignores it anyway).")

fields = {}
for key, name in [
    ("coreLegalSets", "defaultCoreLegalSets"),
    ("coreBannedCards", "defaultCoreBannedCards"),
    ("infinityBannedCards", "defaultInfinityBannedCards"),
]:
    values = extract(name)
    print(f"{key}: {values}", file=sys.stderr)
    if values:
        fields[key] = {"type": "stringListType", "value": values}

print(json.dumps(fields))
PYEOF
echo "Built fields JSON (environment: ${ENVIRONMENT})."

if [ "$DRY_RUN" -eq 1 ]; then
  cat "$WORK_DIR/fields.json"; echo
  echo "Dry run complete — nothing published."
  exit 0
fi

CKTOOL=(xcrun cktool)

# --- 2. Ensure the record type exists (development only) -----------------------------------

if [ "$ENVIRONMENT" = "development" ]; then
  "${CKTOOL[@]}" export-schema \
    --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
    --environment development > "$WORK_DIR/schema.ckdb"

  if ! grep -q "RECORD TYPE DeckRules" "$WORK_DIR/schema.ckdb"; then
    echo "DeckRules type missing from development schema — adding it."
    cat >> "$WORK_DIR/schema.ckdb" << 'SCHEMA'

    RECORD TYPE DeckRules (
        "___createTime"     TIMESTAMP,
        "___createdBy"      REFERENCE,
        "___etag"           STRING,
        "___modTime"        TIMESTAMP,
        "___modifiedBy"     REFERENCE,
        "___recordID"       REFERENCE QUERYABLE,
        coreLegalSets       LIST<STRING>,
        coreBannedCards     LIST<STRING>,
        infinityBannedCards LIST<STRING>,
        GRANT WRITE TO "_creator",
        GRANT CREATE TO "_icloud",
        GRANT READ TO "_world"
    );
SCHEMA
    "${CKTOOL[@]}" import-schema \
      --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
      --environment development --file "$WORK_DIR/schema.ckdb"
    echo "Schema imported to development."
  fi
else
  echo "Publishing to PRODUCTION — assuming the DeckRules schema is already deployed."
  echo "(If this fails with an unknown-record-type error: CloudKit Console → Deploy Schema Changes, then rerun.)"
fi

# --- 3. Create the record (newest record wins in the app) ----------------------------------

"${CKTOOL[@]}" create-record \
  --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" --database-type public \
  --record-type DeckRules \
  --fields-file "$WORK_DIR/fields.json"

echo "Published deck rules to ${ENVIRONMENT}."

#!/bin/bash
#
# Publishes the AI Rules Assistant digest to CloudKit so shipped apps pick it up without
# an app release. The digest text is extracted straight from RulesAssistantService.swift
# (bundledRulesDigest) — the repo stays the single source of truth.
#
# One-time setup:
#   1. Generate a CloudKit Management Token: icloud.developer.apple.com → account (top right)
#      → Tokens → Manage Tokens → new Management Token
#   2. xcrun cktool save-token   (paste the token; choose keychain storage)
#
# Usage:
#   Scripts/publish_rules_digest.sh                       # publish to development
#   Scripts/publish_rules_digest.sh production            # publish to production
#   Scripts/publish_rules_digest.sh development 2026-08-15 # explicit version label
#   Scripts/publish_rules_digest.sh --dry-run             # extract + validate only
#
# Production note: the RulesDigest record type must exist in production first. This script
# creates it in DEVELOPMENT automatically; promoting schema to production is dashboard-only
# (CloudKit Console → your container → Deploy Schema Changes). Do that once, then rerun
# this script with `production`.

set -euo pipefail

TEAM_ID="YFXZ6WNN53"
CONTAINER_ID="iCloud.co.brevinb.Inkwell-Keeper"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_FILE="$REPO_ROOT/Inkwell Keeper/Services/RulesAssistantService.swift"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

DRY_RUN=0
ENVIRONMENT="development"
VERSION="$(date +%Y-%m-%d)"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    development|production) ENVIRONMENT="$arg" ;;
    *) VERSION="$arg" ;;
  esac
done

# --- 1. Extract the digest from the Swift source -------------------------------------------

awk '
  /static let bundledRulesDigest = """/ { flag = 1; next }
  flag && /^    """$/ { exit }
  flag { sub(/^    /, ""); print }
' "$SOURCE_FILE" > "$WORK_DIR/digest.txt"

DIGEST_BYTES=$(wc -c < "$WORK_DIR/digest.txt" | tr -d ' ')
if [ "$DIGEST_BYTES" -lt 5000 ]; then
  echo "ERROR: extracted digest is only ${DIGEST_BYTES} bytes — extraction likely broke." >&2
  exit 1
fi
echo "Extracted digest: ${DIGEST_BYTES} bytes (version label: ${VERSION})"

python3 - "$WORK_DIR/digest.txt" "$VERSION" > "$WORK_DIR/fields.json" << 'PYEOF'
import json, sys
digest = open(sys.argv[1]).read()
print(json.dumps({
    "digest": {"type": "stringType", "value": digest},
    "version": {"type": "stringType", "value": sys.argv[2]},
}))
PYEOF
echo "Built fields JSON."

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete — nothing published."
  exit 0
fi

CKTOOL=(xcrun cktool)

# --- 2. Ensure the record type exists (development only) -----------------------------------

if [ "$ENVIRONMENT" = "development" ]; then
  "${CKTOOL[@]}" export-schema \
    --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
    --environment development > "$WORK_DIR/schema.ckdb"

  if ! grep -q "RECORD TYPE RulesDigest" "$WORK_DIR/schema.ckdb"; then
    echo "RulesDigest type missing from development schema — adding it."
    cat >> "$WORK_DIR/schema.ckdb" << 'SCHEMA'

    RECORD TYPE RulesDigest (
        "___createTime" TIMESTAMP,
        "___createdBy"  REFERENCE,
        "___etag"       STRING,
        "___modTime"    TIMESTAMP,
        "___modifiedBy" REFERENCE,
        "___recordID"   REFERENCE QUERYABLE,
        digest          STRING,
        version         STRING,
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
  echo "Publishing to PRODUCTION — assuming the RulesDigest schema is already deployed."
  echo "(If this fails with an unknown-record-type error: CloudKit Console → Deploy Schema Changes, then rerun.)"
fi

# --- 3. Create the record (newest record wins in the app) ----------------------------------

"${CKTOOL[@]}" create-record \
  --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" --database-type public \
  --record-type RulesDigest \
  --fields-file "$WORK_DIR/fields.json"

echo "Published rules digest ${VERSION} to ${ENVIRONMENT}."

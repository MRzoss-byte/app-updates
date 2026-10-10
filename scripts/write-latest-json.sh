#!/usr/bin/env bash
# Write /<app>/latest.json using per-app field lists in manifest-fields.json.
#
# Usage:
#   scripts/write-latest-json.sh <app> <versionName> <versionCode> <apkUrl> <sha256> <apkFileName> <notes> <publishedAt>
set -euo pipefail

APP="${1:?app}"
VERSION_NAME="${2:?versionName}"
VERSION_CODE="${3:?versionCode}"
APK_URL="${4:?apkUrl}"
SHA256="${5:?sha256}"
APK_FILE_NAME="${6:?apkFileName}"
NOTES="${7:-}"
PUBLISHED_AT="${8:-}"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "write-latest-json.sh: run from app-updates repo" >&2; exit 1; }
cd "$ROOT"

fields_file="scripts/manifest-fields.json"
[[ -f "$fields_file" ]] || { echo "write-latest-json.sh: missing $fields_file" >&2; exit 1; }

mapfile -t fields < <(jq -r --arg app "$APP" '.[$app][]? // empty' "$fields_file")
if ((${#fields[@]} == 0)); then
  mapfile -t fields < <(jq -r '.["*"][]? // empty' "$fields_file")
fi
((${#fields[@]} > 0)) || { echo "write-latest-json.sh: no manifest fields for $APP" >&2; exit 1; }

mkdir -p "$APP"
fields_json=$(printf '%s\n' "${fields[@]}" | jq -R . | jq -s .)

jq -n \
  --argjson fields "$fields_json" \
  --arg version "$VERSION_NAME" \
  --arg versionName "$VERSION_NAME" \
  --argjson versionCode "$VERSION_CODE" \
  --arg apkUrl "$APK_URL" \
  --arg sha256 "$SHA256" \
  --arg apkFileName "$APK_FILE_NAME" \
  --arg notes "$NOTES" \
  --arg publishedAt "$PUBLISHED_AT" \
  '{
    version: $version,
    versionName: $versionName,
    versionCode: $versionCode,
    apkUrl: $apkUrl,
    sha256: $sha256,
    apkFileName: $apkFileName,
    notes: $notes,
    publishedAt: $publishedAt
  } as $full
  | reduce $fields[] as $k ({}; . + {($k): $full[$k]})' > "${APP}/latest.json"

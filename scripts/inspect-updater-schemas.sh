#!/usr/bin/env bash
# Clone private app repos (read-only) and infer latest.json field names from updater code.
# Updates scripts/manifest-fields.json when patterns are found.
#
# Usage: scripts/inspect-updater-schemas.sh
set -euo pipefail

unset GH_TOKEN GITHUB_TOKEN 2>/dev/null || true

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
command -v gh >/dev/null || { echo "gh required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

token=$(gh auth token)
mapfile -t apps < <(jq -r '.apps[] | "\(.id)|\(.sourceRepo)"' scripts/app-sources.json)

manifest=$(cat scripts/manifest-fields.json)

for pair in "${apps[@]}"; do
  id="${pair%%|*}"
  repo="${pair#*|}"
  dest="$tmpdir/$id"
  echo "Inspecting $id ($repo)..."
  if ! git clone --depth 1 "https://x-access-token:${token}@github.com/${repo}.git" "$dest" 2>/dev/null; then
    echo "  skip: cannot clone $repo" >&2
    continue
  fi
  hits=$(rg -l -i 'latest\.json|apkUrl|versionCode|UpdateChecker|AppUpdate|RemoteUpdate' "$dest" 2>/dev/null | head -20 || true)
  if [[ -z "$hits" ]]; then
    echo "  no updater files found" >&2
    continue
  fi
  fields=$(rg -o '@SerialName\("([^"]+)"\)|"([a-zA-Z]+)"\s*:\s*|apkUrl|versionCode|versionName|publishedAt|sha256|notes' "${hits[@]}" 2>/dev/null \
    | sed -n 's/.*"\([a-zA-Z][a-zA-Z0-9]*\)".*/\1/p; s/^apkUrl$/apkUrl/p; s/^versionCode$/versionCode/p' \
    | sort -u | grep -E '^(version|versionName|versionCode|apkUrl|sha256|notes|publishedAt|apkFileName)$' || true)
  if [[ -n "$fields" ]]; then
    arr=$(printf '%s\n' $fields | jq -R . | jq -s .)
    manifest=$(jq --arg id "$id" --argjson fields "$arr" '.[$id] = $fields' <<<"$manifest")
    echo "  fields: $(printf '%s ' $fields)"
  fi
done

printf '%s\n' "$manifest" | jq . > scripts/manifest-fields.json
echo "Wrote scripts/manifest-fields.json"

#!/usr/bin/env bash
# Mirror release APKs from private app repos into public app-updates releases + latest.json feeds.
#
# Usage:
#   scripts/sync-public-feed.sh              # all apps in scripts/app-sources.json
#   scripts/sync-public-feed.sh diyfolio ... # subset of app ids
#
# Environment:
#   PUBLISH_SKIP_GIT=1   — do not commit (default during loop; one commit at end unless set to 0)
#   PRIVATE_REPO_TOKEN / GH_PAT / gh auth — read private source releases
set -euo pipefail

unset GH_TOKEN GITHUB_TOKEN 2>/dev/null || true

die() {
  echo "sync-public-feed.sh: $*" >&2
  exit 1
}

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "run from app-updates repo"
cd "$ROOT"

command -v gh >/dev/null || die "gh is required"
command -v jq >/dev/null || die "jq is required"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated"

config="scripts/app-sources.json"
[[ -f "$config" ]] || die "missing $config"

skip_final_git="${PUBLISH_SKIP_GIT:-0}"

if (($# > 0)); then
  wanted=("$@")
else
  mapfile -t wanted < <(jq -r '.apps[].id' "$config")
fi

failures=()
published=()

for app in "${wanted[@]}"; do
  entry=$(jq -c --arg id "$app" '.apps[] | select(.id == $id)' "$config")
  [[ -n "$entry" ]] || die "unknown app id $app in $config"

  source_repo=$(jq -r '.sourceRepo' <<<"$entry")
  source_tag=$(jq -r '.sourceTag' <<<"$entry")
  notes=$(jq -r --arg id "$app" '.notes // ""' <<<"$entry")

  echo "==> $app from $source_repo ($source_tag)"

  err_file=$(mktemp)
  if ! apk_path=$(SOURCE_REPO="$source_repo" SOURCE_TAG="$source_tag" scripts/fetch-private-release-apk.sh 2>"$err_file"); then
    err=$(cat "$err_file" 2>/dev/null || true)
    rm -f "$err_file"
    echo "$err" >&2
    failures+=("$app: $source_repo ($source_tag) — ${err:-fetch failed}")
    continue
  fi

  # shellcheck disable=SC1090
  eval "$(scripts/apk-version.sh "$apk_path")"
  version_name="$versionName"
  version_code="$versionCode"

  if [[ -z "$notes" || "$notes" == "null" ]]; then
    display=$(jq -r --arg id "$app" '.apps[] | select(.id == $id) | .name' apps.json)
    notes="${display} ${version_name}"
  fi

  PUBLISH_SKIP_GIT=1 scripts/publish.sh "$app" "$apk_path" "$version_name" "$version_code" "$notes"
  published+=("$app")
done

if ((${#published[@]} == 0)); then
  echo "No apps published." >&2
  for f in "${failures[@]}"; do echo "  - $f" >&2; done
  exit 1
fi

if [[ "$skip_final_git" == "1" ]]; then
  echo "PUBLISH_SKIP_GIT=1 — latest.json files written; not committing."
  exit 0
fi

git add -- "${published[@]/%//}/latest.json" 2>/dev/null || true
for app in "${published[@]}"; do
  git add -- "${app}/latest.json"
done

if git diff --cached --quiet; then
  echo "No manifest changes to commit."
else
  summary=$(printf '%s, ' "${published[@]}")
  summary="${summary%, }"
  git commit -m "Publish public feeds: ${summary}"
  git push -u origin HEAD
  echo "Pushed feeds for: ${summary}"
fi

if ((${#failures[@]} > 0)); then
  echo "Some apps failed:" >&2
  for f in "${failures[@]}"; do echo "  - $f" >&2; done
  exit 1
fi

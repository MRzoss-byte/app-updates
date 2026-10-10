#!/usr/bin/env bash
# Publish one Android APK to a GitHub Release and point /<app>/latest.json at it.
#
# Usage:
#   scripts/publish.sh <app> <apk> <versionName> <versionCode> [notes]
#
# Example:
#   scripts/publish.sh diyfolio ./app-release.apk 11.6.26 110626 "Fixes export."
#
# The release tag is <app>-v<versionName> (diyfolio-v11.6.26). The asset name is
# <app>-<versionName>.apk. apkUrl is the GitHub release asset download URL.
# This script commits <app>/latest.json and pushes the current branch.
# Set PUBLISH_SKIP_GIT=1 to write the file without committing or pushing.
set -euo pipefail

# Stale GH_TOKEN in the environment breaks `gh` (installation token is in gh auth).
if [[ -n "${GH_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
  unset GH_TOKEN GITHUB_TOKEN
fi

die() {
  echo "publish.sh: $*" >&2
  exit 1
}

usage() {
  echo "Usage: scripts/publish.sh <app> <apk> <versionName> <versionCode> [notes]" >&2
  exit 2
}

if [[ $# -lt 4 ]]; then
  usage
fi

APP="$1"
APK="$2"
VERSION_NAME="$3"
VERSION_CODE="$4"
NOTES="${*:5}"

if [[ ! "$APP" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  die "app id must be lowercase words separated by hyphens"
fi
if [[ ! "$VERSION_NAME" =~ ^[0-9][0-9A-Za-z._-]*$ ]]; then
  die "versionName must start with a digit and use only letters, digits, dots, underscores, and hyphens"
fi
if [[ ! "$VERSION_CODE" =~ ^[1-9][0-9]*$ ]]; then
  die "versionCode must be a positive integer"
fi
if (( VERSION_CODE > 2100000000 )); then
  die "versionCode is above Android's limit of 2100000000"
fi
if [[ "$APK" =~ ^https?:// ]]; then
  tmp_apk=$(mktemp --suffix=.apk)
  trap 'rm -f "$tmp_apk"' RETURN
  curl -fsSL "$APK" -o "$tmp_apk"
  APK="$tmp_apk"
fi
if [[ ! -f "$APK" ]]; then
  die "APK not found: $APK"
fi
if [[ ! -s "$APK" ]]; then
  die "APK is empty: $APK"
fi

if command -v realpath >/dev/null; then
  APK=$(realpath "$APK")
else
  command -v python3 >/dev/null || die "realpath or python3 is required"
  APK=$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$APK")
fi
signature=$(od -An -t x1 -N 2 "$APK" | tr -d ' \n')
if [[ "$signature" != "504b" ]]; then
  die "APK is not a zip archive: $APK"
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "run this from inside the app-updates repo"
cd "$ROOT"

command -v gh >/dev/null || die "gh is required"
command -v jq >/dev/null || die "jq is required"
if command -v sha256sum >/dev/null; then
  sha_file() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null; then
  sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  die "sha256sum or shasum is required"
fi

if [[ ! -f apps.json ]]; then
  die "apps.json is missing"
fi
if ! jq -e --arg id "$APP" '[.apps[] | select(.id == $id)] | length == 1' apps.json >/dev/null; then
  die "unknown app id '$APP' (see apps.json)"
fi

display_name=$(jq -r --arg id "$APP" '.apps[] | select(.id == $id) | .name' apps.json)
if [[ -z "${NOTES//[[:space:]]/}" ]]; then
  NOTES="${display_name} ${VERSION_NAME}"
fi
origin=$(git remote get-url origin)
if [[ ! "$origin" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
  die "origin is not a github.com repo"
fi
REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"

tag="${APP}-v${VERSION_NAME}"
asset_name="${APP}-${VERSION_NAME}.apk"
sha=$(sha_file "$APK")
published_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ -n "${EXPECTED_SHA256:-}" && "$sha" != "$EXPECTED_SHA256" ]]; then
  die "sha256 mismatch: expected $EXPECTED_SHA256 got $sha"
fi

gh auth status >/dev/null 2>&1 || die "gh is not authenticated"

if gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
  die "release $tag already exists"
fi

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -- "$APK" "$stage/$asset_name"
gh release create "$tag" "$stage/$asset_name" \
  --repo "$REPO" \
  --title "${display_name} ${VERSION_NAME}" \
  --notes="$NOTES"

apk_url=$(gh api "repos/${REPO}/releases/tags/${tag}" \
  --jq ".assets[] | select(.name == \"${asset_name}\") | .browser_download_url")
if [[ -z "$apk_url" ]]; then
  die "release $tag has no asset named $asset_name"
fi

scripts/write-latest-json.sh "$APP" "$VERSION_NAME" "$VERSION_CODE" "$apk_url" "$sha" "$asset_name" "$NOTES" "$published_at"

echo "Wrote ${APP}/latest.json"
echo "apkUrl ${apk_url}"
echo "sha256 ${sha}"

if [[ "${PUBLISH_SKIP_GIT:-}" == "1" ]]; then
  echo "Skipped git commit (PUBLISH_SKIP_GIT=1). Commit ${APP}/latest.json so the site picks it up."
  exit 0
fi

git add -- "${APP}/latest.json"
git commit -m "Publish ${APP} ${VERSION_NAME} (${VERSION_CODE})" -m "$NOTES"
git push -u origin HEAD
echo "Pushed ${APP}/latest.json. Production updates after this commit is on main."

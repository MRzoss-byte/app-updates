#!/usr/bin/env bash
# Download an APK asset from a private GitHub release.
#
# Usage:
#   SOURCE_REPO=MRzoss-byte/Auction-Tracker- SOURCE_TAG=v1.0.3 \
#     scripts/fetch-private-release-apk.sh [output.apk]
#
# Uses the first non-empty token from:
#   AUCTION_TRACKER_REPO_TOKEN, PRIVATE_REPO_TOKEN, GH_PAT, GH_TOKEN, GITHUB_TOKEN
set -euo pipefail

die() {
  echo "fetch-private-release-apk.sh: $*" >&2
  exit 1
}

SOURCE_REPO="${SOURCE_REPO:-MRzoss-byte/Auction-Tracker-}"
SOURCE_TAG="${SOURCE_TAG:-v1.0.3}"
OUT="${1:-}"

command -v gh >/dev/null || die "gh is required"

token=""
for name in AUCTION_TRACKER_REPO_TOKEN PRIVATE_REPO_TOKEN GH_PAT GH_TOKEN GITHUB_TOKEN; do
  if [[ -n "${!name:-}" ]]; then
    token="${!name}"
    break
  fi
done
if [[ -z "$token" ]]; then
  token="$(gh auth token 2>/dev/null || true)"
fi
[[ -n "$token" ]] || die "no GitHub token available"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

export GH_TOKEN="$token"
tag="$SOURCE_TAG"
if ! gh release view "$tag" --repo "$SOURCE_REPO" >/dev/null 2>&1; then
  if [[ "$tag" == v* ]]; then
    alt="${tag#v}"
  else
    alt="v${tag}"
  fi
  if gh release view "$alt" --repo "$SOURCE_REPO" >/dev/null 2>&1; then
    tag="$alt"
  else
    die "cannot read release $SOURCE_TAG on $SOURCE_REPO (grant repo access or set AUCTION_TRACKER_REPO_TOKEN)"
  fi
fi

gh release download "$tag" --repo "$SOURCE_REPO" --pattern '*.apk' -D "$tmpdir"
mapfile -t apks < <(find "$tmpdir" -type f -name '*.apk' | sort)
((${#apks[@]} > 0)) || die "release $SOURCE_TAG on $SOURCE_REPO has no .apk assets"
((${#apks[@]} == 1)) || die "release $SOURCE_TAG on $SOURCE_REPO has multiple APK assets: ${apks[*]}"

if [[ -n "$OUT" ]]; then
  cp -- "${apks[0]}" "$OUT"
  realpath "$OUT" 2>/dev/null || python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$OUT"
else
  printf '%s\n' "${apks[0]}"
fi

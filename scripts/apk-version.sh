#!/usr/bin/env bash
# Print versionCode and versionName from an APK (aapt dump badging).
# Usage: scripts/apk-version.sh <apk>
set -euo pipefail

apk="${1:?apk path required}"
command -v aapt >/dev/null || { echo "apk-version.sh: install aapt (android SDK build-tools)" >&2; exit 1; }

badging=$(aapt dump badging "$apk")
version_code=$(printf '%s\n' "$badging" | sed -n "s/.* versionCode='\([^']*\)'.*/\1/p" | head -1)
version_name=$(printf '%s\n' "$badging" | sed -n "s/.* versionName='\([^']*\)'.*/\1/p" | head -1)

[[ -n "$version_code" ]] || { echo "apk-version.sh: could not read versionCode from $apk" >&2; exit 1; }
[[ -n "$version_name" ]] || { echo "apk-version.sh: could not read versionName from $apk" >&2; exit 1; }

printf 'versionCode=%s\nversionName=%s\n' "$version_code" "$version_name"

# app-updates

Public update feed and APK downloads for Lefor family Android apps.

This repository holds release metadata and the download page only. APKs are GitHub Release assets. Do not commit application source or APK files to git.

**Production site:** [https://app-updates-lovat.vercel.app](https://app-updates-lovat.vercel.app)

## Apps

| App | id | Package | Feed |
| --- | --- | --- | --- |
| DIYfolio | `diyfolio` | `app.diyfolio.app` | `/diyfolio/latest.json` |
| Hannah's Paints | `hannahs-paints` | | `/hannahs-paints/latest.json` |
| Mileage Tracker | `mileage-tracker` | | `/mileage-tracker/latest.json` |
| Auction Tracker | `auction-tracker` | `app.lotledger.auction` | `/auction-tracker/latest.json` |

Live feed URL pattern: `https://app-updates-lovat.vercel.app/<app>/latest.json`

## latest.json

Field names match each app’s in-app updater (see `scripts/manifest-fields.json`, generated/verified with `scripts/inspect-updater-schemas.sh`). Typical shape:

```json
{
  "version": "1.2.2",
  "versionCode": 12,
  "apkUrl": "https://github.com/MRzoss-byte/app-updates/releases/download/auction-tracker-v1.2.2/auction-tracker-1.2.2.apk",
  "sha256": "<64 lowercase hex characters>",
  "notes": "Auction Tracker 1.2.2",
  "publishedAt": "2026-10-10T22:00:00Z",
  "apkFileName": "auction-tracker-1.2.2.apk"
}
```

`version` is the human-readable version string (`versionName` from the APK). `apkUrl` must be the **public** `app-updates` release asset URL (unauthenticated download).

## Restart / sync all feeds

From a machine or Cloud Agent with **read access** to the private app repos:

```bash
# Optional: refresh per-app JSON field lists from Kotlin updater sources
scripts/inspect-updater-schemas.sh

# Mirror configured releases → public GitHub releases + latest.json (one commit)
scripts/sync-public-feed.sh
```

Source mapping lives in `scripts/app-sources.json` (repo, tag, or `latest`).

Requires `git`, `gh`, `jq`, `sha256sum`, and `aapt` (for `versionCode` / `versionName` from the APK).

## Publish one app

```bash
scripts/publish.sh <app> <apk> <versionName> <versionCode> [notes]
```

Example:

```bash
scripts/publish.sh diyfolio ./app-release.apk 11.6.42 65 "DIYfolio 11.6.42"
```

What it does:

1. Validates `<app>` against `apps.json`.
2. Creates GitHub Release `<app>-v<versionName>` on **this** repo.
3. Uploads `<app>-<versionName>.apk`.
4. Writes `<app>/latest.json` (per-app field list).
5. Commits and pushes (unless `PUBLISH_SKIP_GIT=1`).

To copy an APK from a private source release:

```bash
apk=$(SOURCE_REPO=MRzoss-byte/Auction-Tracker- SOURCE_TAG=v1.2.2 scripts/fetch-private-release-apk.sh)
scripts/publish.sh auction-tracker "$apk" 1.2.2 12 "Auction Tracker 1.2.2"
```

`SOURCE_TAG=latest` uses the newest release on the source repo. Tokens: `PRIVATE_REPO_TOKEN`, `GH_PAT`, or `gh auth` with repo read access.

## Wiring app release CI to this feed

After each app’s GitHub Release (APK attached), update the public feed in one of these ways:

| App | Private source repo | Suggested trigger |
| --- | --- | --- |
| DIYfolio | `MRzoss-byte/DIYfolio` | On release published: run `fetch-private-release-apk.sh` + `publish.sh diyfolio …` (or bump `scripts/app-sources.json` and run `sync-public-feed.sh`) |
| Auction Tracker | `MRzoss-byte/Auction-Tracker-` | Same with `auction-tracker` |
| Mileage Tracker | `MRzoss-byte/Mileage-Tracker` | Same with `mileage-tracker` |
| Hannah's Paints | `MRzoss-byte/Hannah-s-Paints` | Same with `hannahs-paints` |

**GitHub Actions on `app-updates`:** workflow **Sync public feed** (`sync-public-feed.yml`) runs on `workflow_dispatch` or when `scripts/app-sources.json` changes. Set repository secrets `PRIVATE_REPO_TOKEN` or per-app `*_REPO_TOKEN` with read access to private releases.

**Request-file workflow:** push `publish-requests/<app>.json` to trigger **Publish app (request file)** (legacy; prefer `sync-public-feed.sh`).

## Deploy

Static site on Vercel (`vercel.json`: CORS `*`, short cache on `/*/latest.json`). Pushes to `main` deploy production. `scripts/publish.sh` / `scripts/sync-public-feed.sh` push `latest.json`; that updates the live feed after deploy.

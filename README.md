# app-updates

Public update feed and APK downloads for Lefor family Android apps.

This repository holds release metadata and the download page only. APKs are GitHub Release assets. Do not commit application source or APK files.

## Apps

| App | id | Package | Feed |
| --- | --- | --- | --- |
| DIYfolio | `diyfolio` | `app.diyfolio.app` | `/diyfolio/latest.json` |
| Hannah's Paints | `hannahs-paints` | | `/hannahs-paints/latest.json` |
| Mileage Tracker | `mileage-tracker` | | `/mileage-tracker/latest.json` |
| Auction Tracker | `auction-tracker` | `app.lotledger.auction` | `/auction-tracker/latest.json` |

The live feed URL is `https://<vercel-host>/<app>/latest.json`.

## latest.json

```json
{
  "versionCode": 4,
  "versionName": "1.0.3",
  "apkUrl": "https://github.com/MRzoss-byte/app-updates/releases/download/auction-tracker-v1.0.3/auction-tracker-1.0.3.apk",
  "sha256": "<64 lowercase hex characters>",
  "apkFileName": "auction-tracker-1.0.3.apk"
}
```

`versionCode` is the Android `versionCode` integer. `apkUrl` is the release asset download URL. `sha256` is the APK file hash. `apkFileName` is the GitHub Release asset name.

Until the first publish, `latest.json` is absent and the download page says no public release yet.

## Publish

Requires `git`, `gh` (authenticated with permission to create releases in this repo), `jq`, and `sha256sum` (`shasum` works too). Run from a checkout that can push. Production follows `main` once Vercel Git deployment is connected.

```bash
scripts/publish.sh <app> <apk> <versionName> <versionCode> [notes]
```

```bash
scripts/publish.sh diyfolio ./app-release.apk 11.6.26 110626 "Fixes the export crash."
```

What it does:

1. Checks `<app>` against `apps.json`.
2. Creates GitHub Release `<app>-v<versionName>` (for example `diyfolio-v11.6.26`).
3. Uploads the APK as `<app>-<versionName>.apk`.
4. Writes `<app>/latest.json` with the download URL, sha256, and apkFileName.
5. Commits that file and pushes the current branch.

`PUBLISH_SKIP_GIT=1` writes `latest.json` and uploads the release without committing. Set `EXPECTED_SHA256` to fail fast when the APK hash does not match. Quote notes when they contain spaces. Re-publishing the same version name fails because the tag already exists.

To copy an APK from a private source release (for example `MRzoss-byte/Auction-Tracker-` tag `v1.0.3`), set `AUCTION_TRACKER_REPO_TOKEN` (or `PRIVATE_REPO_TOKEN` / `GH_PAT`) and run:

```bash
apk=$(SOURCE_REPO=MRzoss-byte/Auction-Tracker- SOURCE_TAG=v1.0.3 scripts/fetch-private-release-apk.sh)
EXPECTED_SHA256=d60a82fa9b02e7ce8b1dbeae52d31ba73dc3849a6106661fb85ca3371295d001 \
  scripts/publish.sh auction-tracker "$apk" 1.0.3 4
```

GitHub Actions workflow `Publish auction-tracker` does the same using the Production environment secrets.

## Deploy

The site is static: `index.html` lists each app, and Vercel serves the JSON files with a one-minute cache and open CORS.

Connect the GitHub repo so a push to `main` deploys production. `scripts/publish.sh` pushes `latest.json`; that push is what updates the live feed.

1. Open [vercel.com/new](https://vercel.com/new) (or **New Project** at the top right of the Vercel dashboard).
2. If GitHub is not connected, use the Git provider dropdown, continue with GitHub, and grant the Vercel GitHub App access to `MRzoss-byte/app-updates`.
3. Select `MRzoss-byte/app-updates` and click **Import**.
4. Framework Preset: **Other**. Root Directory: `./`.
5. Open **Build and Output Settings** and clear Build Command and Output Directory if Vercel filled them in.
6. Click **Deploy**.

The deployment screen shows the production URL. The feed for an app is `https://<that-host>/<app>/latest.json`, for example `https://<that-host>/diyfolio/latest.json`.

This environment had no Vercel login, and the Vercel connector cannot complete interactive auth here. A one-off CLI deploy, after `vercel login` on your machine, is `vercel link` then `vercel --prod` from the repo root. Git import is the setup that keeps the feed in sync with `publish.sh`.

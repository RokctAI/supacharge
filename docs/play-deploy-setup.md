# Play deploy setup

This repo deploys to Google Play through the shared `universal-play-deploy`
workflow. A deploy fails until the items below are in place. Each is needed
once, not on every run. Green no-op runs are not failures; see section 7.

## 1. Google Play Console

- The app exists in Play Console under the package name in the Occultation
  `.env/production.env` key `<ROLE>_ANDROID_PACKAGE_NAME` (the role is the
  contents of `.rokct/config/app_type`).
- The first build was uploaded by hand. Play requires it before any API upload.
- The track you deploy to exists: `internal`, `alpha`, `beta` or `production`.

## 2. Google Cloud service account

1. In the Google Cloud project linked to Play Console, enable the
   **Google Play Android Developer API**.
2. IAM & Admin > Service accounts > Create service account. Grant it no
   Google Cloud roles.
3. Open the account > Keys > Add key > Create new key > JSON. Keep the file private.

## 3. Give the service account access in Play Console

1. Play Console > Users and permissions > Invite new users.
2. Enter the service account email: the `client_email` field of the JSON key.
3. Under App permissions, add this app with release permissions (Release
   manager). Store-listing permission is needed for the image and text upload.
4. Play can take a while to apply new access. A deploy straight after may fail.

## 4. Secrets

Set these on this repo (Settings > Secrets and variables > Actions), or leave
them unset and provide the same values as files in RokctAI/Occultation `.env/`:

- `PLAY_STORE_SERVICE_ACCOUNT_JSON`: the whole JSON key. File fallback:
  `.env/play_store_service_account.json`.
- `KEY_JKS`, `KEY_PASSWORD`, `ALIAS_PASSWORD`: the upload keystore (base64) and
  its passwords. The key alias must be `upload`.
- `GOOGLE_SERVICES_JSON`: Firebase config, if the app uses Firebase. File
  fallback: `.env/google-services.json`.
- `MONOREPO_PAT`: a token that can read RokctAI/Occultation.
- `APP_ID` and `APP_PRIVATE_KEY`: the GitHub App used to open the PRs this
  workflow writes.

## 5. Repo files

- `version.json` at the repo root: `{"version": "X.Y.Z"}`, the version to ship.
- `.rokct/config/app_type`: the app role, for example `launcher`.
- `.github/.play-store-release-state.json`: the record of the last Play
  release. Create it by running the deploy once with `allow_first_release`
  set to true, then merge the PR it opens. Until it is merged, the gate refuses
  with `release-state-unknown`.

## 6. What a deploy uploads

- The AAB attached to the latest published GitHub release. That release's tag
  must be `v` followed by the `version.json` version. Publish that release first.
- Store listing images and text from `marketing/tour/store/`,
  `marketing/tour/tablet/store/`, `marketing/store/listing/` and
  `marketing/store/video.txt`. Images whose files did not change are not
  re-pushed.

## 7. Refusals

- `release-state-unknown`: the state marker is missing. See section 5.
- `release-version-mismatch`: the latest release is not `v` plus `version.json`.
  Publish that release.
- `version-unchanged-since-last-release`: same version. The AAB is skipped;
  listing assets still update.
- `already-released-this-week`: one AAB per ISO week. Listing assets still update.
- `no-new-commits-since-last-release`: nothing changed. The whole run is a no-op.

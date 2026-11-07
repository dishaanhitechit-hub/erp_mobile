# PRAX ERP — Play Store, auto-deploy & push notifications

What is already done in code:

| Part | Where |
|---|---|
| Release signing with your own upload key | `android/app/build.gradle` (reads `android/key.properties` locally, env vars in CI) |
| Target Android 16 (API 36), app name "PRAX ERP" | `android/app/build.gradle`, `AndroidManifest.xml` |
| Firebase push in the app (auto-enabled when `google-services.json` exists) | `lib/services/push_service.dart` |
| Backend: device tokens + push on every ping / alert / chat message | `erp_backend` → `chatting/push_service.py`, migration `c4f8a2d61e93` |
| Auto build + upload to Play on every push to `master` | `.github/workflows/play-store.yml` |

Everything below needs **your** accounts — do it once.

---

## 1. Upload key (already created — back it up!)

Created on the dev Mac in `~/prax-erp-keys/`:

- `upload.jks` — the upload key
- `key.properties` — its passwords (alias `upload`)

**Copy both files to a safe place (password manager / company drive).**
Never commit them — the GitHub repo is public. With Play App Signing, a lost
upload key can be reset through Play support, but it takes days.

## 2. Google Play Developer account

1. Go to <https://play.google.com/console/signup> with the company Google account.
2. Choose **Organization** (not Personal). Personal accounts must run a closed
   test with 12+ testers for 14 days before they can publish to production;
   organization accounts don't. You need the company's D-U-N-S number.
3. Pay the one-time US$25 fee and finish identity verification (can take a few days).

## 3. Create the app and do the FIRST upload by hand

Google requires the first bundle to be uploaded in the console.

1. Play Console → **Create app** → name "PRAX ERP", app, free.
2. Get a bundle: GitHub → Actions → **Play Store** → latest run → download the
   `prax-erp-<n>.aab` artifact. (It runs on every push once step 6 secrets exist;
   until then, build it on the dev Mac: `flutter build appbundle --release`.)
3. **Testing → Internal testing → Create release** → upload the `.aab` →
   accept **Play App Signing** → save → roll out. Add yourself as a tester.
4. Fill in the required pages (Dashboard shows them): privacy policy URL,
   app access (give Google a test login — the app needs one), Data safety
   (account info + device ID for notifications), content rating, target audience.

## 4. Play API access for GitHub (service account)

1. Google Cloud console → same project as step 5 is fine → **IAM → Service accounts →
   Create** (e.g. `github-play-upload`) → **Keys → Add key → JSON** → download.
2. Play Console → **Users and permissions → Invite new user** → the service
   account's email → app permissions for PRAX ERP: *Release apps to testing tracks*
   and *Release to production* (and *View app information*).

## 5. Firebase (instant notifications)

1. <https://console.firebase.google.com> → **Add project** (e.g. "PRAX ERP").
2. **Add app → Android** → package name `com.dishaanhitech.erp_mobile` → register →
   download **google-services.json**.
   - For local builds put it at `erp_mobile/android/app/google-services.json` (git-ignored).
3. **Project settings → Service accounts → Generate new private key** → this JSON
   is for the **backend server only**:
   ```bash
   # on the backend server
   sudo cp firebase-key.json /srv/backend/firebase-key.json
   sudo chmod 600 /srv/backend/firebase-key.json
   echo 'FIREBASE_CREDENTIALS=/srv/backend/firebase-key.json' >> /srv/backend/.env
   sudo systemctl restart backend.service
   ```
   The backend deploy already installs `firebase-admin` and creates the
   `comm_device_tokens` table (`flask db upgrade`).

## 6. GitHub secrets (needs the repo owner `dishaanhitechit-hub`)

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | output of `base64 -i ~/prax-erp-keys/upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `~/prax-erp-keys/key.properties` |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` from the same file |
| `PLAY_SERVICE_ACCOUNT_JSON` | whole content of the step-4 JSON |
| `GOOGLE_SERVICES_JSON` | whole content of `google-services.json` (step 5) |

Or with the GitHub CLI, logged in as the owner, from the `erp_mobile` folder:

```bash
gh secret set ANDROID_KEYSTORE_BASE64 < <(base64 -i ~/prax-erp-keys/upload.jks)
gh secret set ANDROID_KEYSTORE_PASSWORD --body "$(grep storePassword ~/prax-erp-keys/key.properties | cut -d= -f2)"
gh secret set ANDROID_KEY_ALIAS --body upload
gh secret set ANDROID_KEY_PASSWORD --body "$(grep keyPassword ~/prax-erp-keys/key.properties | cut -d= -f2)"
gh secret set PLAY_SERVICE_ACCOUNT_JSON < path/to/play-service-account.json
gh secret set GOOGLE_SERVICES_JSON < path/to/google-services.json
```

Optional repo **variable** `PLAY_TRACK` = `internal` (default), `beta` or `production`.

## 7. How auto-update works after that

1. Push to `master`.
2. GitHub Actions → **Play Store** builds a signed bundle (version code = run number + 100)
   and uploads it to the `PLAY_TRACK` track.
3. Internal testing: available in minutes. Production: Google reviews each update
   (usually hours, up to a few days).
4. Phones update automatically through the Play Store (default auto-update setting).

When you're happy with internal testing, set `PLAY_TRACK=production`
(the first production release also needs "Production → Create release" once in the console).

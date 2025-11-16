# In-App Update Flow (Firebase Storage)

This document explains how the new automatic updater works and how to publish new builds without Play Store.

## Overview

1. **Host the APK** in Firebase Storage (e.g., `gs://<project-id>.appspot.com/releases/vanmerchant-105.apk`).
2. **Describe the release** in Firestore document `app_updates/android` with metadata such as version codes, download URL, hash, and changelog.
3. When the app launches, `AppUpdateGate` asks `AppUpdateService` to read the Firestore doc. If `latestVersionCode` is higher than the currently installed build, the user sees a dialog before entering the app.
4. Pressing **Update** downloads the APK straight from Firebase Storage via the `ota_update` plugin and hands it off to Android's package installer.
5. If the running build is lower than `minSupportedVersionCode` (or `forceUpdate == true`), the dialog cannot be dismissed until the update finishes.

## Firestore document shape

Collection: `app_updates`
Document: `android`

```jsonc
{
  "latestVersionCode": 105,
  "latestVersionName": "1.5.0",
  "minSupportedVersionCode": 101,
  "apkUrl": "https://firebasestorage.googleapis.com/v0/b/<bucket>/o/releases%2Fvanmerchant-105.apk?alt=media&token=<signed-token>",
  "releaseNotes": "- เพิ่มระบบเพื่อนใหม่\n- ปรับปรุงความเร็ว",
  "sizeBytes": 73400320,
  "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "forceUpdate": false,
  "updatedAt": 1731648000
}
```

**Fields**
- `latestVersionCode` *(required)*: must match `versionCode`/`buildNumber` from `flutter build apk` (integer part after the `+` in `pubspec.yaml`).
- `latestVersionName`: free-form display string shown to users.
- `minSupportedVersionCode`: the oldest build that is still allowed to run. Anything lower triggers a mandatory update.
- `apkUrl` *(required)*: **download URL** of the APK stored in Firebase Storage. Use a long-lived download token or Cloud Storage signed URL.
- `releaseNotes`: optional multiline text rendered in the dialog.
- `sizeBytes`: optional integer for nicer size display.
- `sha256`: optional checksum (recommended). Run `CertUtil -hashfile app-release.apk SHA256` to generate.
- `forceUpdate`: set to `true` to require an update even if `minSupportedVersionCode` is equal to the running build.
- `updatedAt`: optional timestamp for your own tracking.

## Publishing a new version

1. Build the signed APK: `flutter build apk --release`.
2. Upload the resulting `build/app/outputs/flutter-apk/app-release.apk` to Firebase Storage (e.g., folder `releases/`). Copy the HTTPS download link.
3. (Optional) Compute the SHA-256 checksum and note the file size in bytes.
4. Update Firestore document `app_updates/android` with the new metadata. Make sure `latestVersionCode` increments and matches the APK.
5. Share the new version with internal testers. On the next app launch, they will see the update dialog immediately.

## Runtime behavior

- **Optional update**: users can tap “ภายหลัง” to continue. The dialog reappears on the next cold start until they update.
- **Mandatory update**: triggered when current build `< minSupportedVersionCode` or `forceUpdate == true`. The dialog cannot be dismissed and the rest of the app is blocked.
- **Progress & errors**: download progress is displayed inside the dialog. If Android blocks the installation because installing from unknown sources is disabled, users get a snackbar with instructions to enable the permission for “Van Merchant.”

## Android permissions

The manifest now requests `android.permission.REQUEST_INSTALL_PACKAGES` so Android 8+ allows the in-app installer to launch. Users still need to grant the “Install unknown apps” permission the first time; Android automatically shows the system prompt.

## Tips

- Keep `app_updates/android` secured: restrict write access to administrators (e.g., via Firestore security rules).
- Prefer storing APKs in a dedicated `releases/` folder with read-only signed URLs that expire after a reasonable duration if distributed publicly.
- To roll back a faulty build, simply point the Firestore document back to the previous APK.
- Consider logging update attempts (success/error) via Analytics for better observability.

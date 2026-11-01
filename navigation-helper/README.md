# Navigation helper

This is the complete source for the included [navigation-helper-1.0.apk](../artifacts/navigation-helper-1.0.apk).

The app sends `android.intent.action.SHOW_NAVIGATION_BAR` to the stock `com.android.systemui` after `BOOT_COMPLETED`, then retries once about 15 seconds later. Opening its icon performs the same action immediately. No root, network, account, storage, accessibility, or overlay permission is requested. Its sole permission is `RECEIVE_BOOT_COMPLETED`.

## Install and activate

```powershell
Get-FileHash ..\artifacts\navigation-helper-1.0.apk -Algorithm SHA256
adb install -r ..\artifacts\navigation-helper-1.0.apk
adb shell am start -n org.myxunlock.navigation/.MainActivity
```

Compare the hash with [SHA256SUMS.txt](../artifacts/SHA256SUMS.txt). Open the app once so Android clears its just-installed stopped state and permits boot events. Leave it enabled. Force-stopping it prevents boot events until it is opened again. An app can still enter full-screen mode later; this helper is not a permanent block against immersive UI.

The included APK was installed and tested through a real reboot on MYX215A Android 8.1. The navigation bar was visible afterward without sending a manual command.

## Build locally on Windows

Install a JDK that provides `java`, `javac`, `jar`, and `keytool` on PATH. The tested JDK was 21. The script obtains pinned SDK/build dependencies from Google's servers into ignored `.tools/`:

```powershell
.\build.ps1
```

Output: `build/navigation-helper.apk`. The script generates a local signing key under `.local-signing/` for repeat builds. Never publish that private key. Its password is only a local build convenience and is not a security boundary.

This repository does not include the private key used for the tested APK. A locally rebuilt APK will have a different signing certificate, so uninstall the prebuilt helper before installing your own build. You lose no settings because the helper has no persistent configuration.

## Source and artifact identity

- [AndroidManifest.xml](./AndroidManifest.xml): package `org.myxunlock.navigation`, minimum API 23, target API 27.
- [BootReceiver.java](./src/org/myxunlock/navigation/BootReceiver.java): boot event and one retry.
- [MainActivity.java](./src/org/myxunlock/navigation/MainActivity.java): manual activation and explanation.
- [SignApk.java](./SignApk.java): local APK signer using Google's `apksig` library.
- Published APK signer SHA-256: `bde7cc46206c62abee52550e324e167d0a3f6109f77a7bb3decd0b861df015fc`.

Rebuilding need not produce byte-identical APKs because generated keys, signatures, and ZIP timestamps differ. This is a source-available local build, not an independently audited or reproducible-build certification.

## Remove

Uninstall **Navigation helper** in Settings, or run `adb uninstall org.myxunlock.navigation`.

# Publishing this folder

Only publish this repository folder. The parent working directory contains private backups, device identifiers, firmware dumps, APK downloads, screenshots, and full conversation logs.

Before pushing:

```powershell
git status --short --untracked-files=all
git ls-files
```

The intended contents are documentation, generic scripts, helper source, and `artifacts/navigation-helper-1.0.apk` with its checksum. Do not add serial numbers, account data, Wi-Fi details, MAC addresses, on-device policy XML, firmware images, helper private signing keys, or debugging logs.

`.gitignore` excludes common private outputs, but does not sanitize files or remove previously committed data. Review what you stage. The shared XML is only the helper's public Android manifest, not a device configuration backup.

The helper is locally signed. Its signing certificate is public information; the private signing key is not included. A rebuild using a different key cannot update the included APK in place: uninstall the existing helper first, then install the rebuilt version and open it once.

No third-party software binaries are redistributed other than our own helper. Obtain platform-tools and optional app stores directly from their official projects. The generated decorative wallpaper is not required and is not included.

Create a GitHub repository when ready, then commit and push from **this directory**. Do not set a remote or push the parent workspace. No remote is configured and nothing has been published by preparing these files.

The owner has licensed the original documentation, scripts, navigation-helper source, and included helper APK under the [MIT License](../LICENSE). Preserve the license notice when redistributing them. Third-party tools, Android firmware, and external apps retain their respective licenses; this repository's license does not relicense those dependencies.

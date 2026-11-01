# Evidence and test scope

## Verified on the original tablet

1. Root ADB in Chinese factory mode (`uid=0`, permissive SELinux, mounted data partition).
2. Original configuration files backed up and byte-for-byte hashes compared with the device.
3. The five documented XML transformations applied offline; output hashes matched local replacements.
4. Normal boot into the stock launcher, Developer options accessible, normal ADB after enabling debugging and reconnecting.
5. All four target apps disabled. Two persistent system agents also hidden. After reboot, none of the four processes appeared in `ps`.
6. Built-in navigation restored using the vendor System UI broadcast.
7. The distributed helper APK installed and launched; a subsequent real reboot restored a visible navigation bar without a manual show broadcast. No helper crash was recorded.

The included APK is the exact local build used for that test. Check its hash in [SHA256SUMS.txt](../artifacts/SHA256SUMS.txt).

## Portable-script validation

The published scripts are a generalized version of the successful owner-specific commands. Synthetic fixtures check preservation of unrelated XML, removal of intended kiosk fields, dynamic checksum generation, unexpected-owner rejection, and repeat-run protection. They are not evidence of a second physical-device unlock.

All PowerShell scripts passed parser checks. Both Android shell templates passed `bash -n`. The standalone navigation helper build completed and its generated APK passed signature verification for Android 8.1. The distributable artifact remains the original APK tested on the tablet, not the rebuild with a new signing key.

The generic rollback script is provided and reviewed, but a full restore back into the kiosk has not been executed on the working tablet. It relies on your own pre-change snapshots. Rollback is not guaranteed after factory reset, storage failure, or a firmware update.

## Still unverified

- A second tablet, another firmware build, and a clean Windows USB-driver setup.
- A deliberate repeat test of the owner's recalled factory-menu sequence: connect power, hold all three buttons about 5–10 seconds, release Power, and keep both volume buttons held until the Chinese menu appears. The owner clarified that computer micro-USB was connected afterward, accompanied by the Windows USB connection sound. Exact button timing and clean-computer driver requirements remain unverified.
- Long-term behavior across updates, power failures, and factory resets.
- Bootloader unlock, a newer Android ROM, Google Play certification, and full Google services integration.

Do not describe this as a universal bootloader unlock or claim that all hardware features and third-party apps have been validated.

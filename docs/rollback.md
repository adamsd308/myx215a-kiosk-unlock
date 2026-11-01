# Rollback

Rollback restores the original kiosk restrictions. It is not a firmware flash and does not uninstall apps added after kiosk removal. Restoring a snapshot can revert Android settings and app-state preferences changed since that snapshot.

The generic rollback scripts have not been exercised through a full return to the kiosk on the working tablet. Keep both computer-side backups and the on-device snapshot. Do not promise recovery if storage is damaged, factory-reset, or replaced by other firmware.

## Restore offline configuration

Return to Chinese factory mode, connect root ADB, and verify `system_server` is absent. **Never restore these XML files while normal Android is running.**

If the on-device original snapshot from the published apply script still exists:

```powershell
adb root
adb shell id
adb shell pidof system_server
adb shell sh /data/local/tmp/myx-kiosk-unlock/rollback.sh
adb reboot
```

If that snapshot is gone, restore your own verified computer-side backup:

```powershell
.\scripts\Restore-Factory.ps1 -Serial YOUR_SERIAL -BackupDirectory .\private\original
adb -s YOUR_SERIAL reboot
```

This restores the five original XML files and saved USB property. It does not restore `packages.xml`, flash partitions, or erase user data. A factory-mode path and readable existing target files are required. Restoration is not power-loss transactional across all five files; do not interrupt USB or tablet power while files are being restored.

## Re-enable individual apps

To reverse only the later app disable/hide step, use normal Android with root ADB:

```powershell
adb root
adb shell pm unhide --user 0 com.abupdate.mdm
adb shell pm unhide --user 0 com.adups.fota
adb shell pm enable --user 0 com.myxfitness.app
adb shell pm enable --user 0 com.beachbody.bod.bike
adb shell pm enable --user 0 com.abupdate.mdm
adb shell pm enable --user 0 com.adups.fota
```

Re-enabling the MDM/updater can restart provisioning and restrictions. This alone does not restore the removed owner and policy XML; use the factory-mode snapshot restore for that.

## Remove automatic navigation restoration

```powershell
adb uninstall org.myxunlock.navigation
```

That removes only the helper. It does not undo kiosk removal or erase other apps.

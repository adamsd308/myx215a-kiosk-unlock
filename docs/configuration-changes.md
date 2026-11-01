# Configuration changes

The successful procedure changes five files under `/data`, while factory mode has mounted that partition and normal Android's `system_server` is absent. Editing these while the framework is running can be overwritten by cached state and is not supported by these scripts.

| File | Change |
| --- | --- |
| `/data/system/device_owner_2.xml` | Remove the MDM device-owner and owner-context records, keeping the root XML element. |
| `/data/system/device_policies.xml` | Remove the MDM admin, forced lock-task components, and disabled-status-bar record. |
| `/data/system/users/0/package-restrictions.xml` | Disable and stop `com.abupdate.mdm`, enable the stock launcher, remove MDM persistent preferred HOME activities. |
| `/data/system/users/0.xml` | Clear the device-policy restriction groups belonging to the removed owner; retain ordinary base user restrictions. |
| `/data/system/users/0/settings_global.xml` | Set `adb_enabled` and `development_settings_enabled` to `1`. |

The original `persist.sys.usb.config` property is recorded, then set to `adb`. Even so, normal-mode USB debugging needed enabling/reconnecting through Settings on the tested tablet. The scripts make no guarantee of unattended ADB after reboot.

The preparation script refuses a different device owner, additional admins, unexpected policy restrictions, and missing package records. This is intentional: it is not a generic enterprise-management removal utility.

The preparation output contains your private settings. Generated shell scripts use hashes from that device's original files, not fixed hashes from the first tablet. On-device originals remain under `/data/local/tmp/myx-kiosk-unlock/originals`; the computer backup is still required because `/data/local/tmp` can be cleared.

MYX/BODi disablement and hidden vendor-agent states are applied later through the package manager in normal Android. These steps retain all app data and can be reversed; see [rollback](./rollback.md).

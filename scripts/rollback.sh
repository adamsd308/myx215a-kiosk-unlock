#!/system/bin/sh
set -eu
stage=/data/local/tmp/myx-kiosk-unlock
test "$(id -u)" = 0
test "$(getprop ro.product.model)" = MYX215A
test -e "$stage/originals/complete"
if pidof system_server >/dev/null 2>&1; then echo 'Return to factory mode before rollback'; exit 1; fi
restore_file() {
    target="$1"; name="$2"
    cp -p "$stage/originals/$name" "$target.myx-restore"
    mv -f "$target.myx-restore" "$target"
    restorecon "$target"
    cmp "$stage/originals/$name" "$target"
}
restore_file /data/system/device_owner_2.xml device_owner_2.xml
restore_file /data/system/device_policies.xml device_policies.xml
restore_file /data/system/users/0/package-restrictions.xml package-restrictions.xml
restore_file /data/system/users/0.xml user-0.xml
restore_file /data/system/users/0/settings_global.xml settings_global.xml
setprop persist.sys.usb.config "$(cat "$stage/originals/usb-config")"
sync
echo 'Original configuration restored. Reboot explicitly when ready.'

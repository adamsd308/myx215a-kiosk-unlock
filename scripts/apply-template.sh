#!/system/bin/sh
set -eu
stage=/data/local/tmp/myx-kiosk-unlock
test "$(id -u)" = 0
test "$(getprop ro.product.model)" = MYX215A
if pidof system_server >/dev/null 2>&1; then echo 'Refusing edit with Android framework running'; exit 1; fi
test ! -e "$stage/originals/complete"
mkdir -p "$stage/originals"
save_file() {
    file="$1"; name="$2"; expected="$3"
    actual=$(sha256sum "$file"); actual=${actual%% *}
    test "$actual" = "$expected"
    cp -p "$file" "$stage/originals/$name"
}
__SAVE_FILES__
getprop persist.sys.usb.config > "$stage/originals/usb-config"
touch "$stage/originals/complete"
trap 'sh "$stage/rollback.sh"' HUP INT TERM EXIT
replace_file() {
    target="$1"; name="$2"
    test ! -e "$target.myx-new"
    cp -p "$target" "$target.myx-new"
    cat "$stage/$name" > "$target.myx-new"
    mv -f "$target.myx-new" "$target"
    restorecon "$target"
    cmp "$stage/$name" "$target"
}
replace_file /data/system/device_owner_2.xml device_owner_2.xml
replace_file /data/system/device_policies.xml device_policies.xml
replace_file /data/system/users/0/package-restrictions.xml package-restrictions.xml
replace_file /data/system/users/0.xml user-0.xml
replace_file /data/system/users/0/settings_global.xml settings_global.xml
setprop persist.sys.usb.config adb
sync
trap - HUP INT TERM EXIT
echo 'Configuration applied and verified. Originals retained. No automatic reboot.'

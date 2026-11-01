# Offline tests only. Never contacts a tablet and contains no real device configuration.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('myx-kiosk-tests-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $testRoot 'original'
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$fixtures = @{
    'device_owner_2.xml' = '<root><device-owner package="com.abupdate.mdm" component="com.abupdate.mdm/com.abupdate.mdm.receiver.DeviceOwnerReceiver"/><device-owner-context userId="0"/></root>'
    'device_policies.xml' = '<policies setup-complete="true"><admin name="com.abupdate.mdm/com.abupdate.mdm.receiver.DeviceOwnerReceiver"><policies flags="991"/></admin><lock-task-component name="com.abupdate.mdm"/><statusbar disabled="true"/><password-validity value="true"/></policies>'
    'package-restrictions.xml' = '<package-restrictions><pkg name="com.abupdate.mdm"/><pkg name="com.android.launcher3"/><pkg name="example.keep" enabled="2"/><persistent-preferred-activities><item name="com.abupdate.mdm/.activity.CheckActivity"/><item name="example.keep/.Home"/></persistent-preferred-activities></package-restrictions>'
    'user-0.xml' = '<user id="0"><restrictions no_add_user="true"/><device_policy_restrictions no_debugging_features="true"/><device_policy_global_restrictions no_usb_file_transfer="true"/></user>'
    'settings_global.xml' = '<settings version="1"><setting id="1" name="device_provisioned" value="1"/><setting id="2" name="adb_enabled" value="0"/></settings>'
}
foreach ($name in $fixtures.Keys) { Write-Utf8File "$backup/$name" $fixtures[$name] }
Write-Utf8File "$backup/usb-config.txt" "none`n"
function Save-TestManifest {
    $records = @()
    foreach ($entry in (Get-ConfigurationMap).GetEnumerator()) {
        $records += @{name=$entry.Key;remotePath=$entry.Value;sha256=(Get-FileHash "$backup/$($entry.Key)").Hash.ToLowerInvariant()}
    }
    Write-Utf8File "$backup/backup-manifest.json" (@{schemaVersion=1;model='MYX215A';androidVersion='8.1.0';usbConfig='none';files=$records} | ConvertTo-Json -Depth 6)
}
function Assert-True { param([bool]$Condition,[string]$Message); if (!$Condition) { throw $Message } }
Save-TestManifest
$prepared = Join-Path $testRoot 'prepared'
& "$PSScriptRoot/Prepare-KioskRemoval.ps1" -BackupDirectory $backup -OutputDirectory $prepared
[xml]$owner = Get-Content "$prepared/device_owner_2.xml"
Assert-True ($owner.SelectNodes('/root/device-owner').Count -eq 0) 'Owner was not removed'
[xml]$policies = Get-Content "$prepared/device_policies.xml"
Assert-True ($policies.SelectNodes('/policies/admin | /policies/statusbar | /policies/lock-task-component').Count -eq 0) 'Kiosk policies remain'
Assert-True ($null -ne $policies.SelectSingleNode('/policies/password-validity')) 'Unrelated policy lost'
[xml]$packages = Get-Content "$prepared/package-restrictions.xml"
Assert-True ($packages.SelectSingleNode('/package-restrictions/pkg[@name="com.abupdate.mdm"]').GetAttribute('enabled') -eq '3') 'MDM not disabled'
Assert-True ($packages.SelectSingleNode('/package-restrictions/pkg[@name="example.keep"]').GetAttribute('enabled') -eq '2') 'Unrelated package changed'
Assert-True ($packages.SelectNodes('/package-restrictions/persistent-preferred-activities/item').Count -eq 1) 'Preferred activities incorrectly removed'
[xml]$user = Get-Content "$prepared/user-0.xml"
Assert-True ($user.SelectSingleNode('/user/restrictions').GetAttribute('no_add_user') -eq 'true') 'Base restriction lost'
Assert-True ($user.SelectSingleNode('/user/device_policy_restrictions').Attributes.Count -eq 0) 'Device restriction not cleared'
[xml]$settings = Get-Content "$prepared/settings_global.xml"
Assert-True ($settings.SelectSingleNode('/settings/setting[@name="adb_enabled"]').GetAttribute('value') -eq '1') 'ADB setting not enabled'
Assert-True ($settings.SelectNodes('/settings/setting[@name="adb_enabled"]').Count -eq 1) 'Duplicate setting created'
Assert-True ($settings.SelectSingleNode('/settings/setting[@name="device_provisioned"]').GetAttribute('value') -eq '1') 'Provisioning changed'
$shell = Get-Content -Raw "$prepared/apply.sh"
Assert-True (!$shell.Contains('__SAVE_FILES__')) 'Hash template unresolved'
Assert-True ($shell.Contains((Get-FileHash "$backup/device_owner_2.xml").Hash.ToLowerInvariant())) 'Device-specific hash missing'
Assert-True (!$shell.Contains("`r")) 'Android script has CRLF line endings'

$rejected = $false
try { & "$PSScriptRoot/Prepare-KioskRemoval.ps1" -BackupDirectory $backup -OutputDirectory $prepared } catch { $rejected = $true }
Assert-True $rejected 'Existing output was overwritten'
Write-Utf8File "$backup/device_owner_2.xml" '<root><device-owner package="example.other"/></root>'
Save-TestManifest
$rejected = $false
try { & "$PSScriptRoot/Prepare-KioskRemoval.ps1" -BackupDirectory $backup -OutputDirectory "$testRoot/unexpected-owner" } catch { $rejected = $true }
Assert-True $rejected 'Unexpected owner was accepted'
Assert-True (!(Test-Path "$testRoot/unexpected-owner")) 'Rejected config produced output'
Write-Utf8File "$backup/device_owner_2.xml" $fixtures['device_owner_2.xml']
# Deliberately do not rehash after replacing the file.
$rejected = $false
try { & "$PSScriptRoot/Prepare-KioskRemoval.ps1" -BackupDirectory $backup -OutputDirectory "$testRoot/tampered-backup" } catch { $rejected = $true }
Assert-True $rejected 'Backup hash mismatch was ignored'
Write-Output "PASS: transformations, preserved state, dynamic hashes, LF output, repeat protection, owner guard, checksum guard. Synthetic fixtures: $testRoot"

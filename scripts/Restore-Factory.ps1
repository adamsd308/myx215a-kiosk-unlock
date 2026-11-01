[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Serial,
    [Parameter(Mandatory=$true)][string]$BackupDirectory,
    [string]$AdbPath='adb'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
Initialize-Adb -AdbPath $AdbPath -Serial $Serial
Assert-FactoryRoot
$backup = (Resolve-Path -LiteralPath $BackupDirectory).Path
$manifest = Get-Content -Raw -LiteralPath "$backup/backup-manifest.json" | ConvertFrom-Json
if ($manifest.model -ne 'MYX215A' -or $manifest.schemaVersion -ne 1 -or $manifest.androidVersion -ne '8.1.0') { throw 'Unexpected backup manifest.' }
if ($manifest.usbConfig -notmatch '^[a-zA-Z0-9_,.-]*$') { throw 'Invalid saved USB configuration.' }
if ((Get-Content -Raw -LiteralPath "$backup/usb-config.txt").Trim() -ne $manifest.usbConfig) { throw 'Saved USB property does not match the backup manifest.' }
$map = Get-ConfigurationMap
foreach ($entry in $map.GetEnumerator()) {
    $records = @($manifest.files | Where-Object { $_.name -eq $entry.Key -and $_.remotePath -eq $entry.Value })
    if ($records.Count -ne 1 -or $records[0].sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Incomplete backup manifest.' }
    if ((Get-FileHash (Join-Path $backup $entry.Key) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $records[0].sha256) { throw "Backup hash mismatch: $($entry.Key)" }
}
$stage = '/data/local/tmp/myx-kiosk-unlock-restore'
Write-Output (Invoke-TargetAdb -Arguments @('shell','mkdir','-p',"$stage/originals"))
foreach ($entry in $map.GetEnumerator()) { Write-Output (Invoke-TargetAdb -Arguments @('push',(Join-Path $backup $entry.Key),"$stage/originals/$($entry.Key)")) }
Write-Output (Invoke-TargetAdb -Arguments @('push',"$backup/usb-config.txt","$stage/originals/usb-config"))
$temporaryScript = Join-Path ([System.IO.Path]::GetTempPath()) ('myx-restore-' + [guid]::NewGuid().ToString('N') + '.sh')
$restore = (Get-Content -Raw -LiteralPath "$PSScriptRoot/rollback.sh").Replace('stage=/data/local/tmp/myx-kiosk-unlock',"stage=$stage")
Write-Utf8File -Path $temporaryScript -Content $restore
Write-Output (Invoke-TargetAdb -Arguments @('push',$temporaryScript,"$stage/rollback.sh"))
# Verify the transfer before allowing restore. No automatic reboot.
foreach ($entry in $map.GetEnumerator()) {
    $actual = ((Invoke-TargetAdb -Arguments @('shell','sha256sum',"$stage/originals/$($entry.Key)")).Trim() -split '\s+')[0]
    if ($actual.ToLowerInvariant() -ne (Get-FileHash (Join-Path $backup $entry.Key) -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'Restore upload verification failed.' }
}
Write-Output (Invoke-TargetAdb -Arguments @('shell','touch',"$stage/originals/complete"))
Write-Output (Invoke-TargetAdb -Arguments @('shell','sh',"$stage/rollback.sh"))
Write-Output 'Original configuration restored. Installed apps are not uninstalled. Reboot explicitly when ready.'

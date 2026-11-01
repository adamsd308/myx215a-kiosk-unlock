[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Serial,
    [Parameter(Mandatory=$true)][string]$BackupDirectory,
    [string]$AdbPath = 'adb'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
if (Test-Path $BackupDirectory) { throw 'Use a new backup directory; existing backups will not be overwritten.' }
Initialize-Adb -AdbPath $AdbPath -Serial $Serial
Assert-FactoryRoot
$directory = [System.IO.Path]::GetFullPath($BackupDirectory)
New-Item -ItemType Directory -Path $directory | Out-Null
$files = @()
foreach ($entry in (Get-ConfigurationMap).GetEnumerator()) {
    Write-Output (Invoke-TargetAdb -Arguments @('pull',$entry.Value,(Join-Path $directory $entry.Key)))
    $remoteHash = Invoke-TargetAdb -Arguments @('shell','sha256sum',$entry.Value)
    $expected = ($remoteHash.Trim() -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash (Join-Path $directory $entry.Key) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expected -notmatch '^[0-9a-f]{64}$' -or $expected -ne $actual) { throw "Backup verification failed: $($entry.Key)" }
    $files += @{ name=$entry.Key; remotePath=$entry.Value; sha256=$actual }
}
$usb = (Invoke-TargetAdb -Arguments @('shell','getprop','persist.sys.usb.config')).Trim()
if ($usb -notmatch '^[a-zA-Z0-9_,.-]*$') { throw 'Unexpected USB configuration value.' }
Write-Utf8File -Path "$directory/usb-config.txt" -Content ($usb + "`n")
$manifest = @{
    schemaVersion=1
    model='MYX215A'
    androidVersion='8.1.0'
    buildIncremental=(Invoke-TargetAdb -Arguments @('shell','getprop','ro.build.version.incremental')).Trim()
    usbConfig=$usb
    files=$files
}
Write-Utf8File -Path "$directory/backup-manifest.json" -Content ($manifest | ConvertTo-Json -Depth 6)
Write-Output "Verified private backup saved to $directory. Do not publish it."

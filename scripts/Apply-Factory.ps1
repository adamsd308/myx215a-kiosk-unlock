[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Serial,
    [Parameter(Mandatory=$true)][string]$PreparedDirectory,
    [string]$AdbPath = 'adb'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
Initialize-Adb -AdbPath $AdbPath -Serial $Serial
Assert-FactoryRoot
$prepared = (Resolve-Path -LiteralPath $PreparedDirectory).Path
$stage = '/data/local/tmp/myx-kiosk-unlock'
$required = @((Get-ConfigurationMap).Keys) + @('apply.sh','rollback.sh','source-manifest.json')
foreach ($name in $required) { if (!(Test-Path -LiteralPath (Join-Path $prepared $name) -PathType Leaf)) { throw "Missing prepared file: $name" } }
$active = Invoke-TargetAdb -Arguments @('shell','sh','-c', "'if test -e $stage/originals/complete; then echo EXISTS; else echo ABSENT; fi'")
if ($active.Trim() -ne 'ABSENT') { throw 'An on-device snapshot already exists. Refusing to overwrite or repeat the transaction.' }
Write-Output (Invoke-TargetAdb -Arguments @('shell','mkdir','-p',$stage))
foreach ($name in $required) { Write-Output (Invoke-TargetAdb -Arguments @('push',(Join-Path $prepared $name),"$stage/$name")) }
Write-Output (Invoke-TargetAdb -Arguments @('shell','sh','-n',"$stage/apply.sh"))
Write-Output (Invoke-TargetAdb -Arguments @('shell','sh','-n',"$stage/rollback.sh"))
Write-Output (Invoke-TargetAdb -Arguments @('shell','sh',"$stage/apply.sh"))
foreach ($entry in (Get-ConfigurationMap).GetEnumerator()) {
    $remote = Invoke-TargetAdb -Arguments @('shell','sha256sum',$entry.Value)
    $hash = ($remote.Trim() -split '\s+')[0].ToLowerInvariant()
    if ($hash -ne (Get-FileHash (Join-Path $prepared $entry.Key) -Algorithm SHA256).Hash.ToLowerInvariant()) {
        throw "Post-apply verification failed for $($entry.Key). Remain in factory mode and inspect rollback."
    }
}
Write-Output 'Applied and verified. Reboot explicitly when ready. Keep your computer-side backup.'

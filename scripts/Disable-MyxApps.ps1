[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Serial, [string]$AdbPath='adb')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
Initialize-Adb -AdbPath $AdbPath -Serial $Serial
$boot = Invoke-TargetAdb -Arguments @('shell','getprop','sys.boot_completed')
if ($boot.Trim() -ne '1') { throw 'Run this package-manager step after normal Android has finished booting.' }
$identity = Invoke-TargetAdb -Arguments @('shell','id')
if ($identity -notmatch 'uid=0\(root\)') {
    Write-Output (Invoke-TargetAdb -Arguments @('root'))
    Write-Output 'ADB was restarted as root. Reconnect if needed, then run this script again.'
    return
}
foreach ($package in @('com.myxfitness.app','com.beachbody.bod.bike','com.abupdate.mdm','com.adups.fota')) {
    $installed = Invoke-TargetAdb -Arguments @('shell','pm','list','packages','-u',$package)
    if ($installed.Trim() -notmatch ('(?m)^package:' + [regex]::Escape($package) + '$')) { throw "Expected package not found: $package" }
    Write-Output (Invoke-TargetAdb -Arguments @('shell','pm','disable-user','--user','0',$package))
    Write-Output (Invoke-TargetAdb -Arguments @('shell','am','force-stop','--user','0',$package))
}
foreach ($package in @('com.abupdate.mdm','com.adups.fota')) {
    $result = Invoke-TargetAdb -Arguments @('shell','pm','hide','--user','0',$package)
    Write-Output $result
    if ($result -notmatch 'hidden state: true') { throw "Failed to hide $package; do not assume its persistent startup is stopped." }
}
Write-Output 'Apps disabled; persistent agents hidden. Reboot explicitly, reconnect, and verify ps -A before declaring success.'

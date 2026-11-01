function Initialize-Adb {
    param([string]$AdbPath, [string]$Serial)
    if ([string]::IsNullOrWhiteSpace($Serial) -or $Serial -match '[\s\x00]') { throw 'Pass the exact device serial with -Serial.' }
    $command = Get-Command $AdbPath -ErrorAction Stop
    $script:AdbExecutable = $command.Source
    $script:AdbSerial = $Serial
    $state = Invoke-TargetAdb -Arguments @('get-state')
    if ($state.Trim() -ne 'device') { throw 'Target is not in the connected ADB device state.' }
    $model = Invoke-TargetAdb -Arguments @('shell','getprop','ro.product.model')
    if ($model.Trim() -ne 'MYX215A') { throw "Unexpected model: $model. Stop and inspect your device." }
}

function Invoke-TargetAdb {
    param([string[]]$Arguments)
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $script:AdbExecutable -s $script:AdbSerial @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    $text = ($output | ForEach-Object { $_.ToString() }) -join "`n"
    if ($exitCode -ne 0) { throw "ADB command failed ($exitCode): $text" }
    return $text
}

function Assert-FactoryRoot {
    $identity = Invoke-TargetAdb -Arguments @('shell','id')
    if ($identity -notmatch 'uid=0\(root\)') { throw 'Root ADB required. Run adb root in factory mode, reconnect, then retry.' }
    # pidof returns 1 when the process is absent; use a shell script with an explicit success exit.
    $running = Invoke-TargetAdb -Arguments @('shell','sh','-c', "'if pidof system_server >/dev/null 2>&1; then echo RUNNING; else echo ABSENT; fi'")
    if ($running.Trim() -ne 'ABSENT') { throw 'Android framework is running or mode is unknown; offline editing is refused.' }
    $version = Invoke-TargetAdb -Arguments @('shell','getprop','ro.build.version.release')
    if ($version.Trim() -ne '8.1.0') { throw 'Only the documented Android 8.1.0 layout is supported.' }
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $normalized = $Content.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-ConfigurationMap {
    return [ordered]@{
        'device_owner_2.xml' = '/data/system/device_owner_2.xml'
        'device_policies.xml' = '/data/system/device_policies.xml'
        'package-restrictions.xml' = '/data/system/users/0/package-restrictions.xml'
        'user-0.xml' = '/data/system/users/0.xml'
        'settings_global.xml' = '/data/system/users/0/settings_global.xml'
    }
}

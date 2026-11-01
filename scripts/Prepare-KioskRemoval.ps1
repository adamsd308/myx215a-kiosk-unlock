[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BackupDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$backup = (Resolve-Path -LiteralPath $BackupDirectory).Path
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Use a new preparation directory; existing output will not be overwritten.' }
$manifest = Get-Content -Raw -LiteralPath "$backup/backup-manifest.json" | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.model -ne 'MYX215A' -or $manifest.androidVersion -ne '8.1.0') { throw 'Unsupported backup manifest.' }
$map = Get-ConfigurationMap
$documents = @{}
$hashes = @{}
foreach ($entry in $map.GetEnumerator()) {
    $records = @($manifest.files | Where-Object { $_.name -eq $entry.Key -and $_.remotePath -eq $entry.Value })
    if ($records.Count -ne 1 -or $records[0].sha256 -cnotmatch '^[0-9a-f]{64}$') { throw "Invalid manifest entry: $($entry.Key)" }
    $path = Join-Path $backup $entry.Key
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $records[0].sha256) { throw "Backup hash mismatch: $($entry.Key)" }
    $hashes[$entry.Key] = $hash
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.XmlResolver = $null
    $document.Load($path)
    $documents[$entry.Key] = $document
}

$owner = $documents['device_owner_2.xml']
$owners = @($owner.SelectNodes('/root/device-owner'))
if ($owners.Count -ne 1 -or $owners[0].GetAttribute('package') -ne 'com.abupdate.mdm' -or
    $owners[0].GetAttribute('component') -ne 'com.abupdate.mdm/com.abupdate.mdm.receiver.DeviceOwnerReceiver') {
    throw 'Expected MYX MDM owner not found; refusing this device configuration.'
}
$contexts = @($owner.SelectNodes('/root/device-owner-context'))
if ($contexts.Count -ne 1 -or $contexts[0].GetAttribute('userId') -ne '0') { throw 'Expected device owner context for user 0.' }
foreach ($child in @($owner.DocumentElement.ChildNodes)) {
    if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.Name -notin @('device-owner','device-owner-context')) {
        throw 'Unexpected owner record; manual review required.'
    }
}
$policies = $documents['device_policies.xml']
$admins = @($policies.SelectNodes('/policies/admin'))
if ($admins.Count -ne 1 -or $admins[0].GetAttribute('name') -ne 'com.abupdate.mdm/com.abupdate.mdm.receiver.DeviceOwnerReceiver') {
    throw 'Unexpected device admins; refusing to remove their policies.'
}
foreach ($component in @($policies.SelectNodes('/policies/lock-task-component'))) {
    if ($component.GetAttribute('name') -ne 'com.abupdate.mdm') { throw 'Unexpected lock-task package.' }
}
$users = $documents['user-0.xml']
if ($users.DocumentElement.Name -ne 'user' -or $users.DocumentElement.GetAttribute('id') -ne '0') { throw 'Expected user 0 record missing.' }
foreach ($node in @($users.SelectNodes('/user/device_policy_restrictions | /user/device_policy_global_restrictions'))) {
    if ($node.ChildNodes.Count -gt 0) { throw 'Unexpected nested user-policy data.' }
    foreach ($attribute in @($node.Attributes)) {
        if ($attribute.Name -notin @('no_add_managed_profile','no_debugging_features','no_usb_file_transfer','no_bluetooth_sharing')) {
            throw "Unexpected user policy restriction: $($attribute.Name)"
        }
    }
}
$restrictions = $documents['package-restrictions.xml']
$mdm = $restrictions.SelectSingleNode('/package-restrictions/pkg[@name="com.abupdate.mdm"]')
$launcher = $restrictions.SelectSingleNode('/package-restrictions/pkg[@name="com.android.launcher3"]')
if ($null -eq $mdm -or $null -eq $launcher) { throw 'MDM or stock launcher package record is missing.' }
$settings = $documents['settings_global.xml']
if ($settings.DocumentElement.Name -ne 'settings' -or $policies.DocumentElement.Name -ne 'policies') { throw 'Unexpected XML root.' }

# Validation is complete before producing any output or modifying any local copy.
foreach ($child in @($owner.DocumentElement.ChildNodes)) { [void]$owner.DocumentElement.RemoveChild($child) }
foreach ($node in @($policies.SelectNodes('/policies/admin | /policies/lock-task-component | /policies/statusbar'))) { [void]$node.ParentNode.RemoveChild($node) }
$mdm.SetAttribute('enabled','3'); $mdm.SetAttribute('stopped','true')
$launcher.SetAttribute('enabled','1'); $launcher.SetAttribute('stopped','false')
foreach ($node in @($restrictions.SelectNodes('/package-restrictions/persistent-preferred-activities/item[starts-with(@name,"com.abupdate.mdm/")]'))) { [void]$node.ParentNode.RemoveChild($node) }
foreach ($node in @($users.SelectNodes('/user/device_policy_restrictions | /user/device_policy_global_restrictions'))) { $node.RemoveAll() }
$ids = @($settings.SelectNodes('/settings/setting') | ForEach-Object { [int]$_.GetAttribute('id') })
$nextId = 1
if ($ids.Count -gt 0) { $nextId = 1 + ($ids | Measure-Object -Maximum).Maximum }
foreach ($name in @('adb_enabled','development_settings_enabled')) {
    $nodes = @($settings.SelectNodes("/settings/setting[@name='$name']"))
    if ($nodes.Count -gt 1) { throw 'Duplicate Android setting; manual review required.' }
    if ($nodes.Count -eq 0) {
        $node = $settings.CreateElement('setting')
        $node.SetAttribute('name',$name); $node.SetAttribute('id',[string]$nextId); $nextId++
        $node.SetAttribute('package','com.android.shell'); [void]$settings.DocumentElement.AppendChild($node)
    } else { $node = $nodes[0] }
    $node.SetAttribute('value','1')
}
New-Item -ItemType Directory -Path $output | Out-Null
foreach ($entry in $map.GetEnumerator()) { Write-Utf8File -Path (Join-Path $output $entry.Key) -Content $documents[$entry.Key].OuterXml }
$apply = Get-Content -Raw -LiteralPath "$PSScriptRoot/apply-template.sh"
$saveLines = @()
foreach ($entry in $map.GetEnumerator()) { $saveLines += "save_file $($entry.Value) $($entry.Key) $($hashes[$entry.Key])" }
$apply = $apply.Replace('__SAVE_FILES__', ($saveLines -join "`n"))
Write-Utf8File -Path "$output/apply.sh" -Content $apply
Write-Utf8File -Path "$output/rollback.sh" -Content (Get-Content -Raw -LiteralPath "$PSScriptRoot/rollback.sh")
Copy-Item -LiteralPath "$backup/backup-manifest.json" -Destination "$output/source-manifest.json"
Write-Output "Prepared private XML and scripts in $output. Review before applying."

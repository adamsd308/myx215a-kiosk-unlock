[CmdletBinding()]
param([string]$ToolDirectory = "$PSScriptRoot/.tools")
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$tools = [System.IO.Path]::GetFullPath($ToolDirectory)
$build = "$PSScriptRoot/build"
$signing = "$PSScriptRoot/.local-signing"
New-Item -ItemType Directory -Force -Path $tools,"$build/classes","$build/dex",$signing | Out-Null
$java = (Get-Command java -ErrorAction Stop).Source
$javac = (Get-Command javac -ErrorAction Stop).Source
$jar = (Get-Command jar -ErrorAction Stop).Source
$keytool = (Get-Command keytool -ErrorAction Stop).Source

function Invoke-Checked {
    param([string]$Executable,[string[]]$ArgumentList)
    & $Executable @ArgumentList
    if ($LASTEXITCODE -ne 0) { throw "Build command failed: $Executable" }
}
function Download-Tool {
    param([string]$Name,[string]$Url)
    if (!(Test-Path -LiteralPath "$tools/$Name")) {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile "$tools/$Name"
    }
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (!(Test-Path "$tools/android-27.jar")) {
    Download-Tool platform-27_r03.zip 'https://dl.google.com/android/repository/platform-27_r03.zip'
    $zip = [System.IO.Compression.ZipFile]::OpenRead("$tools/platform-27_r03.zip")
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -match '/android\.jar$' } | Select-Object -First 1
        if ($null -eq $entry) { throw 'SDK archive has no android.jar' }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry,"$tools/android-27.jar",$true)
    } finally { $zip.Dispose() }
}
if (!(Test-Path "$tools/aapt2.exe")) {
    Download-Tool aapt2-windows.jar 'https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/8.7.3-12006047/aapt2-8.7.3-12006047-windows.jar'
    $zip = [System.IO.Compression.ZipFile]::OpenRead("$tools/aapt2-windows.jar")
    try { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry('aapt2.exe'),"$tools/aapt2.exe",$true) }
    finally { $zip.Dispose() }
}
Download-Tool r8.jar 'https://dl.google.com/dl/android/maven2/com/android/tools/r8/8.7.18/r8-8.7.18.jar'
Download-Tool apksig-8.7.3.jar 'https://dl.google.com/dl/android/maven2/com/android/tools/build/apksig/8.7.3/apksig-8.7.3.jar'
$android = "$tools/android-27.jar"
$apkSig = "$tools/apksig-8.7.3.jar"
Invoke-Checked $javac @('-source','8','-target','8','-bootclasspath',$android,'-d',"$build/classes",
    "$PSScriptRoot/src/org/myxunlock/navigation/BootReceiver.java", "$PSScriptRoot/src/org/myxunlock/navigation/MainActivity.java")
Invoke-Checked $jar @('cf',"$build/classes.jar",'-C',"$build/classes",'.')
Invoke-Checked $java @('-cp',"$tools/r8.jar",'com.android.tools.r8.D8','--lib',$android,'--min-api','23','--output',"$build/dex", "$build/classes.jar")
Invoke-Checked "$tools/aapt2.exe" @('link','-I',$android,'--manifest',"$PSScriptRoot/AndroidManifest.xml",'-o',"$build/unsigned.apk")
$zip = [System.IO.Compression.ZipFile]::Open("$build/unsigned.apk",[System.IO.Compression.ZipArchiveMode]::Update)
try { [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,"$build/dex/classes.dex",'classes.dex') }
finally { $zip.Dispose() }
$key = "$signing/helper.p12"
if (!(Test-Path $key)) {
    Invoke-Checked $keytool @('-genkeypair','-alias','navigation-helper','-keyalg','RSA','-keysize','2048',
        '-validity','3650','-dname','CN=MYX Navigation Helper Local Build','-keystore',$key,'-storetype','PKCS12',
        '-storepass','local-build-only','-keypass','local-build-only')
}
Invoke-Checked $java @('--class-path',$apkSig,"$PSScriptRoot/SignApk.java",$key,"$build/unsigned.apk","$build/navigation-helper.apk")
Invoke-Checked $java @('--class-path',$apkSig,"$PSScriptRoot/VerifyApk.java","$build/navigation-helper.apk")
Get-FileHash "$build/navigation-helper.apk" -Algorithm SHA256

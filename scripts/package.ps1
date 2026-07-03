param(
    [string]$OutDir = "dist"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Version = if ($env:GITHUB_REF_NAME) { $env:GITHUB_REF_NAME } else { "local" }
$ModName = "SN2-NeverNight-UE4SS"
$InstallerName = "SN2NeverNightInstaller"
$OutPath = Join-Path $Root $OutDir

Set-Location $Root
if (Test-Path $OutPath) {
    Remove-Item -Recurse -Force $OutPath
}
New-Item -ItemType Directory -Force (Join-Path $OutPath "$ModName/NeverNight/Scripts") | Out-Null

Copy-Item (Join-Path $Root "README.md") (Join-Path $OutPath "$ModName/README.md")
Copy-Item (Join-Path $Root "NeverNight/Scripts/main.lua") (Join-Path $OutPath "$ModName/NeverNight/Scripts/main.lua")

Compress-Archive -Path (Join-Path $OutPath $ModName) -DestinationPath (Join-Path $OutPath "$ModName-$Version.zip") -Force

if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    dotnet publish (Join-Path $Root "src/SN2NeverNightInstaller/SN2NeverNightInstaller.csproj") `
        -c Release `
        -r win-x64 `
        --self-contained true `
        -p:PublishSingleFile=true `
        -p:PublishReadyToRun=false `
        -p:DebugType=none `
        -p:DebugSymbols=false `
        -o (Join-Path $OutPath $InstallerName)

    Compress-Archive -Path (Join-Path $OutPath $InstallerName) -DestinationPath (Join-Path $OutPath "$InstallerName-win-x64-$Version.zip") -Force
}

$sumPath = Join-Path $OutPath "SHA256SUMS.txt"
Remove-Item -Force $sumPath -ErrorAction SilentlyContinue
Get-ChildItem $OutPath -Filter "*.zip" | Sort-Object Name | ForEach-Object {
    $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    "$hash  $($_.Name)" | Add-Content -Encoding ascii $sumPath
}

Get-Content $sumPath

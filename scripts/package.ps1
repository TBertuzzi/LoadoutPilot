$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$VersionLine = Select-String -Path (Join-Path $Root "LoadoutPilot.toc") -Pattern '^## Version: (.+)$'
$Version = $VersionLine.Matches[0].Groups[1].Value.Trim()
$Out = Join-Path $Root "release"
$Stage = Join-Path $Out "LoadoutPilot"
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Stage | Out-Null
$Files = @("LoadoutPilot.toc","Localization.lua","Data.lua","Core.lua","CHANGELOG.md","LICENSE")
foreach ($File in $Files) { Copy-Item (Join-Path $Root $File) (Join-Path $Stage $File) }
Copy-Item (Join-Path $Root "Media") (Join-Path $Stage "Media") -Recurse
$Zip = Join-Path $Out "LoadoutPilot-v$Version-CurseForge.zip"
Compress-Archive -Path $Stage -DestinationPath $Zip
Write-Output $Zip

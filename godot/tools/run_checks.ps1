param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$Project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
# UI tests refuse to run unless the isolated test opt-in is present.
# Use a copied project with a unique application name so real saves stay separate.
$Sandbox = Join-Path $env:TEMP ("lumi-godot-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Sandbox | Out-Null
Copy-Item -Path (Join-Path $Project "*") -Destination $Sandbox -Recurse
$Config = Join-Path $Sandbox "project.godot"
(Get-Content $Config -Raw -Encoding UTF8).Replace('config/name="고양이와 커피"', ('config/name="Lumi-Isolated-' + [guid]::NewGuid().ToString("N") + '"')) | Set-Content $Config -Encoding UTF8
$env:LUMI_UI_TEST="1"
& $Godot --headless --path $Sandbox --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
foreach ($Test in @("cafe", "puzzle", "session", "garden", "screens", "ui", "review", "feedback")) {
  & $Godot --headless --path $Sandbox --script "res://tests/test_$Test.gd"
  if ($LASTEXITCODE -ne 0) { throw "$Test tests failed" }
}
Write-Host "Passed native checks in $Sandbox. APK/IPA and visual/device checks are separate."

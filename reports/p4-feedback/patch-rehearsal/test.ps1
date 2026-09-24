param([switch]$SkipSmoke)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$env:PYTHONIOENCODING = "utf-8"
$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$godotExe = & $python -c "from tools.godot_path import godot_path; print(godot_path())"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $python -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($name in @("settings", "gameplay", "fly", "pursuit", "escape", "combat_round", "weapon_view", "combat_feedback", "drone_visual", "report", "brain_view", "hud", "mobile")) {
    $arguments = @("--headless", "--path", "game", "--script", "../tests/$name.gd")
    if ($name -in @("fly", "pursuit")) { $arguments += @("--fixed-fps", "60") }
    & $godotExe @arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
if (-not $SkipSmoke) {
    & $python tools/launch.py --headless --smoke
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Write-Host "PASS: Python and headless regression suite. Smoke skipped: $SkipSmoke"

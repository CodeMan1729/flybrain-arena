$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$godotExe = (Get-ChildItem tools -Filter "Godot_v4.5.2-stable_win64.exe" | Select-Object -First 1).FullName

& .venv\Scripts\python.exe -m unittest discover -s tests -v
& $godotExe --headless --path game --script ../tests/settings.gd
& $godotExe --headless --path game --script ../tests/gameplay.gd
& $godotExe --headless --path game --script ../tests/fly.gd
& $godotExe --headless --path game --script ../tests/brain_view.gd
& $godotExe --headless --path game --script ../tests/hud.gd
& $godotExe --headless --path game --script ../tests/mobile.gd
& .\run.ps1 --headless --smoke
Write-Host "Python ve headless oynanış testleri geçti. Görünür 1080p ölçüm: .\run.ps1 --benchmark"

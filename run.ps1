$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$godotExe = Get-ChildItem tools -Filter "Godot_v4.5.2-stable_win64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not (Test-Path ".venv\Scripts\python.exe") -or -not $godotExe -or -not (Test-Path "data\weights.npz")) {
    & .\setup.ps1
}
& .venv\Scripts\python.exe tools\launch.py @args

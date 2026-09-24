# Windows port of setup.sh. Requires Python 3.12 and curl.exe (both ship with Win10+/or installed manually).
# Does not touch C:\; venv, Godot binary and data all live under this project folder on E:\.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

New-Item -ItemType Directory -Force -Path tools,data,reports,logs | Out-Null

$python = $null
foreach ($candidate in @("py -3.12", "python3.12", "python")) {
    $parts = $candidate.Split(" ")
    $exe = $parts[0]
    $exeArgs = $parts[1..($parts.Length-1)]
    try {
        $version = & $exe @exeArgs --version 2>$null
        if ($version -match "3\.12") { $python = @($exe) + $exeArgs; break }
    } catch {}
}
if (-not $python) {
    Write-Error "Python 3.12 not found. Install it from https://www.python.org/downloads/ and re-run."
}

if (-not (Test-Path ".venv\Scripts\python.exe")) {
    & $python[0] @($python[1..($python.Length-1)]) -m venv .venv
}
$venvPython = ".venv\Scripts\python.exe"
& $venvPython -m pip install --upgrade pip -q
& $venvPython -m pip install -r requirements.txt

$godotExe = Get-ChildItem tools -Filter "Godot_v4.5.2-stable_win64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $godotExe) {
    $zipPath = "tools\godot.zip"
    if (-not (Test-Path $zipPath)) {
        Write-Host "Downloading Godot 4.5.2 win64..."
        curl.exe -fL --retry 5 --retry-delay 2 -C - --connect-timeout 15 `
            "https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_win64.exe.zip" `
            -o $zipPath
    }
    Expand-Archive -Path $zipPath -DestinationPath tools -Force
    $godotExe = Get-ChildItem tools -Filter "Godot_v4.5.2-stable_win64.exe" | Select-Object -First 1
}

& $venvPython tools\download_data.py
if (-not (Test-Path "data\manifest.json") -or -not (Test-Path "data\weights.npz")) {
    & $venvPython -m brain.connectome prepare
}

& $godotExe.FullName --headless --path game --editor --import --quit *> reports\setup-godot.log
$importLog = Get-Content reports\setup-godot.log -Raw
if ($importLog -match "SCRIPT ERROR|Parse Error") {
    Write-Output $importLog
    exit 1
}
Write-Host "Hazır. Başlat: .\run.ps1   Test: .\test.ps1"


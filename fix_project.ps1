<#
.SYNOPSIS
    Medical AI Project - Automatic Environment and Dependency Repair Script
#>

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "     Medical AI Project - Automatic Repair Script" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# 1. Detect Python
Write-Host "[*] Step 1/6: Detecting compatible Python installation..." -ForegroundColor Yellow
$pyCandidates = @(
    @("py", "-3.12"),
    @("py", "-3.11"),
    @("py", "-3"),
    @("python", "")
)

$selectedCmd = $null
$selectedArgs = $null

foreach ($cand in $pyCandidates) {
    $cmd = $cand[0]
    $arg = $cand[1]
    try {
        $testArgs = if ($arg) { @($arg, "-c", "import sys; print(sys.version.split()[0])") } else { @("-c", "import sys; print(sys.version.split()[0])") }
        $output = & $cmd $testArgs 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $selectedCmd = $cmd
            $selectedArgs = $arg
            $pyVer = $output.Trim()
            Write-Host "[+] Found compatible Python interpreter: $cmd $arg (version $pyVer)" -ForegroundColor Green
            break
        }
    } catch {
        # continue searching
    }
}

if (-not $selectedCmd) {
    Write-Host "`n[ERROR] No working Python 3 installation found." -ForegroundColor Red
    Write-Host "Please download and install Python 3.11 or 3.12 from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "(Ensure 'Add Python to PATH' is checked during installation)`n" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# 2. Check and clean broken .venv
Write-Host "`n[*] Step 2/6: Checking virtual environment integrity..." -ForegroundColor Yellow
$venvPython = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$needRebuild = $false

if (Test-Path ".venv") {
    if (Test-Path $venvPython) {
        try {
            & $venvPython -c "import sys" 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[!] Existing .venv is broken (machine-specific paths from friend's PC)." -ForegroundColor Yellow
                $needRebuild = $true
            } else {
                Write-Host "[+] Existing .venv is intact." -ForegroundColor Green
            }
        } catch {
            $needRebuild = $true
        }
    } else {
        Write-Host "[!] Incomplete .venv detected." -ForegroundColor Yellow
        $needRebuild = $true
    }
} else {
    $needRebuild = $true
}

if ($needRebuild) {
    if (Test-Path ".venv") {
        Write-Host "[*] Deleting stale .venv directory..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force ".venv"
    }
    Write-Host "[*] Creating fresh virtual environment..." -ForegroundColor Yellow
    $createArgs = if ($selectedArgs) { @($selectedArgs, "-m", "venv", ".venv") } else { @("-m", "venv", ".venv") }
    & $selectedCmd $createArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to create virtual environment." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Host "[+] Fresh virtual environment created." -ForegroundColor Green
}

# 3. Write requirements files
Write-Host "`n[*] Step 3/6: Writing compatible requirements..." -ForegroundColor Yellow
$reqContent = @"
streamlit>=1.35.0
transformers>=4.40.0,<5.0.0
torch>=2.0.0
torchvision
numpy>=1.26.0
pillow>=10.0.0
safetensors>=0.4.0
timm>=1.0.0
albumentations>=1.4.0
"@

Set-Content -Path "requirements.txt" -Value $reqContent
Set-Content -Path "requirments.txt" -Value $reqContent
Write-Host "[+] Updated requirements.txt and requirments.txt (added albumentations, pinned transformers<5.0.0)." -ForegroundColor Green

# 4. Install dependencies
Write-Host "`n[*] Step 4/6: Installing packages into .venv (this may take 2-4 minutes)..." -ForegroundColor Yellow
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Dependency installation failed. Check internet connection and try again." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "[+] All dependencies installed successfully." -ForegroundColor Green

# 5. Update run_app.bat
Write-Host "`n[*] Step 5/6: Updating run_app.bat..." -ForegroundColor Yellow
$runBatContent = @'
@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

:: Verify virtual environment health
set "NEED_SETUP=0"
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -c "import sys" >nul 2>&1
    if !errorlevel! neq 0 set "NEED_SETUP=1"
) else (
    set "NEED_SETUP=1"
)

if "!NEED_SETUP!"=="1" (
    echo [*] Virtual environment missing or invalid. Initializing...
    if exist ".venv" rmdir /s /q ".venv"
    set "PY_CMD="
    py -3.12 -c "import sys" >nul 2>&1 && set "PY_CMD=py -3.12"
    if not defined PY_CMD py -3.11 -c "import sys" >nul 2>&1 && set "PY_CMD=py -3.11"
    if not defined PY_CMD py -3 -c "import sys" >nul 2>&1 && set "PY_CMD=py -3"
    if not defined PY_CMD python -c "import sys" >nul 2>&1 && set "PY_CMD=python"
    if not defined PY_CMD (
        echo [ERROR] Python not found. Please install Python 3.11 or 3.12.
        pause
        exit /b 1
    )
    !PY_CMD! -m venv .venv
    if !errorlevel! neq 0 exit /b !errorlevel!
    ".venv\Scripts\python.exe" -m pip install -r requirements.txt
    if !errorlevel! neq 0 exit /b !errorlevel!
)

echo [*] Starting Medical AI Image Analyzer...
".venv\Scripts\python.exe" -m streamlit run APP.py --server.headless true --server.port 8502
pause
'@

Set-Content -Path "run_app.bat" -Value $runBatContent
Write-Host "[+] Updated run_app.bat with self-healing launcher." -ForegroundColor Green

# 6. Clean .vscode/tasks.json
Write-Host "`n[*] Step 6/6: Normalizing VS Code tasks..." -ForegroundColor Yellow
if (Test-Path ".vscode\tasks.json") {
    $tasksJson = Get-Content ".vscode\tasks.json" -Raw
    $tasksJson = $tasksJson -replace '"C:.*pythoncore-3.12-64/python.exe"', '".venv/Scripts/python.exe"'
    $tasksJson = $tasksJson -replace 'py -3.12', '.venv\Scripts\python.exe'
    Set-Content -Path ".vscode\tasks.json" -Value $tasksJson
    Write-Host "[+] Fixed hardcoded paths in .vscode/tasks.json." -ForegroundColor Green
}

# Verification
Write-Host "`n[*] Running verification smoke test..." -ForegroundColor Yellow
& $venvPython -c "import streamlit, transformers, torch, timm, albumentations, PIL; print('    [OK] All core libraries loaded successfully.')"
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "     SUCCESS: Project repaired and ready to run!" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "You can now launch the app at any time by running:" -ForegroundColor White
    Write-Host "    .\run_app.bat`n" -ForegroundColor Yellow
} else {
    Write-Host "`n[WARNING] Verification encountered an error. Please inspect the logs above.`n" -ForegroundColor Yellow
}

Read-Host "Press Enter to exit"

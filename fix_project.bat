@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ========================================================
echo     Medical AI Project - Automatic Repair Script
echo ========================================================
echo.

:: 1. Detect working Python launcher
echo [*] Step 1/6: Detecting compatible Python installation...
set "PY_CMD="

py -3.12 -c "import sys" >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=py -3.12"
    goto :found_py
)

py -3.11 -c "import sys" >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=py -3.11"
    goto :found_py
)

py -3 -c "import sys" >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=py -3"
    goto :found_py
)

python -c "import sys" >nul 2>&1
if %errorlevel% equ 0 (
    set "PY_CMD=python"
    goto :found_py
)

echo.
echo [ERROR] No working Python 3 installation was detected.
echo Please install Python 3.11 or 3.12 from:
echo   https://www.python.org/downloads/
echo (Make sure to check "Add Python to PATH" during installation)
echo.
pause
exit /b 1

:found_py
echo [+] Selected Python launcher: %PY_CMD%
%PY_CMD% -c "import sys; print('    Interpreter version:', sys.version.split()[0])"
echo.

:: 2. Check and clean broken .venv
echo [*] Step 2/6: Checking virtual environment integrity...
set "REBUILD_VENV=0"

if exist ".venv" (
    if exist ".venv\Scripts\python.exe" (
        ".venv\Scripts\python.exe" -c "import sys" >nul 2>&1
        if %errorlevel% neq 0 (
            echo [!] Existing .venv is broken (machine-specific paths from friend's PC).
            set "REBUILD_VENV=1"
        ) else (
            echo [+] Existing .venv is valid.
        )
    ) else (
        echo [!] Incomplete .venv detected.
        set "REBUILD_VENV=1"
    )
) else (
    set "REBUILD_VENV=1"
)

if "!REBUILD_VENV!"=="1" (
    if exist ".venv" (
        echo [*] Deleting stale .venv directory...
        rmdir /s /q ".venv"
    )
    echo [*] Creating clean virtual environment with %PY_CMD%...
    %PY_CMD% -m venv .venv
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b %errorlevel%
    )
    echo [+] Fresh virtual environment created.
)
echo.

:: 3. Generate compatible requirements files
echo [*] Step 3/6: Generating updated requirements files...
(
echo streamlit^>=1.35.0
echo transformers^>=4.40.0,^<5.0.0
echo torch^>=2.0.0
echo torchvision
echo numpy^>=1.26.0
echo pillow^>=10.0.0
echo safetensors^>=0.4.0
echo timm^>=1.0.0
echo albumentations^>=1.4.0
) > requirements.txt

:: Also overwrite requirments.txt (preserving typo for legacy scripts)
copy /y requirements.txt requirments.txt >nul
echo [+] Updated requirements.txt and requirments.txt (added missing 'albumentations', pinned transformers^<5.0.0).
echo.

:: 4. Install dependencies
echo [*] Step 4/6: Installing dependencies into virtual environment...
echo [*] (This may take 2-4 minutes to download PyTorch and dependencies)
".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install packages. Check internet connection and try again.
    pause
    exit /b %errorlevel%
)
echo [+] All dependencies successfully installed.
echo.

:: 5. Update run_app.bat with self-healing launcher
echo [*] Step 5/6: Updating run_app.bat with resilient startup logic...
(
echo @echo off
echo setlocal enabledelayedexpansion
echo cd /d "%%~dp0"
echo.
echo :: Verify virtual environment health
echo set "NEED_SETUP=0"
echo if exist ".venv\Scripts\python.exe" ^(
echo     ".venv\Scripts\python.exe" -c "import sys" ^>nul 2^>^&1
echo     if !errorlevel! neq 0 set "NEED_SETUP=1"
echo ^) else ^(
echo     set "NEED_SETUP=1"
echo ^)
echo.
echo if "!NEED_SETUP!"=="1" ^(
echo     echo [*] Virtual environment missing or invalid. Initializing...
echo     if exist ".venv" rmdir /s /q ".venv"
echo     set "PY_CMD="
echo     py -3.12 -c "import sys" ^>nul 2^>^&1 ^&^& set "PY_CMD=py -3.12"
echo     if not defined PY_CMD py -3.11 -c "import sys" ^>nul 2^>^&1 ^&^& set "PY_CMD=py -3.11"
echo     if not defined PY_CMD py -3 -c "import sys" ^>nul 2^>^&1 ^&^& set "PY_CMD=py -3"
echo     if not defined PY_CMD python -c "import sys" ^>nul 2^>^&1 ^&^& set "PY_CMD=python"
echo     if not defined PY_CMD ^(
echo         echo [ERROR] Python not found. Please install Python 3.11 or 3.12.
echo         pause
echo         exit /b 1
echo     ^)
echo     !PY_CMD! -m venv .venv
echo     if !errorlevel! neq 0 exit /b !errorlevel!
echo     ".venv\Scripts\python.exe" -m pip install -r requirements.txt
echo     if !errorlevel! neq 0 exit /b !errorlevel!
echo ^)
echo.
echo echo [*] Starting Medical AI Image Analyzer...
echo ".venv\Scripts\python.exe" -m streamlit run APP.py --server.headless true --server.port 8502
echo pause
) > run_app.bat
echo [+] run_app.bat updated.
echo.

:: 6. Clean .vscode/tasks.json if present
echo [*] Step 6/6: Normalizing VS Code tasks...
if exist ".vscode\tasks.json" (
    powershell -NoProfile -Command "(Get-Content .vscode\tasks.json) -replace '\"C:.*pythoncore-3.12-64/python.exe\"', '\".venv/Scripts/python.exe\"' -replace 'py -3.12', '.venv\\Scripts\\python.exe' | Set-Content .vscode\tasks.json" 2>nul
    echo [+] Cleaned hardcoded user paths in .vscode/tasks.json.
) else (
    echo [-] No .vscode/tasks.json found. Skipping.
)
echo.

:: Final validation
echo [*] Running smoke test on installed libraries...
".venv\Scripts\python.exe" -c "import streamlit, transformers, torch, timm, albumentations, PIL; print('    [OK] All core libraries loaded successfully.')"
if %errorlevel% neq 0 (
    echo [WARNING] Verification test failed. Please check log messages above.
) else (
    echo.
    echo ========================================================
    echo      SUCCESS: Project repaired and ready to run!
    echo ========================================================
    echo To launch the web application, run:
    echo     run_app.bat
    echo.
)

pause

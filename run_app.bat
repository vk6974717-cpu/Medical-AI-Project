@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
    py -3.12 -m venv .venv
    if errorlevel 1 exit /b %errorlevel%
)

".venv\Scripts\python.exe" -m pip install -r requirments.txt
if errorlevel 1 exit /b %errorlevel%

".venv\Scripts\python.exe" -m streamlit run APP.py --server.headless true --server.port 8502

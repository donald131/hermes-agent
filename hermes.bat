@echo off
setlocal EnableDelayedExpansion

REM ============================================================================
REM Hermes Agent - Windows 10 Launcher & Installer
REM ============================================================================
REM This script serves as both:
REM   1. Daily launcher (when venv and deps are already set up)
REM   2. First-time installer (auto-detects and sets up environment)
REM
REM Usage:
REM   hermes.bat              - Start interactive chat (or auto-setup if first run)
REM   hermes.bat install      - Force full installation/setup
REM   hermes.bat help         - Show help
REM   hermes.bat <any> ...    - Pass through to Python CLI
REM
REM Environment variables:
REM   HERMES_SKIP_AUTOSETUP=1 - Disable auto-setup (only find Python and run)
REM   HERMES_NO_CHCP=1        - Skip codepage switch (fix garbled output)
REM   HERMES_VERBOSE=1        - Show detailed setup progress
REM ============================================================================

REM --- Encoding Setup (Windows 10 compatible) ---
if not defined HERMES_NO_CHCP (
    for /f "tokens=2 delims=:" %%a in ('chcp 2^>nul') do set "CURRENT_CP=%%a"
    set "CURRENT_CP=!CURRENT_CP: =!"
    if not "!CURRENT_CP!"=="65001" (
        chcp 65001 >nul 2>&1
    )
)
set "PYTHONIOENCODING=utf-8"
set "PYTHONUTF8=1"

REM --- Initialize Variables ---
set "HERMES_DIR=%~dp0"
if "%HERMES_DIR:~-1%"=="\" set "HERMES_DIR=%HERMES_DIR:~0,-1%"
set "HERMES_ARGS=%*"
set "PYTHON_CMD="
set "PIP_CMD="

if defined HERMES_HOME (
    set "HH=%HERMES_HOME%"
) else (
    set "HH=%USERPROFILE%\.hermes"
)

REM ============================================================================
REM Subcommand Dispatch
REM ============================================================================

set "HERMES_SUBCMD=%~1"
if not defined HERMES_SUBCMD goto :ready_checks

if /i "%HERMES_SUBCMD%"=="install" (
    shift
    set "HERMES_ARGS="
    call :parse_remaining_args %*
    goto :full_install
)
if /i "%HERMES_SUBCMD%"=="help" (
    call :show_help
    goto :eof
)
if /i "%HERMES_SUBCMD%"=="--help" (
    call :show_help
    goto :eof
)
if /i "%HERMES_SUBCMD%"=="-h" (
    call :show_help
    goto :eof
)

REM All other subcommands: fall through to Python after readiness checks
goto :ready_checks

REM ============================================================================
REM Readiness Pipeline
REM ============================================================================

:ready_checks
call :find_python
if not defined PYTHON_CMD exit /b 1

if not defined HERMES_SKIP_AUTOSETUP (
    call :check_venv
    if !VENV_FAILED! EQU 1 exit /b 1
    call :check_deps
    if !DEPS_FAILED! EQU 1 exit /b 1
    call :check_hermes_home
)

goto :run

REM ============================================================================
REM Python Discovery
REM ============================================================================

:find_python
REM 1. Bundled portable Python
if exist "%HERMES_DIR%\python.exe" (
    set "PYTHON_CMD=%HERMES_DIR%\python.exe"
    if defined HERMES_VERBOSE echo   [found] Bundled Python: %HERMES_DIR%\python.exe
    goto :validate_python
)

REM 2. venv Python
if exist "%HERMES_DIR%\venv\Scripts\python.exe" (
    set "PYTHON_CMD=%HERMES_DIR%\venv\Scripts\python.exe"
    set "PIP_CMD=%HERMES_DIR%\venv\Scripts\pip.exe"
    if defined HERMES_VERBOSE echo   [found] venv Python: %HERMES_DIR%\venv\Scripts\python.exe
    goto :validate_python
)

REM 3. System PATH - python
where python >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    set "PYTHON_CMD=python"
    if defined HERMES_VERBOSE echo   [found] System Python (PATH)
    goto :validate_python
)

REM 4. System PATH - python3
where python3 >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    set "PYTHON_CMD=python3"
    if defined HERMES_VERBOSE echo   [found] System Python3 (PATH)
    goto :validate_python
)

REM 5. Common Windows install locations (bypass PATH)
for %%v in (313 312 311 310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\Python%%v\python.exe" (
        set "PYTHON_CMD=%LOCALAPPDATA%\Programs\Python\Python%%v\python.exe"
        if defined HERMES_VERBOSE echo   [found] Local Python %%v
        goto :validate_python
    )
)

REM 6. Windows launcher (py command)
where py >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    py -3 -c "import sys; sys.exit(0)" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        set "PYTHON_CMD=py -3"
        if defined HERMES_VERBOSE echo   [found] Python launcher (py -3)
        goto :validate_python
    )
)

call :show_error_no_python
set "PYTHON_CMD="
goto :eof

:validate_python
"%PYTHON_CMD%" -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    for /f "tokens=*" %%v in ('"%PYTHON_CMD%" --version 2^>^&1') do set "PY_VER=%%v"
    call :show_error_python_version "!PY_VER!"
    set "PYTHON_CMD="
)
goto :eof

REM ============================================================================
REM Virtual Environment
REM ============================================================================

:check_venv
set "VENV_FAILED=0"

REM Already using venv Python? Done.
if "%PYTHON_CMD%"=="%HERMES_DIR%\venv\Scripts\python.exe" goto :eof
if exist "%HERMES_DIR%\venv\Scripts\python.exe" (
    set "PYTHON_CMD=%HERMES_DIR%\venv\Scripts\python.exe"
    set "PIP_CMD=%HERMES_DIR%\venv\Scripts\pip.exe"
    goto :eof
)

REM Check path length (Windows 10 long path issue)
set "VENVPATH=%HERMES_DIR%\venv"
call :strlen VENVPATH VENVLEN
if !VENVLEN! GTR 200 (
    echo.
    echo   WARNING: Project path is long (!VENVLEN! chars^).
    echo   venv nested paths may exceed 260-char limit on Windows 10.
    echo   Consider moving to a shorter path like C:\hermes\
    echo.
)

echo.
echo   No virtual environment found. Creating one...
echo   Location: %HERMES_DIR%\venv
echo.

"%PYTHON_CMD%" -m venv "%HERMES_DIR%\venv"
if !ERRORLEVEL! NEQ 0 (
    call :show_error_venv_failed
    set "VENV_FAILED=1"
    goto :eof
)

set "PYTHON_CMD=%HERMES_DIR%\venv\Scripts\python.exe"
set "PIP_CMD=%HERMES_DIR%\venv\Scripts\pip.exe"

echo   Virtual environment created successfully.
echo.
goto :eof

REM ============================================================================
REM Dependency Installation
REM ============================================================================

:check_deps
set "DEPS_FAILED=0"

REM Quick check: is hermes_cli importable?
"%PYTHON_CMD%" -c "import hermes_cli.main" >nul 2>&1
if !ERRORLEVEL! EQU 0 goto :eof

echo   Installing Hermes dependencies...
echo   This may take a few minutes on first run.
echo.

REM Determine pip command
if not defined PIP_CMD (
    if exist "%HERMES_DIR%\venv\Scripts\pip.exe" (
        set "PIP_CMD=%HERMES_DIR%\venv\Scripts\pip.exe"
    ) else (
        set "PIP_CMD="
    )
)

REM Upgrade pip first (avoids many issues)
if defined PIP_CMD (
    "%PIP_CMD%" install --upgrade pip >nul 2>&1
) else (
    "%PYTHON_CMD%" -m pip install --upgrade pip >nul 2>&1
)

REM Try editable install from pyproject.toml
set "INSTALL_OK=0"

if exist "%HERMES_DIR%\pyproject.toml" (
    echo   Installing from local pyproject.toml...
    if defined PIP_CMD (
        "%PIP_CMD%" install -e "%HERMES_DIR%." 2>nul
        if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
    )
    if !INSTALL_OK! EQU 0 (
        "%PYTHON_CMD%" -m pip install -e "%HERMES_DIR%." 2>nul
        if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
    )
    if !INSTALL_OK! EQU 0 (
        echo   Base install failed, trying with all extras...
        if defined PIP_CMD (
            "%PIP_CMD%" install -e "%HERMES_DIR%.[all]" 2>nul
            if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
        )
        if !INSTALL_OK! EQU 0 (
            "%PYTHON_CMD%" -m pip install -e "%HERMES_DIR%.[all]" 2>nul
            if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
        )
    )
)

REM Fallback: try PyPI
if !INSTALL_OK! EQU 0 (
    echo   Local install failed, trying from PyPI...
    if defined PIP_CMD (
        "%PIP_CMD%" install hermes-agent 2>nul
        if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
    )
    if !INSTALL_OK! EQU 0 (
        "%PYTHON_CMD%" -m pip install hermes-agent 2>nul
        if !ERRORLEVEL! EQU 0 set "INSTALL_OK=1"
    )
)

REM Verify installation
"%PYTHON_CMD%" -c "import hermes_cli.main" >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    call :show_error_pip_failed
    set "DEPS_FAILED=1"
    goto :eof
)

echo.
echo   Dependencies installed successfully.
echo.
goto :eof

REM ============================================================================
REM HERMES_HOME Setup
REM ============================================================================

:check_hermes_home

REM Check if HERMES_HOME already has config
if exist "%HH%\config.yaml" if exist "%HH%\.env" goto :eof

echo   Setting up Hermes configuration directory...
echo   Location: %HH%
echo.

REM Create directory structure
for %%d in (cron sessions logs memories skills pairing hooks image_cache audio_cache) do (
    if not exist "%HH%\%%d" mkdir "%HH%\%%d" 2>nul
)

REM Create .env from template
if not exist "%HH%\.env" (
    if exist "%HERMES_DIR%\.env.example" (
        copy /Y "%HERMES_DIR%\.env.example" "%HH%\.env" >nul 2>&1
        echo   Created .env from template - edit to add your API key
    ) else (
        (
            echo # Hermes Agent Environment Variables
            echo # Add your API key below
            echo.
            echo # OpenRouter - 200+ models through one API
            echo # Get your key at: https://openrouter.ai/keys
            echo # OPENROUTER_API_KEY=
        ) > "%HH%\.env"
        echo   Created .env - edit to add your API key
    )
)

REM Create config.yaml from template
if not exist "%HH%\config.yaml" (
    if exist "%HERMES_DIR%\cli-config.yaml.example" (
        copy /Y "%HERMES_DIR%\cli-config.yaml.example" "%HH%\config.yaml" >nul 2>&1
        echo   Created config.yaml from template
    )
)

REM Set HERMES_HOME environment variable persistently (no PowerShell needed)
setx HERMES_HOME "%HH%" >nul 2>&1
set "HERMES_HOME=%HH%"

echo   Configuration directory ready.
echo.
goto :eof

REM ============================================================================
REM Full Install (hermes.bat install)
REM ============================================================================

:full_install
echo.
echo   ============================================
echo    Hermes Agent - Windows 10 Installation
echo   ============================================
echo.

call :find_python
if not defined PYTHON_CMD exit /b 1

call :check_venv
if !VENV_FAILED! EQU 1 exit /b 1

call :check_deps
if !DEPS_FAILED! EQU 1 exit /b 1

call :check_hermes_home

echo.
echo   ============================================
echo    Installation Complete!
echo   ============================================
echo.
echo   Config:    %HH%\config.yaml
echo   API Keys:  %HH%\.env
echo   Data:      %HH%\cron\, sessions\, logs\
echo.
echo   Next steps:
echo   1. Edit %HH%\.env and add your API key
echo   2. Run: hermes.bat
echo.
echo   Useful commands:
echo   hermes.bat setup       - Interactive setup wizard
echo   hermes.bat config edit - Open config in editor
echo   hermes.bat doctor      - Diagnose issues
echo.

goto :eof

REM ============================================================================
REM Main Runner
REM ============================================================================

:run
"%PYTHON_CMD%" -m hermes_cli.main %HERMES_ARGS%
set "EXIT_CODE=!ERRORLEVEL!"
endlocal & exit /b %EXIT_CODE%

REM ============================================================================
REM Help
REM ============================================================================

:show_help
echo.
echo   Hermes Agent - Windows 10 Launcher
echo   ====================================
echo.
echo   Usage: hermes.bat [command] [options]
echo.
echo   Commands:
echo     (none)      Start interactive chat
echo     install     Full installation / setup
echo     setup       Interactive setup wizard
echo     config      View/edit configuration
echo     doctor      Diagnose configuration issues
echo     update      Update to latest version
echo     help        Show this help
echo.
echo   Environment:
echo     HERMES_SKIP_AUTOSETUP=1  Disable auto-setup
echo     HERMES_NO_CHCP=1         Skip codepage switch
echo     HERMES_VERBOSE=1         Verbose output
echo.
echo   First run? Just execute: hermes.bat
echo   It will auto-detect and set up the environment.
echo.
goto :eof

REM ============================================================================
REM Error Messages
REM ============================================================================

:show_error_no_python
echo.
echo   ERROR: Python 3.10+ not found!
echo.
echo   Searched:
echo     - %HERMES_DIR%\python.exe (bundled^)
echo     - %HERMES_DIR%\venv\Scripts\python.exe (virtual environment^)
echo     - System PATH (python, python3^)
echo     - %LOCALAPPDATA%\Programs\Python\Python3xx\
echo     - Python launcher (py -3^)
echo.
echo   To fix:
echo     1. Download Python 3.11+ from https://www.python.org/downloads/
echo        IMPORTANT: Check "Add Python to PATH" during installation
echo     2. Or install via winget:
echo        winget install Python.Python.3.11
echo     3. Then restart your terminal and re-run this script
echo.
goto :eof

:show_error_python_version
echo.
echo   ERROR: Python version too old!
echo   Found: %~1
echo   Required: Python 3.10 or later
echo.
echo   Please install Python 3.11+ from https://www.python.org/downloads/
echo   Or: winget install Python.Python.3.11
echo.
goto :eof

:show_error_venv_failed
echo.
echo   ERROR: Failed to create virtual environment!
echo.
echo   Common fixes for Windows 10:
echo.
echo   1. Path too long (most common^):
echo      Move the project closer to the drive root, e.g. C:\hermes\
echo.
echo   2. Enable long paths in Windows (requires admin^):
echo      Open CMD as Administrator and run:
echo      reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem ^
echo          /v LongPathsEnabled /t REG_DWORD /d 1 /f
echo      Then restart your computer.
echo.
echo   3. Permission denied:
echo      Right-click CMD ^> "Run as administrator"
echo.
echo   4. Antivirus blocking:
echo      Add an exclusion for: %HERMES_DIR%
echo.
goto :eof

:show_error_pip_failed
echo.
echo   ERROR: Failed to install dependencies!
echo.
echo   Common fixes for Windows 10:
echo.
echo   1. Windows Defender may be quarantining packages:
echo      - Open Windows Security ^> Virus & threat protection
echo      - Manage settings ^> Exclusions ^> Add: %HERMES_DIR%
echo      - Re-run: hermes.bat install
echo.
echo   2. Network/proxy issues:
echo      set HTTP_PROXY=http://proxy-server:port
echo      set HTTPS_PROXY=http://proxy-server:port
echo      hermes.bat install
echo.
echo   3. Missing Visual C++ Redistributable:
echo      Download from: https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
echo.
echo   4. Try the full PowerShell installer instead:
echo      powershell -ExecutionPolicy ByPass -c "irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1 ^| iex"
echo.
goto :eof

REM ============================================================================
REM Utility: String Length
REM ============================================================================

:strlen
set "STR=!%~1!"
set "LEN=0"
:strlen_loop
if defined STR (
    set "STR=!STR:~1!"
    set /a "LEN+=1"
    goto :strlen_loop
)
set "%~2=%LEN%"
goto :eof

REM ============================================================================
REM Utility: Parse remaining args after shift
REM ============================================================================

:parse_remaining_args
set "HERMES_ARGS="
:parse_loop
if "%~1"=="" goto :eof
if defined HERMES_ARGS (
    set "HERMES_ARGS=!HERMES_ARGS! %~1"
) else (
    set "HERMES_ARGS=%~1"
)
shift
goto :parse_loop

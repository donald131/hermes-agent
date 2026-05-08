@echo off
setlocal EnableExtensions

REM ============================================================================
REM Hermes Agent Windows Launcher + Setup
REM ============================================================================
REM Usage:
REM   hermes.bat              — interactive chat (default)
REM   hermes.bat setup        — first-time setup (mirrors setup-hermes.sh)
REM   hermes.bat gateway run   — Run gateway in foreground
REM   hermes.bat gateway start — Start gateway in background (using start command)
REM   hermes.bat gateway stop  — Stop gateway processes
REM   hermes.bat gateway status — Show gateway status
REM   hermes.bat dashboard     — Start web UI dashboard
REM   hermes.bat dashboard --stop   — Stop dashboard
REM   hermes.bat dashboard --status — Show dashboard status
REM   hermes.bat <command>    — any hermes subcommand
REM ============================================================================

REM --- Resolve script directory ---
set "HERMES_DIR=%~dp0"
if "%HERMES_DIR:~-1%"=="\" set "HERMES_DIR=%HERMES_DIR:~0,-1%"

REM --- HERMES_HOME default for Windows ---
if not defined HERMES_HOME set "HERMES_HOME=%LOCALAPPDATA%\hermes"

REM ============================================================================
REM Dispatch: setup with no extra args goes to setup flow
REM ============================================================================
if not "%~1"=="setup" goto :skip_setup
if not "%~2"=="" goto :skip_setup
goto :do_setup
:skip_setup

REM ============================================================================
REM Gateway command handling for Windows
REM ============================================================================
if not "%~1"=="gateway" goto :skip_gateway

set "GATEWAY_SUBCMD=%~2"

REM gateway run - run in foreground (default behavior, just pass through)
if "%GATEWAY_SUBCMD%"=="run" goto :resolve_python

REM gateway start - run in background window
if "%GATEWAY_SUBCMD%"=="start" (
    echo   [*] Starting Hermes Gateway in background...
    goto :resolve_python_for_bg
)

REM gateway stop - stop all gateway processes
if "%GATEWAY_SUBCMD%"=="stop" (
    echo   [*] Stopping Hermes Gateway...
    taskkill /f /im python.exe /fi "WINDOWTITLE eq Hermes Gateway" 2>nul
    taskkill /f /im python.exe /fi "COMMANDLINE eq *hermes_cli.main gateway*" 2>nul
    echo   [OK] Gateway stopped
    exit /b 0
)

REM gateway status - show status
if "%GATEWAY_SUBCMD%"=="status" (
    echo   [*] Checking Gateway status...
    tasklist /fi "WINDOWTITLE eq Hermes Gateway" 2>nul | findstr /i python >nul
    if %ERRORLEVEL%==0 (
        echo   [OK] Gateway is running
    ) else (
        tasklist /fi "COMMANDLINE eq *hermes_cli.main gateway*" 2>nul | findstr /i python >nul
        if %ERRORLEVEL%==0 (
            echo   [OK] Gateway is running
        ) else (
            echo   [!] Gateway is not running
        )
    )
    exit /b 0
)

REM For other gateway commands (install, uninstall, restart, etc.), pass through
goto :resolve_python

:resolve_python_for_bg
REM Find Python for background execution
set "PYTHON_EXE="

if exist "%HERMES_DIR%\venv\Scripts\python.exe" (
    set "PYTHON_EXE=%HERMES_DIR%\venv\Scripts\python.exe"
    goto :run_gateway_bg
)

if exist "%HERMES_DIR%\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%HERMES_DIR%\.venv\Scripts\python.exe"
    goto :run_gateway_bg
)

if defined VIRTUAL_ENV (
    if exist "%VIRTUAL_ENV%\Scripts\python.exe" (
        set "PYTHON_EXE=%VIRTUAL_ENV%\Scripts\python.exe"
        goto :run_gateway_bg
    )
)

echo   [!] No virtual environment found. Run "hermes.bat setup" first.
exit /b 1

:run_gateway_bg
REM Run gateway in background with a hidden window
start "Hermes Gateway" /min "%PYTHON_EXE%" -m hermes_cli.main gateway run
echo   [OK] Gateway started in background
exit /b 0

:skip_gateway

REM ============================================================================
REM Dashboard command handling for Windows
REM ============================================================================
if not "%~1"=="dashboard" goto :skip_dashboard

set "DASHBOARD_SUBCMD=%~2"

REM dashboard --stop - stop all dashboard processes
if "%DASHBOARD_SUBCMD%"=="--stop" (
    echo   [*] Stopping Hermes Dashboard...
    taskkill /f /im python.exe /fi "WINDOWTITLE eq Hermes Dashboard" 2>nul
    taskkill /f /im python.exe /fi "COMMANDLINE eq *hermes_cli.main dashboard*" 2>nul
    echo   [OK] Dashboard stopped
    exit /b 0
)

REM dashboard --status - show status
if "%DASHBOARD_SUBCMD%"=="--status" (
    echo   [*] Checking Dashboard status...
    tasklist /fi "WINDOWTITLE eq Hermes Dashboard" 2>nul | findstr /i python >nul
    if %ERRORLEVEL%==0 (
        echo   [OK] Dashboard is running
    ) else (
        tasklist /fi "COMMANDLINE eq *hermes_cli.main dashboard*" 2>nul | findstr /i python >nul
        if %ERRORLEVEL%==0 (
            echo   [OK] Dashboard is running
        ) else (
            echo   [!] Dashboard is not running
        )
    )
    exit /b 0
)

REM For dashboard run (foreground) and other dashboard args, pass through
REM Check Node.js availability first
where npm >nul 2>&1
if errorlevel 1 (
    echo   [!] Node.js is required for the Dashboard but is not installed.
    echo.
    echo   Please install Node.js:
    echo     https://nodejs.org/
    echo.
    echo   After installation, restart your terminal and try again.
    exit /b 1
)

REM Check and install web dependencies if needed
if not exist "%HERMES_DIR%\web\node_modules" (
    echo   [*] Installing web UI dependencies...
    cd /d "%HERMES_DIR%\web"
    npm install
    if errorlevel 1 (
        echo   [!] Failed to install web UI dependencies.
        cd /d "%HERMES_DIR%"
        exit /b 1
    )
    echo   [OK] Web UI dependencies installed
    cd /d "%HERMES_DIR%"
)

REM Find Git Bash for npm commands (needed for Unix-style scripts)
set "GIT_BASH="
if defined HERMES_GIT_BASH_PATH (
    if exist "%HERMES_GIT_BASH_PATH%" (
        set "GIT_BASH=%HERMES_GIT_BASH_PATH%"
    )
)
if not defined GIT_BASH (
    if exist "%ProgramFiles%\Git\bin\bash.exe" (
        set "GIT_BASH=%ProgramFiles%\Git\bin\bash.exe"
    )
)

REM Pre-build web UI (Python will skip if already built)
echo   [*] Building web UI...
cd /d "%HERMES_DIR%\web"
if defined GIT_BASH (
    "%GIT_BASH%" -c "npm run build"
) else (
    npm run build
)
if errorlevel 1 (
    echo   [!] Web UI build failed.
    echo.
    echo   Common causes:
    echo     - Missing dependencies: run "npm install" in web directory
    echo     - Node.js version mismatch: requires Node.js 18+
    echo     - Permission issues: try running as administrator
    echo.
    echo   Manual fix:
    echo     cd web
    echo     npm install
    echo     npm run build
    cd /d "%HERMES_DIR%"
    exit /b 1
)
echo   [OK] Web UI built
cd /d "%HERMES_DIR%"

goto :resolve_python

:skip_dashboard

REM ============================================================================
REM Normal launcher (mirrors Unix hermes shim)
REM ============================================================================

REM --- Sanitize environment ---
set PYTHONPATH=
set PYTHONHOME=

REM --- UTF-8 protection before Python starts ---
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8

REM --- Locate Python (3-step cascade, auto-init if no venv) ---
set "PYTHON_EXE="

:resolve_python

REM 1. venv relative to this script (source checkout)
if exist "%HERMES_DIR%\venv\Scripts\python.exe" (
    set "PYTHON_EXE=%HERMES_DIR%\venv\Scripts\python.exe"
    goto :run_hermes
)

REM 1b. .venv relative to this script (uv convention)
if exist "%HERMES_DIR%\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%HERMES_DIR%\.venv\Scripts\python.exe"
    goto :run_hermes
)

REM 2. VIRTUAL_ENV env var (external/activated venv)
if defined VIRTUAL_ENV (
    if exist "%VIRTUAL_ENV%\Scripts\python.exe" (
        set "PYTHON_EXE=%VIRTUAL_ENV%\Scripts\python.exe"
        goto :run_hermes
    )
)

REM 3. No local venv found — auto-initialize with uv
set "UV_AUTO="
where uv >nul 2>&1
if %ERRORLEVEL%==0 (
    set "UV_AUTO=uv"
    goto :auto_init
)
if exist "%LOCALAPPDATA%\uv\uv.exe" (
    set "UV_AUTO=%LOCALAPPDATA%\uv\uv.exe"
    goto :auto_init
)
if exist "%USERPROFILE%\.local\bin\uv.exe" (
    set "UV_AUTO=%USERPROFILE%\.local\bin\uv.exe"
    goto :auto_init
)
if exist "%USERPROFILE%\.cargo\bin\uv.exe" (
    set "UV_AUTO=%USERPROFILE%\.cargo\bin\uv.exe"
    goto :auto_init
)

echo   [*] uv not found, installing...
powershell -NoProfile -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
if errorlevel 1 (
    echo   [!] Failed to install uv. Visit https://docs.astral.sh/uv/
    exit /b 1
)

REM Re-scan after install
where uv >nul 2>&1
if %ERRORLEVEL%==0 (
    set "UV_AUTO=uv"
    goto :auto_init
)
if exist "%LOCALAPPDATA%\uv\uv.exe" (
    set "UV_AUTO=%LOCALAPPDATA%\uv\uv.exe"
    goto :auto_init
)
echo   [!] uv installed but not found on PATH. Restart terminal and retry.
exit /b 1

:auto_init
echo.
echo   [*] No virtual environment found, initializing...
echo.

REM Ensure Python 3.11 is available
"%UV_AUTO%" python find 3.11 >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   [*] Python 3.11 not found, installing via uv...
    "%UV_AUTO%" python install 3.11
    if errorlevel 1 (
        echo   [!] Failed to install Python 3.11.
        exit /b 1
    )
)

REM Create .venv
echo   [*] Creating .venv...
"%UV_AUTO%" venv "%HERMES_DIR%\.venv" --python 3.11
if errorlevel 1 (
    echo   [!] Failed to create .venv.
    exit /b 1
)
echo   [OK] .venv created

REM Install dependencies
echo   [*] Installing dependencies...
set "VENV_PYTHON=%HERMES_DIR%\.venv\Scripts\python.exe"

if exist "%HERMES_DIR%\uv.lock" (
    set "UV_PROJECT_ENVIRONMENT=%HERMES_DIR%\.venv"
    "%UV_AUTO%" sync --all-extras --locked 2>nul
    if not errorlevel 1 (
        echo   [OK] Dependencies installed ^(lockfile verified^)
        goto :auto_init_done
    )
    echo   [!] Lockfile failed, falling back to pip install...
)

"%UV_AUTO%" pip install --python "%VENV_PYTHON%" -e ".[all,dev]" 2>nul
if errorlevel 1 (
    "%UV_AUTO%" pip install --python "%VENV_PYTHON%" -e ".[all]" 2>nul
    if errorlevel 1 (
        "%UV_AUTO%" pip install --python "%VENV_PYTHON%" -e . 2>nul
        if errorlevel 1 (
            echo   [!] Failed to install dependencies.
            echo       Run "hermes.bat setup" for a full setup.
            exit /b 1
        )
    )
)
echo   [OK] Dependencies installed

:auto_init_done
set "PYTHON_EXE=%HERMES_DIR%\.venv\Scripts\python.exe"
echo.
echo   [*] Virtual environment ready, launching hermes...
echo.

:run_hermes
"%PYTHON_EXE%" -m hermes_cli.main %*
exit /b %ERRORLEVEL%

REM ============================================================================
REM Setup flow (mirrors setup-hermes.sh)
REM ============================================================================
:do_setup

echo.
echo   ================================
echo   Hermes Agent Setup ^(Windows^)
echo   ================================
echo.

REM ---- Step 1: Check / install uv ----
echo   [1/6] Checking uv...

set "UV_CMD="
where uv >nul 2>&1
if %ERRORLEVEL%==0 (
    set "UV_CMD=uv"
    goto :uv_found
)

if exist "%LOCALAPPDATA%\uv\uv.exe" (
    set "UV_CMD=%LOCALAPPDATA%\uv\uv.exe"
    goto :uv_found
)

if exist "%USERPROFILE%\.local\bin\uv.exe" (
    set "UV_CMD=%USERPROFILE%\.local\bin\uv.exe"
    goto :uv_found
)

if exist "%USERPROFILE%\.cargo\bin\uv.exe" (
    set "UV_CMD=%USERPROFILE%\.cargo\bin\uv.exe"
    goto :uv_found
)

echo   [*] uv not found, installing...
powershell -NoProfile -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
if errorlevel 1 (
    echo   [!] Failed to install uv. Visit https://docs.astral.sh/uv/
    exit /b 1
)

REM Re-scan after install
where uv >nul 2>&1
if %ERRORLEVEL%==0 (
    set "UV_CMD=uv"
    goto :uv_found
)
if exist "%LOCALAPPDATA%\uv\uv.exe" (
    set "UV_CMD=%LOCALAPPDATA%\uv\uv.exe"
    goto :uv_found
)
echo   [!] uv installed but not found on PATH. Restart terminal and retry.
exit /b 1

:uv_found
for /f "delims=" %%v in ('"%UV_CMD%" --version 2^>nul') do echo   [OK] uv %%v

REM ---- Step 2: Check / install Python 3.11 ----
echo   [2/6] Checking Python 3.11...

set "PYTHON_EXE="
"%UV_CMD%" python find 3.11 >nul 2>&1
if %ERRORLEVEL%==0 (
    for /f "delims=" %%p in ('"%UV_CMD%" python find 3.11 2^>nul') do set "PYTHON_EXE=%%p"
    goto :python_found
)

echo   [*] Python 3.11 not found, installing via uv...
"%UV_CMD%" python install 3.11
if errorlevel 1 (
    echo   [!] Failed to install Python 3.11.
    exit /b 1
)
for /f "delims=" %%p in ('"%UV_CMD%" python find 3.11 2^>nul') do set "PYTHON_EXE=%%p"

:python_found
for /f "delims=" %%v in ('"%PYTHON_EXE%" --version 2^>nul') do echo   [OK] %%v

REM ---- Step 3: Create virtual environment ----
echo   [3/6] Creating virtual environment...

if exist "%HERMES_DIR%\venv" (
    echo   [*] Removing old venv...
    rmdir /s /q "%HERMES_DIR%\venv"
)

"%UV_CMD%" venv "%HERMES_DIR%\venv" --python 3.11
if errorlevel 1 (
    echo   [!] Failed to create venv.
    exit /b 1
)
echo   [OK] venv created

REM ---- Step 4: Install dependencies ----
echo   [4/6] Installing dependencies...

set "VENV_PYTHON=%HERMES_DIR%\venv\Scripts\python.exe"

if exist "%HERMES_DIR%\uv.lock" (
    echo   [*] Using uv.lock for hash-verified installation...
    set "UV_PROJECT_ENVIRONMENT=%HERMES_DIR%\venv"
    "%UV_CMD%" sync --all-extras --locked 2>nul
    if not errorlevel 1 (
        echo   [OK] Dependencies installed ^(lockfile verified^)
        goto :deps_done
    )
    echo   [!] Lockfile failed, falling back to pip install...
)

"%UV_CMD%" pip install --python "%VENV_PYTHON%" -e ".[all]"
if errorlevel 1 (
    echo   [!] Full install failed, trying base package...
    "%UV_CMD%" pip install --python "%VENV_PYTHON%" -e .
    if errorlevel 1 (
        echo   [!] Failed to install dependencies.
        exit /b 1
    )
)
echo   [OK] Dependencies installed

:deps_done

REM ---- Step 5: Environment file + hermes home ----
echo   [5/6] Setting up environment...

if not exist "%HERMES_DIR%\.env" (
    if exist "%HERMES_DIR%\.env.example" (
        copy "%HERMES_DIR%\.env.example" "%HERMES_DIR%\.env" >nul
        echo   [OK] Created .env from template
    ) else (
        echo   [!] .env.example not found, skipping
    )
) else (
    echo   [OK] .env already exists
)

REM Create hermes home directory structure
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%"
if not exist "%HERMES_HOME%\skills" mkdir "%HERMES_HOME%\skills"
if not exist "%HERMES_HOME%\sessions" mkdir "%HERMES_HOME%\sessions"
if not exist "%HERMES_HOME%\logs" mkdir "%HERMES_HOME%\logs"
if not exist "%HERMES_HOME%\memories" mkdir "%HERMES_HOME%\memories"
if not exist "%HERMES_HOME%\cron" mkdir "%HERMES_HOME%\cron"

REM ---- Step 6: Sync bundled skills ----
echo   [6/6] Syncing bundled skills...

if exist "%HERMES_DIR%\tools\skills_sync.py" (
    "%VENV_PYTHON%" "%HERMES_DIR%\tools\skills_sync.py" 2>nul
    if not errorlevel 1 (
        echo   [OK] Skills synced
        goto :skills_done
    )
)

if exist "%HERMES_DIR%\skills" (
    xcopy "%HERMES_DIR%\skills\*" "%HERMES_HOME%\skills\" /e /i /q /y >nul 2>&1
    echo   [OK] Skills copied
    goto :skills_done
)

echo   [!] No bundled skills found

:skills_done

REM ---- Set HERMES_GIT_BASH_PATH if not set ----
if not defined HERMES_GIT_BASH_PATH (
    if exist "%ProgramFiles%\Git\bin\bash.exe" (
        setx HERMES_GIT_BASH_PATH "%ProgramFiles%\Git\bin\bash.exe" >nul 2>&1
        echo   [OK] Set HERMES_GIT_BASH_PATH=%ProgramFiles%\Git\bin\bash.exe
    )
)

REM ---- Done ----
echo.
echo   ================================
echo   Setup complete!
echo   ================================
echo.
echo   Next steps:
echo.
echo     1. Configure API keys:
echo        hermes.bat setup
echo.
echo     2. Start chatting:
echo        hermes.bat
echo.
echo     3. Start messaging gateway:
echo        hermes.bat gateway run      (foreground)
echo        hermes.bat gateway start    (background)
echo.
echo   Other commands:
echo     hermes.bat doctor    - Diagnose issues
echo     hermes.bat status    - Check configuration
echo     hermes.bat tools     - Configure tools
echo     hermes.bat model     - Choose LLM provider
echo     hermes.bat gateway status - Check gateway status
echo     hermes.bat gateway stop    - Stop gateway
echo     hermes.bat dashboard       - Start web UI dashboard
echo     hermes.bat dashboard --stop - Stop dashboard
echo.

set /p "RUN_WIZARD=Run the setup wizard now? [Y/n] "
if errorlevel 1 goto :exit_setup
if /i "%RUN_WIZARD%"=="n" goto :exit_setup

echo.
"%VENV_PYTHON%" -m hermes_cli.main setup
if errorlevel 1 goto :exit_setup
exit /b 0

:exit_setup
exit /b 0
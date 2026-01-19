@ECHO OFF
REM ════════════════════════════════════════════════════════════════
REM  GrEEV.com KG - EXECUTIONPOLICY FOUNDATION v2.0.0
REM  Smart Launcher - Auto-detects PowerShell 7 vs 5.1
REM  www.greev.com | support@greev.com
REM ════════════════════════════════════════════════════════════════

SETLOCAL ENABLEDELAYEDEXPANSION
chcp 65001 >nul 2>&1

SET "SCRIPT_NAME=%~1"
SET "LANGUAGE=%~2"

IF NOT DEFINED SCRIPT_NAME SET "SCRIPT_NAME=Start.ps1"
IF NOT DEFINED LANGUAGE SET "LANGUAGE=en"

REM ════════════════════════════════════════════════════════════════
REM  DETECT: PowerShell 7 (pwsh.exe) vs PowerShell 5.1 (powershell.exe)
REM ════════════════════════════════════════════════════════════════

SET "PS_EXECUTABLE=powershell.exe"

REM Try to find pwsh.exe (PowerShell 7+)
WHERE pwsh.exe >nul 2>&1
IF !ERRORLEVEL! EQU 0 (
    SET "PS_EXECUTABLE=pwsh.exe"
    ECHO [INFO] Using PowerShell 7+ (pwsh.exe)
) ELSE (
    ECHO [INFO] Using Windows PowerShell 5.1 (powershell.exe)
)

ECHO.
ECHO ============================================================
ECHO ExecutionPolicy Foundation v2.0.0 - GrEEV.com KG
ECHO ============================================================
ECHO.

REM ════════════════════════════════════════════════════════════════
REM  EXECUTE: Call PowerShell with Bypass ExecutionPolicy
REM ════════════════════════════════════════════════════════════════

%PS_EXECUTABLE% -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0!SCRIPT_NAME!' -ScriptName '!SCRIPT_NAME!' -Language '!LANGUAGE!'"

SET "EXIT_CODE=!ERRORLEVEL!"

IF !EXIT_CODE! EQU 0 (
    ECHO ============================================================
    ECHO [OK] Script completed successfully
    ECHO ============================================================
) ELSE (
    ECHO ============================================================
    ECHO [ERROR] Script failed with exit code !EXIT_CODE!
    ECHO ============================================================
    PAUSE
)

EXIT /B !EXIT_CODE!

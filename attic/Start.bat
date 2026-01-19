REM ================================================================
REM ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
REM █ GrEEV.com KG - EXECUTIONPOLICY FOUNDATION for PS v2.0.0 █
REM █ www.greev.com | office@greev.com | Dual Licensed █
REM ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
REM
REM Copyright (C) 2026 GrEEV.com KG. All rights reserved.
REM
REM Dual Licensed:
REM 1. AGPLv3 (Community Edition) - for OSS projects
REM 2. MIT License (Commercial-Friendly) - for commercial use
REM 3. Professional Support - EUR 499/year
REM
REM SPDX-License-Identifier: (AGPL-3.0-or-later OR MIT)
REM Support: support@greev.com | www.greev.com
REM ================================================================

@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

REM ================================================================
REM UTF-8 ENCODING FOR BOX-DRAWING CHARACTERS
REM ================================================================
chcp 65001 >nul 2>&1

REM ================================================================
REM PARAMETER PARSING
REM ================================================================

SET "SCRIPT_NAME=%~1"
SET "LANGUAGE=%~2"
SET "WHATIF=%~3"

IF NOT DEFINED SCRIPT_NAME SET "SCRIPT_NAME=Start.ps1"
IF NOT DEFINED LANGUAGE SET "LANGUAGE=en"
IF NOT DEFINED WHATIF SET "WHATIF=false"

REM ================================================================
REM MAIN EXECUTION
REM ================================================================

ECHO.
ECHO ╔================================================================╗
ECHO ║ ExecutionPolicy Foundation v2.0.0 - GrEEV.com KG ║
ECHO ║ Dual Licensed (AGPLv3/MIT) with Professional Support Option ║
ECHO ╚================================================================╝
ECHO.
ECHO Script Name: !SCRIPT_NAME!
ECHO Language:   !LANGUAGE!
ECHO WhatIf Mode: !WHATIF!
ECHO.

REM Run PowerShell launcher with proper encoding
POWERSHELL -NoProfile -ExecutionPolicy Bypass -Command ^
"[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '%~dp0Start.ps1' -ScriptName '!SCRIPT_NAME!' -Language '!LANGUAGE!' -WhatIf:$(!WHATIF! -eq 'true')"

SET "EXIT_CODE=!ERRORLEVEL!"

ECHO.
IF !EXIT_CODE! EQU 0 (
    ECHO ╔================================================================╗
    ECHO ║ ✓ Script completed successfully ║
    ECHO ║ Need support? support@greev.com (EUR 499/year) ║
    ECHO ╚================================================================╝
) ELSE (
    ECHO ╔================================================================╗
    ECHO ║ ✗ Script failed with exit code !EXIT_CODE! ║
    ECHO ║ Issues? Contact: office@greev.com ║
    ECHO ╚================================================================╝
    ECHO.
    PAUSE
)

EXIT /B !EXIT_CODE!

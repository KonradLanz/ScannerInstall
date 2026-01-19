#!/usr/bin/env powershell
# ================================================================
#  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄ 
#  █ GrEEV.com KG - EXECUTIONPOLICY FOUNDATION for PS v2.0.0    █
#  █ www.greev.com | office@greev.com | Dual Licensed           █
#  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀ 
#  
# Copyright (C) 2026 GrEEV.com KG. All rights reserved.
# 
# Dual Licensed:
# 1. AGPLv3 (Community Edition) - https://www.gnu.org/licenses/agpl-3.0.html
#    Free for open source projects and individual use
# 2. MIT License (Commercial-Friendly) - https://opensource.org/licenses/MIT
#    Permissive for commercial use and SaaS
# 
# Professional Support available: EUR 499/year
# Support: support@greev.com
# 
# SPDX-License-Identifier: (AGPL-3.0-or-later OR MIT)
# ================================================================

param(
    [string]$ScriptName = "setup.ps1",
    [string]$Language = "en",
    [switch]$WhatIf = $false,
    [switch]$ShowPolicies = $false,
    [switch]$Verbose = $false
)

# ================================================================
# UTF-8 ENCODING FIX FOR WINDOWS TERMINAL
# ================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ================================================================
# STRICT MODE & ERROR HANDLING
# ================================================================
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ================================================================
# CONFIGURATION
# ================================================================

$Config = @{
    ScriptDir       = Split-Path -Parent $MyInvocation.MyCommandPath
    ScriptName      = $ScriptName
    Language        = if ($Language -eq "de") { "de" } else { "en" }
    WhatIfMode      = $WhatIf.IsPresent
    ShowPolicies    = $ShowPolicies.IsPresent
    VerboseLogging  = $Verbose.IsPresent
}

# ================================================================
# LOCALIZATION (EN / DE)
# ================================================================

$Strings = @{
    en = @{
        title              = "ExecutionPolicy Foundation v2.0.0"
        subtitle           = "GrEEV.com KG - Dual Licensed (AGPLv3/MIT)"
        unblocking         = "Unblocking Zone.Identifier from downloaded files..."
        checking_policies  = "Checking ExecutionPolicy..."
        policies_locked    = "ExecutionPolicy is locked by Group Policy"
        executing_script   = "Executing script: {0}"
        error_not_found    = "Script not found: {0}"
        error_gpo_locked   = "Cannot bypass Group Policy lock. Contact IT admin."
        success            = "Script executed successfully"
        whatif_mode        = "WhatIf Mode: Not executing changes"
        support_info       = "Professional Support: support@greev.com | EUR 499/year"
        license_info       = "License: AGPLv3 (OSS) | MIT (Commercial) | Support"
    }
    de = @{
        title              = "ExecutionPolicy Foundation v2.0.0"
        subtitle           = "GrEEV.com KG - Dual Lizenz (AGPLv3/MIT)"
        unblocking         = "Zone.Identifier wird von heruntergeladenen Dateien entfernt..."
        checking_policies  = "ExecutionPolicy wird überprüft..."
        policies_locked    = "ExecutionPolicy ist durch Group Policy gesperrt"
        executing_script   = "Script wird ausgeführt: {0}"
        error_not_found    = "Script nicht gefunden: {0}"
        error_gpo_locked   = "Group Policy-Sperre kann nicht umgangen werden. Kontaktieren Sie IT-Admin."
        success            = "Script erfolgreich ausgeführt"
        whatif_mode        = "WhatIf Mode: Änderungen werden nicht durchgeführt"
        support_info       = "Professional Support: support@greev.com | EUR 499/Jahr"
        license_info       = "Lizenz: AGPLv3 (OSS) | MIT (Kommerziell) | Support"
    }
}

$Text = $Strings[$Config.Language]

# ================================================================
# FUNCTIONS
# ================================================================

function Write-Header {
    Write-Host ""
    Write-Host "╔================================================================╗" -ForegroundColor Cyan
    Write-Host "║  $($Text.title)" -ForegroundColor Cyan
    Write-Host "║  $($Text.subtitle)" -ForegroundColor Cyan
    Write-Host "╚================================================================╝" -ForegroundColor Cyan
    Write-Host ""
}

function Get-ExecutionPolicies {
    $policies = @{
        Scopes   = @("MachinePolicy", "UserPolicy", "Process", "CurrentUser", "LocalMachine")
        Policies = @()
    }
    
    foreach ($scope in $policies.Scopes) {
        $policy = Get-ExecutionPolicy -Scope $scope -ErrorAction SilentlyContinue
        $policies.Policies += @{ Scope = $scope; Policy = $policy }
    }
    
    return $policies
}

function Unblock-FilesInDirectory {
    param([string]$Path)
    
    Write-Host ""
    Write-Host $Text.unblocking -ForegroundColor Yellow
    
    $files = @(Get-ChildItem -Path $Path -Filter "*.ps1" -ErrorAction SilentlyContinue)
    
    if ($files.Count -eq 0) {
        if ($Config.Language -eq "de") {
            Write-Host "  Keine .ps1 Dateien gefunden" -ForegroundColor Gray
        } else {
            Write-Host "  No .ps1 files found" -ForegroundColor Gray
        }
        return
    }
    
    foreach ($file in $files) {
        if ($Config.WhatIfMode) {
            Write-Host "  [WhatIf] Unblock: $($file.Name)" -ForegroundColor Gray
        } else {
            Unblock-File -Path $file.FullName -ErrorAction SilentlyContinue
            Write-Host "  ✓ $($file.Name)" -ForegroundColor Green
        }
    }
}

function Invoke-MainScript {
    $scriptPath = Join-Path $Config.ScriptDir $Config.ScriptName
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host ""
        Write-Host "✗ $($Text.error_not_found -f $Config.ScriptName)" -ForegroundColor Red
        return $false
    }
    
    Write-Host ""
    Write-Host $($Text.executing_script -f $Config.ScriptName) -ForegroundColor Cyan
    
    if ($Config.WhatIfMode) {
        if ($Config.Language -eq "de") {
            Write-Host "[WhatIf] Würde ausführen: $scriptPath" -ForegroundColor Yellow
        } else {
            Write-Host "[WhatIf] Would execute: $scriptPath" -ForegroundColor Yellow
        }
    } else {
        & $scriptPath
    }
    
    return $LASTEXITCODE -eq 0
}

# ================================================================
# MAIN EXECUTION
# ================================================================

Write-Header

# Show current policies if requested
if ($Config.ShowPolicies) {
    if ($Config.Language -eq "de") {
        Write-Host "Aktuelle ExecutionPolicy Einstellungen:" -ForegroundColor Yellow
    } else {
        Write-Host "Current ExecutionPolicy Settings:" -ForegroundColor Yellow
    }
    $policies = Get-ExecutionPolicies
    foreach ($policy in $policies.Policies) {
        Write-Host "  $($policy.Scope): $($policy.Policy)" -ForegroundColor White
    }
    Write-Host ""
}

# Check for Group Policy lock
Write-Host $Text.checking_policies -ForegroundColor Cyan
$machinePolicy = Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue
if ($machinePolicy -eq "Restricted") {
    Write-Host "✗ $($Text.error_gpo_locked)" -ForegroundColor Red
    Write-Host ""
    if ($Config.Language -eq "de") {
        Write-Host "Dieses Skript kann nicht ausgeführt werden, da Group Policy ExecutionPolicy auf Restricted gesperrt hat." -ForegroundColor Yellow
        Write-Host "Wenden Sie sich bitte an Ihren IT-Administrator, um eine Richtlinienänderung anzufordern." -ForegroundColor Yellow
    } else {
        Write-Host "This script cannot run because Group Policy has locked ExecutionPolicy to Restricted." -ForegroundColor Yellow
        Write-Host "Please contact your IT administrator to request policy change." -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "✓ ExecutionPolicy check passed" -ForegroundColor Green

# Unblock files
Unblock-FilesInDirectory $Config.ScriptDir

# Show WhatIf mode
if ($Config.WhatIfMode) {
    Write-Host ""
    Write-Host $Text.whatif_mode -ForegroundColor Yellow
}

# Execute main script
if (Invoke-MainScript) {
    Write-Host ""
    Write-Host "✓ $($Text.success)" -ForegroundColor Green
    Write-Host ""
    Write-Host $Text.support_info -ForegroundColor Gray
    Write-Host $Text.license_info -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    if ($Config.Language -eq "de") {
        Write-Host "✗ Script-Ausführung fehlgeschlagen" -ForegroundColor Red
    } else {
        Write-Host "✗ Script execution failed" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}


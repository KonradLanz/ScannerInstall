# ================================================================
#  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄ 
#  █ GrEEV.com KG - SETUP SCRIPT v2.0.0                         █
#  █ www.greev.com | office@greev.com | Dual Licensed (MIT/AGPLv3)
#  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀ 
#  
# Copyright (C) 2026 GrEEV.com KG. All rights reserved.
# License: AGPLv3 (OSS) | MIT (Commercial) | See LICENSE files
# SPDX-License-Identifier: (AGPL-3.0-or-later OR MIT)
# ================================================================

param(
    [string]$Language = "en"
)

Set-StrictMode -Version Latest

# Localization
$Strings = @{
    en = @{
        title           = "ExecutionPolicy Foundation - Setup Script"
        congratulations = "Congratulations! The framework is ready to use."
        next_steps      = "Next steps:"
        step_1          = "1. Start with: .\Start.bat"
        step_2          = "2. Or directly: .\Start.ps1 -ShowPolicies"
        website         = "For help, visit: www.greev.com"
        support         = "Professional Support: support@greev.com"
    }
    de = @{
        title           = "ExecutionPolicy Foundation - Setup Script"
        congratulations = "Glückwunsch! Das Framework ist einsatzbereit."
        next_steps      = "Nächste Schritte:"
        step_1          = "1. Starten Sie mit: .\Start.bat"
        step_2          = "2. Oder direkt: .\Start.ps1 -ShowPolicies"
        website         = "Für Hilfe besuchen Sie: www.greev.com"
        support         = "Professional Support: support@greev.com"
    }
}

$Lang = if ($Language -eq "de") { "de" } else { "en" }
$Str = $Strings[$Lang]

Write-Host ""
Write-Host "╔================================================================╗" -ForegroundColor Green
Write-Host "║  $($Str.title)" -ForegroundColor Green
Write-Host "║  GrEEV.com KG - Dual Licensed (AGPLv3/MIT)                   ║" -ForegroundColor Green
Write-Host "╚================================================================╝" -ForegroundColor Green
Write-Host ""
Write-Host $Str.congratulations -ForegroundColor Yellow
Write-Host ""
Write-Host $Str.next_steps -ForegroundColor Cyan
Write-Host "  $($Str.step_1)" -ForegroundColor White
Write-Host "  $($Str.step_2)" -ForegroundColor White
Write-Host ""
Write-Host $Str.website -ForegroundColor Gray
Write-Host $Str.support -ForegroundColor Gray
Write-Host ""


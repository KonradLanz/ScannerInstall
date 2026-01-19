<#
.SYNOPSIS
    PowerShell-native launcher with GPO detection and Zone.Identifier handling

.DESCRIPTION
    Alternative to Start.bat for users who prefer PowerShell directly.
    Handles ExecutionPolicy, GPO detection, and file unblocking automatically.

.PARAMETER ScriptName
    PowerShell script to execute (default: setup.ps1)

.PARAMETER Language
    Output language: 'en' or 'de' (default: en)

.PARAMETER WhatIf
    Show what would happen without making changes

.PARAMETER SkipUnblock
    Skip the Zone.Identifier unblock phase

.PARAMETER ShowPolicies
    Display all ExecutionPolicy scopes and exit

.EXAMPLE
    .\Start.ps1
    .\Start.ps1 -ScriptName scanner-install.ps1 -Language de
    .\Start.ps1 -ScriptName verify.ps1 -WhatIf
    .\Start.ps1 -ShowPolicies

.NOTES
    Version: 2.0.0
    Date: 2026-01-18
    Author: ExecutionPolicy Foundation
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$ScriptName = 'setup.ps1',

    [Parameter(Position = 1)]
    [ValidateSet('en', 'de')]
    [string]$Language = 'en',

    [switch]$SkipUnblock,

    [switch]$ShowPolicies
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:Config = @{
    Version = '2.0.0'
    Date = '2026-01-18'
    UnblockScript = 'unblock-files_v1.0.0.ps1'
}

$script:Strings = @{
    en = @{
        title = "PowerShell Launcher v{0}"
        phase1 = "Phase 1: Validating script exists"
        phase2 = "Phase 2: Checking Group Policy restrictions"
        phase3 = "Phase 3: Unblocking downloaded files"
        phase4 = "Phase 4: Executing main script"
        script_not_found = "Script not found: {0}"
        available_scripts = "Available scripts:"
        gpo_blocked = "ExecutionPolicy is BLOCKED by Group Policy (MachinePolicy: {0})"
        gpo_blocked_detail = @"

This cannot be bypassed by normal users.

Solution:
  1. Contact your IT administrator
  2. Ask them to change Group Policy:
     Computer Configuration > Administrative Templates
     > Windows PowerShell > Execution Policy
     > Set to: RemoteSigned
"@
        gpo_ok = "No GPO restriction detected (MachinePolicy: {0})"
        unblock_skip = "Skipping unblock phase (--SkipUnblock)"
        unblock_not_found = "Unblock script not found - skipping"
        unblock_running = "Running unblock script..."
        executing = "Executing: {0}"
        success = "Script executed successfully"
        failed = "Script failed with exit code: {0}"
        policies_header = "ExecutionPolicy Status (all scopes):"
        whatif_mode = "[WhatIf] Dry-run mode - no changes will be made"
    }
    de = @{
        title = "PowerShell Launcher v{0}"
        phase1 = "Phase 1: Pruefe ob Skript existiert"
        phase2 = "Phase 2: Pruefe Gruppenrichtlinien"
        phase3 = "Phase 3: Entsperre heruntergeladene Dateien"
        phase4 = "Phase 4: Fuehre Hauptskript aus"
        script_not_found = "Skript nicht gefunden: {0}"
        available_scripts = "Verfuegbare Skripte:"
        gpo_blocked = "ExecutionPolicy ist durch Gruppenrichtlinie BLOCKIERT (MachinePolicy: {0})"
        gpo_blocked_detail = @"

Dies kann von normalen Benutzern NICHT umgangen werden.

Loesung:
  1. Kontaktieren Sie Ihren IT-Administrator
  2. Bitten Sie um Aenderung der Gruppenrichtlinie:
     Computer Configuration > Administrative Templates
     > Windows PowerShell > Execution Policy
     > Set to: RemoteSigned
"@
        gpo_ok = "Keine GPO-Blockierung erkannt (MachinePolicy: {0})"
        unblock_skip = "Ueberspringe Unblock-Phase (--SkipUnblock)"
        unblock_not_found = "Unblock-Skript nicht gefunden - ueberspringe"
        unblock_running = "Fuehre Unblock-Skript aus..."
        executing = "Starte: {0}"
        success = "Skript erfolgreich ausgefuehrt"
        failed = "Skript fehlgeschlagen mit Exit-Code: {0}"
        policies_header = "ExecutionPolicy Status (alle Scopes):"
        whatif_mode = "[WhatIf] Testmodus - keine Aenderungen werden vorgenommen"
    }
}

$msg = $script:Strings[$Language]

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-Phase {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
}

function Write-Status {
    param(
        [string]$Message, 
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        Info = 'White'
        Success = 'Green'
        Warning = 'Yellow'
        Error = 'Red'
    }
    $prefixes = @{
        Info = '[•]'
        Success = '[✓]'
        Warning = '[⚠]'
        Error = '[✗]'
    }

    Write-Host "$($prefixes[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Get-AllExecutionPolicies {
    $scopes = @('MachinePolicy', 'UserPolicy', 'Process', 'LocalMachine', 'CurrentUser')
    $policies = [ordered]@{}

    foreach ($scope in $scopes) {
        try {
            $policy = Get-ExecutionPolicy -Scope $scope -ErrorAction SilentlyContinue
            $policies[$scope] = $policy.ToString()
        }
        catch {
            $policies[$scope] = 'Error'
        }
    }

    return $policies
}

function Show-ExecutionPolicies {
    Write-Host ""
    Write-Host $msg.policies_header -ForegroundColor Cyan
    Write-Host ""

    $policies = Get-AllExecutionPolicies

    foreach ($scope in $policies.Keys) {
        $value = $policies[$scope]
        $color = switch ($value) {
            'Restricted' { 'Red' }
            'AllSigned' { 'Yellow' }
            'RemoteSigned' { 'Green' }
            'Unrestricted' { 'Yellow' }
            'Bypass' { 'Cyan' }
            'Undefined' { 'DarkGray' }
            default { 'White' }
        }

        $indicator = if ($scope -eq 'MachinePolicy' -and $value -eq 'Restricted') { ' ← BLOCKING' } else { '' }

        Write-Host ("  {0,-15} : " -f $scope) -NoNewline
        Write-Host ("{0}{1}" -f $value, $indicator) -ForegroundColor $color
    }
    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Header
Write-Host ""
Write-Host ("=" * 65) -ForegroundColor DarkCyan
Write-Host ($msg.title -f $script:Config.Version) -ForegroundColor Cyan
Write-Host ("=" * 65) -ForegroundColor DarkCyan

if ($WhatIf) {
    Write-Host $msg.whatif_mode -ForegroundColor Yellow
}

# Show policies only mode
if ($ShowPolicies) {
    Show-ExecutionPolicies
    exit 0
}

# ============================================================================
# PHASE 1: VALIDATE SCRIPT EXISTS
# ============================================================================

Write-Phase $msg.phase1

$scriptPath = Join-Path $PSScriptRoot $ScriptName

if (-not (Test-Path $scriptPath)) {
    Write-Status ($msg.script_not_found -f $ScriptName) 'Error'
    Write-Host ""
    Write-Host $msg.available_scripts -ForegroundColor Yellow

    Get-ChildItem -Path $PSScriptRoot -Filter "*.ps1" | ForEach-Object {
        Write-Host "  - $($_.Name)"
    }

    exit 1
}

Write-Status "Found: $ScriptName" 'Success'

# ============================================================================
# PHASE 2: GPO DETECTION
# ============================================================================

Write-Phase $msg.phase2

$machinePolicy = Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue

if ($machinePolicy -eq 'Restricted') {
    Write-Status ($msg.gpo_blocked -f $machinePolicy) 'Error'
    Write-Host $msg.gpo_blocked_detail -ForegroundColor Yellow

    Show-ExecutionPolicies
    exit 1
}

Write-Status ($msg.gpo_ok -f $machinePolicy) 'Success'

# ============================================================================
# PHASE 3: UNBLOCK FILES
# ============================================================================

Write-Phase $msg.phase3

if ($SkipUnblock) {
    Write-Status $msg.unblock_skip 'Info'
}
else {
    $unblockPath = Join-Path $PSScriptRoot $script:Config.UnblockScript

    if (-not (Test-Path $unblockPath)) {
        Write-Status $msg.unblock_not_found 'Warning'
    }
    else {
        Write-Status $msg.unblock_running 'Info'

        try {
            & $unblockPath -Language $Language
        }
        catch {
            Write-Status "Unblock script error: $_" 'Warning'
        }
    }
}

# ============================================================================
# PHASE 4: EXECUTE MAIN SCRIPT
# ============================================================================

Write-Phase $msg.phase4

Write-Status ($msg.executing -f $ScriptName) 'Info'
Write-Host ""

try {
    if ($WhatIf) {
        & $scriptPath -WhatIf
    }
    else {
        & $scriptPath
    }

    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
}
catch {
    Write-Status "Exception: $_" 'Error'
    $exitCode = 1
}

# ============================================================================
# PHASE 5: RESULT
# ============================================================================

Write-Host ""
Write-Host ("=" * 65) -ForegroundColor DarkGray

if ($exitCode -eq 0) {
    Write-Status $msg.success 'Success'
}
else {
    Write-Status ($msg.failed -f $exitCode) 'Error'
}

exit $exitCode


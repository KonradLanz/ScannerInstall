<#
.SYNOPSIS
    Start-ScannerSetup - Interactive SANE configuration for WSL/Linux

.DESCRIPTION
    PowerShell wrapper around sane-setup-interactive.sh
    Detects and configures Epson, Brother, HP, Fujitsu, Canon scanners
    with interactive prompts and automatic backups

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER NonInteractive
    Skip all prompts (automated setup)

.PARAMETER Debug
    Enable debug output

.PARAMETER SkipWSLCheck
    Skip WSL availability check

.EXAMPLE
    # Interactive setup with prompts
    ./Start-ScannerSetup.ps1

    # Preview changes without applying
    ./Start-ScannerSetup.ps1 -DryRun

    # Automated setup in CI/CD
    ./Start-ScannerSetup.ps1 -NonInteractive

.NOTES
    Requires: WSL with Ubuntu/Debian, sudo access
    License: AGPL-3.0 / MIT (Dual Licensed)
    Author: KonradLanz (GrEEV.com KG)
    
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$Debug,
    [switch]$SkipWSLCheck
)

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$SaneSetupScript = Join-Path $ScriptRoot "sane-setup-interactive.sh"

# ──────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠️  " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Debug {
    if ($Debug -or $DebugPreference -eq "Continue") {
        Write-Host "🔧 [DEBUG] " -ForegroundColor Magenta -NoNewline
        Write-Host "$args"
    }
}

function Test-WSL {
    Write-Info "Checking WSL availability..."
    
    $wslCheck = wsl --list --verbose 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "WSL is not installed or not available"
        Write-Info "Install WSL with: wsl --install -d Ubuntu"
        return $false
    }
    
    Write-Success "WSL is available"
    
    # Check for Ubuntu/Debian distro
    $hasUbuntu = $wslCheck | Select-String -Pattern "Ubuntu|Debian" -Quiet
    if (-not $hasUbuntu) {
        Write-Warn "No Ubuntu/Debian distribution found in WSL"
        Write-Info "Installing Ubuntu..."
        wsl --install -d Ubuntu --no-launch | Out-Null
    }
    
    return $true
}

function Get-WSLDistro {
    try {
        $distros = wsl --list --verbose | Where-Object { $_ -match "Ubuntu|Debian" } | 
                   ForEach-Object { ($_ -split '\s+')[0] }
        
        if ($distros) {
            # Prefer Ubuntu over Debian
            return ($distros | Where-Object { $_ -match "Ubuntu" } | Select-Object -First 1) ?? $distros[0]
        }
    }
    catch {
        Write-Debug "Error getting WSL distro: $_"
    }
    
    return "Ubuntu"
}

function Copy-ToWSL {
    param(
        [string]$LocalPath,
        [string]$WSLPath = "/tmp"
    )
    
    Write-Info "Copying to WSL: $(Split-Path $LocalPath -Leaf)"
    
    # Windows → WSL path conversion
    $driveLetter = $LocalPath[0]
    $windowsPath = $LocalPath -replace '\\', '/'
    $wslPath = "/mnt/$([char]::ToLower($driveLetter))/$($windowsPath.Substring(3))"
    
    Write-Debug "WSL path: $wslPath"
    return $wslPath
}

function Invoke-WSLCommand {
    param(
        [string]$Command,
        [string]$Distro = (Get-WSLDistro)
    )
    
    Write-Debug "Executing in WSL ($Distro): $Command"
    
    wsl --distribution $Distro --user root bash -c "$Command"
    return $LASTEXITCODE
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN WORKFLOW
# ──────────────────────────────────────────────────────────────────────────────

function Start-ScannerSetup {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  ScannerInstall - Interactive SANE Setup v2.0               ║" -ForegroundColor Cyan
    Write-Host "║  GrEEV.com KG | AGPL-3.0 / MIT (Dual Licensed)             ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Phase 1: WSL Check
    Write-Info "Phase 1: Environment Check"
    Write-Host "─────────────────────────────────"
    
    if (-not $SkipWSLCheck) {
        if (-not (Test-WSL)) {
            Write-Error "WSL setup failed. Please configure WSL manually."
            exit 1
        }
    }
    
    $distro = Get-WSLDistro
    Write-Success "Using WSL Distro: $distro"
    Write-Host ""
    
    # Phase 2: Verify setup script
    Write-Info "Phase 2: Script Setup"
    Write-Host "─────────────────────────────────"
    
    if (-not (Test-Path $SaneSetupScript)) {
        Write-Error "Setup script not found: $SaneSetupScript"
        Write-Info "Expected location: $ScriptRoot/sane-setup-interactive.sh"
        exit 1
    }
    
    Write-Success "Found: $(Split-Path $SaneSetupScript -Leaf)"
    
    # Copy script to WSL temp
    $wslScriptPath = "/tmp/sane-setup-interactive.sh"
    $localScriptPath = Copy-ToWSL $SaneSetupScript
    
    Write-Info "Making script executable in WSL..."
    Invoke-WSLCommand "chmod +x $localScriptPath" $distro | Out-Null
    Write-Success "Script ready"
    Write-Host ""
    
    # Phase 3: Execute setup
    Write-Info "Phase 3: Running SANE Setup"
    Write-Host "─────────────────────────────────"
    
    $wslArgs = @()
    if ($DryRun) { $wslArgs += "--dry-run" }
    if ($NonInteractive) { $wslArgs += "--non-interactive" }
    if ($Debug) { $wslArgs += "--debug" }
    
    $wslCommand = "$localScriptPath $($wslArgs -join ' ')"
    Write-Debug "Command: $wslCommand"
    Write-Host ""
    
    # Execute in WSL and capture output
    Invoke-WSLCommand $wslCommand $distro
    $exitCode = $LASTEXITCODE
    
    Write-Host ""
    
    if ($exitCode -eq 0) {
        Write-Success "SANE setup completed successfully"
    }
    else {
        Write-Error "Setup exited with code: $exitCode"
        exit $exitCode
    }
    
    # Phase 4: Post-setup info
    Write-Info "Phase 4: Post-Setup Information"
    Write-Host "─────────────────────────────────"
    
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "  1. Log out and back in (for group permissions to take effect)"
    Write-Host "  2. Test scanner detection:"
    Write-Host "     wsl scanimage -L"
    Write-Host "  3. Run your scanner app:"
    Write-Host "     wsl pct-scanner-script --lineart -Y 2025"
    Write-Host ""
    
    Write-Success "Setup completed!"
}

# ──────────────────────────────────────────────────────────────────────────────

try {
    Start-ScannerSetup
}
catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
    Write-Debug $_.ScriptStackTrace
    exit 1
}

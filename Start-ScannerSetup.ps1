# ScannerInstall - PowerShell Bootstrap v1.0.2
# (C) 2026 GrEEV.com KG. All rights reserved.
# Dual Licensed: MIT + AGPLv3
#
# Zentrale Koordination: WSL2 + usbipd + Linux SANE Setup
#
# FIXES v1.0.2:
# - Integrated TextFormatting.ps1 module from lib/
# - Professional formatting with Show-Banner, Show-Section, etc.
#
# FIXES v1.0.1:
# - Removed duplicate -Verbose parameter in CmdletBinding()
# - Fixed variable interpolation with ':' character
# - Improved parameter handling

param(
    [string]$ScannerModel = "DS-80W",
    [string]$WslDistribution = "Ubuntu-22.04",
    [string]$Language = "en",
    [switch]$FullSetup,
    [switch]$DryRun
)

# ============================================================================
# LOAD TEXTFORMATTING MODULE
# ============================================================================

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$textFormattingPath = Join-Path $scriptRoot "lib" "TextFormatting.ps1"

if (-not (Test-Path $textFormattingPath)) {
    Write-Error "TextFormatting module not found at: $textFormattingPath"
    Write-Error "Ensure lib/TextFormatting.ps1 exists in the script directory"
    exit 1
}

. $textFormattingPath

# ============================================================================
# CONFIGURATION
# ============================================================================

$config = @{
    ProjectRoot = Split-Path -Parent $PSScriptRoot
    ScannerConfigPath = Join-Path $PSScriptRoot "Scanner.config.json"
    LogsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "logs"
    ScriptsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts"
    LinuxScriptsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "linux"
}

# Ensure logs directory
if (-not (Test-Path $config.LogsPath)) {
    New-Item -ItemType Directory -Path $config.LogsPath -Force | Out-Null
}

$LogFile = Join-Path $config.LogsPath "ScannerInstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Log-Message {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = "White"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $logMessage
}

function Log-Success {
    param([string]$Message)
    Log-Message "✓ $Message" -Level "SUCCESS" -Color Green
}

function Log-Error {
    param([string]$Message)
    Log-Message "✗ $Message" -Level "ERROR" -Color Red
}

function Log-Warning {
    param([string]$Message)
    Log-Message "⚠ $Message" -Level "WARNING" -Color Yellow
}

function Log-Info {
    param([string]$Message)
    Log-Message "ℹ $Message" -Level "INFO" -Color Cyan
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Load-ScannerConfig {
    param([string]$ConfigPath)

    Log-Info "Loading scanner configuration from: $ConfigPath"

    if (-not (Test-Path $ConfigPath)) {
        Log-Error "Scanner configuration not found at: $ConfigPath"
        return $null
    }

    try {
        $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        Log-Success "Configuration loaded: $($configContent.scanner.name)"
        return $configContent
    }
    catch {
        Log-Error "Failed to load configuration: $_"
        return $null
    }
}

function Test-WSL2Installation {
    Log-Info "Testing WSL2 installation..."

    try {
        $wslVersion = wsl --version 2>$null
        if ($wslVersion) {
            Log-Success "WSL2 is installed:"
            Write-Host "  $wslVersion" -ForegroundColor Gray
            return $true
        }
        else {
            Log-Warning "WSL2 not found or not in PATH"
            return $false
        }
    }
    catch {
        Log-Warning "Error testing WSL2: $_"
        return $false
    }
}

function Test-UsbIPD {
    Log-Info "Testing usbipd-win installation..."

    try {
        $usbipd = Get-Command usbipd -ErrorAction SilentlyContinue
        if ($usbipd) {
            $version = usbipd --version 2>$null
            Log-Success "usbipd-win is installed:"
            Write-Host "  $version" -ForegroundColor Gray
            return $true
        }
        else {
            Log-Warning "usbipd-win not found or not in PATH"
            return $false
        }
    }
    catch {
        Log-Warning "Error testing usbipd: $_"
        return $false
    }
}

function Test-GitInstallation {
    Log-Info "Testing Git installation..."

    try {
        $gitVersion = git --version
        Log-Success "Git is installed: $gitVersion"
        return $true
    }
    catch {
        Log-Warning "Git not found: $_"
        return $false
    }
}

# ============================================================================
# MAIN SETUP FLOW
# ============================================================================

function Show-PreflightChecks {
    Show-Section "PREFLIGHT CHECKS"

    # 1. Admin Rights
    if (Test-AdminPrivileges) {
        Log-Success "Running with Administrator privileges"
    }
    else {
        Log-Warning "NOT running with Administrator privileges (some features may fail)"
        Write-Host "  Recommended: Run PowerShell as Administrator" -ForegroundColor Yellow
    }

    Write-Host ""

    # 2. WSL2
    $wsl2OK = Test-WSL2Installation

    # 3. usbipd
    $usbipd_OK = Test-UsbIPD
    if (-not $usbipd_OK) {
        Write-Host "  Status: Can be installed via winget" -ForegroundColor Gray
    }

    # 4. Git
    $gitOK = Test-GitInstallation

    # 5. Config
    Write-Host ""
    Log-Info "Checking configuration files..."

    if (Test-Path $config.ScannerConfigPath) {
        Log-Success "Scanner configuration file found"
    }
    else {
        Log-Error "Scanner configuration file NOT found at: $($config.ScannerConfigPath)"
    }

    Write-Host ""

    # Summary
    Show-Section "SUMMARY"

    $status = @{
        "Admin Rights" = if (Test-AdminPrivileges) { "✓" } else { "⚠" }
        "WSL2" = if ($wsl2OK) { "✓" } else { "✗ (Install required)" }
        "usbipd-win" = if ($usbipd_OK) { "✓" } else { "○ (Will install)" }
        "Git" = if ($gitOK) { "✓" } else { "✗ (Install required)" }
        "Configuration" = if (Test-Path $config.ScannerConfigPath) { "✓" } else { "✗" }
    }

    foreach ($check in $status.Keys) {
        Write-Host "  $($check): $($status[$check])" -ForegroundColor Gray
    }

    Write-Host ""

    if (-not $wsl2OK -or -not $gitOK) {
        Log-Error "Critical prerequisites missing!"
        Log-Error "WSL2 and Git are required."
        Write-Host "  Install from: https://learn.microsoft.com/en-us/windows/wsl/install" -ForegroundColor Yellow
        Write-Host "  Install from: https://git-scm.com/download/win" -ForegroundColor Yellow
        return $false
    }

    return $true
}

function Show-Menu {
    Write-Host ""
    Show-Section "SETUP WIZARD - $($ScannerModel) on $($WslDistribution)"

    Write-Host "Choose setup mode:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1) Full Automated Setup (All steps)" -ForegroundColor Cyan
    Write-Host "  2) Interactive Step-by-Step" -ForegroundColor Cyan
    Write-Host "  3) WSL2 Check Only" -ForegroundColor Cyan
    Write-Host "  4) usbipd Installation Only" -ForegroundColor Cyan
    Write-Host "  5) SANE Configuration Only" -ForegroundColor Cyan
    Write-Host "  6) Test Existing Setup" -ForegroundColor Cyan
    Write-Host "  7) View Configuration" -ForegroundColor Cyan
    Write-Host "  8) Exit" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-Host "Enter option (1-8)"
    return $choice
}

function Invoke-FullAutomatedSetup {
    Log-Info "Starting Full Automated Setup..."

    Write-Host ""
    Write-Host "This will:" -ForegroundColor Yellow
    Write-Host "  • Check/Install WSL2" -ForegroundColor Gray
    Write-Host "  • Install usbipd-win" -ForegroundColor Gray
    Write-Host "  • Setup SANE in WSL" -ForegroundColor Gray
    Write-Host "  • Configure udev rules" -ForegroundColor Gray
    Write-Host "  • Attach USB device" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne "y") {
        Log-Info "Setup cancelled"
        return
    }

    # Load and execute Scanner.Install.Module.ps1
    $moduleFile = Join-Path $config.ProjectRoot "src\Scanner.Install.Module_v1.0.1.ps1"
    if (Test-Path $moduleFile) {
        Log-Success "Launching interactive setup module..."
        Write-Host ""
        & $moduleFile -ScannerModel $ScannerModel -WslDistribution $WslDistribution -Language $Language
    }
    else {
        Log-Error "Setup module not found: $moduleFile"
        Log-Info "Ensure Scanner.Install.Module_v1.0.1.ps1 exists in src/ directory"
    }
}

function Show-Configuration {
    $scannerConfig = Load-ScannerConfig -ConfigPath $config.ScannerConfigPath

    if ($null -eq $scannerConfig) {
        Log-Error "Configuration not loaded"
        return
    }

    Show-Section "SCANNER CONFIGURATION"

    Write-Host "Scanner Details:" -ForegroundColor White
    Write-Host "  Name:        $($scannerConfig.scanner.name)" -ForegroundColor Gray
    Write-Host "  Model:       $($scannerConfig.scanner.model)" -ForegroundColor Gray
    Write-Host "  Vendor ID:   $($scannerConfig.scanner.vendor_id)" -ForegroundColor Gray
    Write-Host "  Product ID:  $($scannerConfig.scanner.product_id)" -ForegroundColor Gray
    Write-Host "  Driver:      $($scannerConfig.scanner.driver)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "WSL Support:" -ForegroundColor White
    foreach ($distro in $scannerConfig.wsl.supported_distributions) {
        $status = if ($distro.tested) { "✓" } else { "○" }
        Write-Host "  $status $($distro.name) ($($distro.id))" -ForegroundColor Gray
    }

    Write-Host ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    # Show Banner
    Show-Banner "ScannerInstall v1.0.2" "Universal Scanner Installation & USB-Binding for WSL2 + Linux"

    # Preflight checks
    if (-not (Show-PreflightChecks)) {
        Log-Error "Preflight checks failed. Exiting."
        exit 1
    }

    # Load configuration
    $scannerConfig = Load-ScannerConfig -ConfigPath $config.ScannerConfigPath
    if ($null -eq $scannerConfig) {
        Log-Error "Failed to load scanner configuration"
        exit 1
    }

    # Interactive menu loop
    do {
        $choice = Show-Menu

        switch ($choice) {
            "1" { Invoke-FullAutomatedSetup }
            "2" {
                Log-Info "Interactive mode - launching setup module..."
                $moduleFile = Join-Path $config.ProjectRoot "src\Scanner.Install.Module_v1.0.1.ps1"
                & $moduleFile -ScannerModel $ScannerModel -WslDistribution $WslDistribution -Language $Language
            }
            "3" { Log-Info "WSL2 Check only - TODO" }
            "4" { Log-Info "usbipd Install only - TODO" }
            "5" { Log-Info "SANE Configuration only - TODO" }
            "6" { Log-Info "Test Setup - TODO" }
            "7" { Show-Configuration }
            "8" {
                Log-Success "Exiting ScannerInstall"
                exit 0
            }
            default {
                Log-Error "Invalid option: $choice"
            }
        }

        Write-Host ""
        Read-Host "Press Enter to continue..."
    } while ($true)
}
catch {
    Log-Error "Fatal error: $_"
    Log-Error $_.ScriptStackTrace
    exit 1
}
finally {
    Log-Info "Log file saved to: $LogFile"
}

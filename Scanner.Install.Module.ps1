# ScannerInstall - PowerShell Hauptmodul v1.0.2
# (C) 2026 GrEEV.com KG. All rights reserved.
# Dual Licensed: MIT + AGPLv3

<#
.SYNOPSIS
    Interaktives Scanner-Installation & USB-Binding Modul für WSL2

.DESCRIPTION
    Automatisiert Installation von:
    - WSL2 + Distribution Selection
    - usbipd-win für USB-Device-Binding
    - SANE + Scanner-spezifische Treiber
    - udev Rules & Kernel Module

.PARAMETER ScannerModel
    Scanner-Modell (Default: DS-80W)

.PARAMETER WslDistribution
    WSL Distribution (ubuntu-22.04, alpine-latest, etc.)

.PARAMETER SkipWslInstall
    Überspringt WSL2-Installation wenn bereits vorhanden

.PARAMETER DryRun
    Zeigt nur was gemacht würde, führt nichts aus

.EXAMPLE
    .\Scanner.Install.Module.ps1 -ScannerModel "DS-80W" -DryRun

.NOTES
    Benötigt: PowerShell 5.1+ oder 7.5+
    Admin-Rechte für usbipd & WSL Installation

    FIXES v1.0.2:
    - Integrated TextFormatting.ps1 module from lib/
    - Professional formatting with Show-Banner, Show-Section, etc.

    FIXES v1.0.1:
    - Fixed variable interpolation with ':' (use ${} syntax)
    - Removed CmdletBinding() Verbose parameter duplication
    - Improved error handling
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ScannerModel = "DS-80W",

    [Parameter(Mandatory=$false)]
    [string]$WslDistribution = "Ubuntu-22.04",

    [Parameter(Mandatory=$false)]
    [switch]$SkipWslInstall,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [string]$Language = "en"  # "en" oder "de"
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
# CONFIGURATION - Scanner Parameter laden
# ============================================================================

$configPath = Join-Path $PSScriptRoot "Scanner.config.json"

function Load-ScannerConfig {
    param([string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Scanner config nicht gefunden: $ConfigPath"
        return $null
    }

    try {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        Write-Verbose "Scanner Config geladen: $($config.scanner.model)"
        return $config
    }
    catch {
        Write-Error "Fehler beim Laden der Config: $_"
        return $null
    }
}

# ============================================================================
# MESSAGES - Mehrsprachig (EN/DE)
# ============================================================================

$messages = @{
    "en" = @{
        "menu_title" = "ScannerInstall v1.0.2 - Interactive Setup"
        "menu_check_wsl2" = "Check WSL2 & Install Distribution"
        "menu_install_usbipd" = "Install usbipd-win"
        "menu_prepare_distro" = "Prepare WSL Distribution (SANE)"
        "menu_attach_usb" = "Attach USB Scanner Device"
        "menu_test_scanner" = "Test Scanner & Validation"
        "menu_configure" = "Configure Epson Scanner"
        "menu_view_logs" = "View Logs"
        "menu_exit" = "Exit"
        "select_option" = "Select option (1-8): "
    }
    "de" = @{
        "menu_title" = "ScannerInstall v1.0.2 - Interaktives Setup"
        "menu_check_wsl2" = "WSL2 prüfen & Distribution installieren"
        "menu_install_usbipd" = "usbipd-win installieren"
        "menu_prepare_distro" = "WSL-Distribution vorbereiten (SANE)"
        "menu_attach_usb" = "USB-Scanner anschließen"
        "menu_test_scanner" = "Scanner testen & Validierung"
        "menu_configure" = "Epson-Scanner konfigurieren"
        "menu_view_logs" = "Logs anzeigen"
        "menu_exit" = "Beenden"
        "select_option" = "Option wählen (1-8): "
    }
}

$lang = $messages[$Language] ?? $messages["en"]

# ============================================================================
# STEP 1: WSL2 Detection & Installation
# ============================================================================

function Invoke-WSL2Check {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Distribution = "Ubuntu-22.04",
        [bool]$SkipInstall = $false
    )

    Show-Section "STEP 1: WSL2 Detection & Installation"

    # 1a: WSL2 vorhanden?
    $wsl2Version = wsl --version 2>$null
    if ($wsl2Version) {
        Write-FormattedSuccess "WSL2 is installed: $wsl2Version"
    }
    else {
        Write-FormattedWarning "WSL2 not found. Installation needed..."
        if ($PSCmdlet.ShouldProcess("WSL2", "Enable and Install")) {
            wsl --install --no-launch
            Write-FormattedSuccess "WSL2 enabled. System restart required!"
            Read-Host "After restart, run this script again..."
            exit
        }
        return $false
    }

    # 1b: Installierte Distributionen auflisten
    Write-Host "`nInstalled WSL Distributions:" -ForegroundColor Cyan
    $wslList = wsl -l --verbose
    Write-Host $wslList

    # 1c: Distro Selection
    $selectedDistro = $Distribution
    $distroExists = $wslList | Select-String $Distribution

    if (-not $distroExists) {
        Write-FormattedInfo "Distribution '$Distribution' not installed."

        if ($PSCmdlet.ShouldProcess("WSL", "Install $Distribution")) {
            Write-Host "Installing $Distribution..."
            wsl --install -d $Distribution --no-launch
            Write-FormattedSuccess "Distribution '$Distribution' installed"
        }
    }
    else {
        Write-FormattedSuccess "Distribution '$selectedDistro' is available"
    }

    # 1d: Distribution Versions-Check
    Write-FormattedInfo "Version check for $selectedDistro..."
    $versionInfo = wsl -d $selectedDistro cat /etc/lsb-release-codename 2>$null || `
                   wsl -d $selectedDistro cat /etc/os-release | Select-String "VERSION="
    Write-Host "   $versionInfo" -ForegroundColor Gray

    return $true
}

# ============================================================================
# STEP 2: usbipd-win Installation
# ============================================================================

function Invoke-USBIPDInstall {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Show-Section "STEP 2: usbipd-win Installation"

    # 2a: Check ob bereits installiert
    $usbipd = Get-Command usbipd -ErrorAction SilentlyContinue
    if ($usbipd) {
        Write-FormattedSuccess "usbipd-win is already installed"
        usbipd --version
        return $true
    }

    Write-FormattedWarning "usbipd-win not found. Installing..."

    if ($PSCmdlet.ShouldProcess("usbipd-win", "Install via winget")) {
        try {
            Write-FormattedInfo "Installing dorssel.usbipd-win..."

            & winget install --interactive --exact "dorssel.usbipd-win" `
                --accept-package-agreements `
                --accept-source-agreements `
                --force 2>&1 | Tee-Object -Variable installLog

            if ($LASTEXITCODE -eq 0) {
                Write-FormattedSuccess "usbipd-win installation successful"

                # Neustart des Services
                Get-Service usbipd -ErrorAction SilentlyContinue |
                    Restart-Service -Force

                Write-FormattedSuccess "usbipd service restarted"
                return $true
            }
            else {
                Write-FormattedWarning "Installation failed. Trying GitHub Download..."

                # Fallback: GitHub Release
                $downloadUrl = "https://github.com/dorssel/usbipd-win/releases/latest"
                Write-FormattedInfo "Please download manually: $downloadUrl"
                Start-Process $downloadUrl
                return $false
            }
        }
        catch {
            Write-FormattedError "Error during usbipd installation: $_"
            return $false
        }
    }

    return $false
}

# ============================================================================
# STEP 3: WSL Distribution vorbereiten (SANE Setup)
# ============================================================================

function Invoke-DistroPreparation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Distribution = "Ubuntu-22.04",
        [object]$ScannerConfig
    )

    Show-Section "STEP 3: WSL Distribution Preparation"

    $vendorId = $ScannerConfig.scanner.vendor_id
    $productId = $ScannerConfig.scanner.product_id
    $scannerName = $ScannerConfig.scanner.name

    Write-FormattedInfo "Target Distribution: $Distribution"
    Write-FormattedInfo "Scanner: $scannerName ($($vendorId):$($productId))"

    # 3a: Distro-Erkennung (Ubuntu vs Alpine)
    $distroType = if ($Distribution -match "Alpine") { "alpine" } else { "ubuntu" }
    Write-FormattedInfo "Distro type detected: $distroType"

    # 3b: SANE Installation (distro-spezifisch)
    Write-FormattedInfo "Installing SANE + Epson Driver..."

    if ($PSCmdlet.ShouldProcess("WSL:$Distribution", "Install SANE")) {
        if ($distroType -eq "alpine") {
            # Alpine (apk)
            $saneSetupScript = @"
#!/bin/ash
set -e
echo "[Alpine SANE Setup]"
apk update
apk add sane sane-backends-libsane sane-backends-epson
apk add usbutils usbip-tools
echo "✓ SANE for Alpine installed"
"@
        }
        else {
            # Ubuntu/Debian (apt)
            $saneSetupScript = @"
#!/bin/bash
set -e
echo "[Ubuntu SANE Setup]"
sudo apt-get update -qq
sudo apt-get install -y sane sane-utils libsane1
sudo apt-get install -y libsane-epson
sudo apt-get install -y usbutils usbip-tools
echo "✓ SANE for Ubuntu installed"
"@
        }

        # Script in WSL ausführen
        $saneSetupScript | wsl -d $Distribution /bin/bash
    }

    # 3c: Kernel Module Setup (SANE benötigt vhci-hcd)
    Write-FormattedInfo "Setting up kernel modules..."

    if ($PSCmdlet.ShouldProcess("WSL:$Distribution", "Setup kernel modules")) {
        if ($distroType -eq "alpine") {
            # Alpine OpenRC
            $moduleScript = @"
#!/bin/ash
set -e
echo 'vhci_hcd' | sudo tee /etc/modules-load.d/vhci-hcd.conf
echo 'usbip_core' | sudo tee -a /etc/modules-load.d/vhci-hcd.conf
echo 'usbip_host' | sudo tee -a /etc/modules-load.d/vhci-hcd.conf
echo "✓ Kernel modules configured (Alpine)"
"@
        }
        else {
            # Ubuntu systemd
            $moduleScript = @"
#!/bin/bash
set -e
echo 'vhci-hcd' | sudo tee /etc/modules-load.d/vhci-hcd.conf
echo 'usbip-core' | sudo tee -a /etc/modules-load.d/vhci-hcd.conf
echo 'usbip-host' | sudo tee -a /etc/modules-load.d/vhci-hcd.conf
sudo systemctl enable systemd-modules-load
echo "✓ Kernel modules configured (systemd)"
"@
        }

        $moduleScript | wsl -d $Distribution /bin/bash
    }

    # 3d: udev Rules Setup
    Write-FormattedInfo "Setting up udev rules..."

    if ($PSCmdlet.ShouldProcess("WSL:$Distribution", "Setup udev rules")) {
        $udevRules = @"
# $scannerName ($($vendorId):$($productId))
SUBSYSTEMS=="usb", ATTRS{idVendor}=="$vendorId", ATTRS{idProduct}=="$productId", MODE="0666", GROUP="lpadmin"
SUBSYSTEMS=="usb_device", ATTRS{idVendor}=="$vendorId", ATTRS{idProduct}=="$productId", MODE="0666", GROUP="lpadmin"
"@

        $scriptToRun = @"
#!/bin/bash
set -e
echo '$udevRules' | sudo tee /etc/udev/rules.d/50-epson-$productId.rules
sudo udevadm control --reload-rules
echo "✓ udev rules installed"
"@

        $scriptToRun | wsl -d $Distribution /bin/bash
    }

    Write-FormattedSuccess "Distribution prepared"
    return $true
}

# ============================================================================
# STEP 4: USB Device Binding (usbipd attach)
# ============================================================================

function Invoke-USBDeviceBinding {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Distribution = "Ubuntu-22.04",
        [object]$ScannerConfig
    )

    Show-Section "STEP 4: USB Device Binding"

    $vendorId = $ScannerConfig.scanner.vendor_id
    $productId = $ScannerConfig.scanner.product_id

    # 4a: Liste USB Devices
    Write-FormattedInfo "Available USB devices:"
    $usbList = usbipd list
    Write-Host $usbList -ForegroundColor Gray

    # 4b: Scanner Device finden
    $hardwareId = "$vendorId`:$productId"
    Write-FormattedInfo "Searching for scanner ($hardwareId)..."

    $scannerDevice = $usbList | Select-String "$vendorId`:$productId"

    if (-not $scannerDevice) {
        Write-FormattedError "Scanner with ID $hardwareId not found!"
        Write-FormattedWarning "Please connect your scanner and try again."
        return $false
    }

    Write-FormattedSuccess "Scanner found: $scannerDevice"

    # 4c: Bind zum WSL
    if ($PSCmdlet.ShouldProcess("usbipd", "Bind device $hardwareId to $Distribution")) {
        Write-FormattedInfo "Connecting scanner to WSL..."

        try {
            # Erst unbind falls bereits gebunden
            usbipd unbind --hardware-id="$vendorId`:$productId" -f 2>$null

            # Bind
            usbipd bind --hardware-id="$vendorId`:$productId"

            # Auto-attach für WSL
            usbipd attach --wsl --hardware-id="$vendorId`:$productId" --auto-attach 2>$null || `
            usbipd attach --wsl --hardware-id="$vendorId`:$productId"

            Write-FormattedSuccess "Scanner bound to WSL"

            # Verify
            Start-Sleep -Seconds 2
            $attachedDevices = usbipd list | Select-String "Attached"
            Write-FormattedInfo "Attached devices:"
            Write-Host $attachedDevices -ForegroundColor Gray

            return $true
        }
        catch {
            Write-FormattedError "Error during device binding: $_"
            return $false
        }
    }

    return $false
}

# ============================================================================
# STEP 5: Scanner Test & Validierung
# ============================================================================

function Invoke-ScannerTest {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Distribution = "Ubuntu-22.04",
        [object]$ScannerConfig
    )

    Show-Section "STEP 5: Scanner Test & Validation"

    Write-FormattedInfo "Running SANE tests in WSL..."

    # 5a: lsmod | grep vhci
    Write-Host "`n1. Kernel Module Check:" -ForegroundColor Cyan
    $moduleCheck = wsl -d $Distribution lsmod
    $vhciModules = $moduleCheck | Select-String "vhci"

    if ($vhciModules) {
        Write-FormattedSuccess "vhci kernel modules active:"
        Write-Host $vhciModules -ForegroundColor Gray
    }
    else {
        Write-FormattedWarning "vhci kernel modules NOT active!"
        Write-FormattedInfo "Trying: sudo modprobe vhci-hcd"

        if ($PSCmdlet.ShouldProcess("WSL:$Distribution", "Load vhci-hcd module")) {
            wsl -d $Distribution sudo modprobe vhci-hcd
            wsl -d $Distribution sudo modprobe usbip-core
            wsl -d $Distribution sudo modprobe usbip-host
            Write-FormattedSuccess "Modules loaded"
        }
    }

    # 5b: sane-find-scanner
    Write-Host "`n2. SANE Scanner Detection:" -ForegroundColor Cyan
    $scannerDetection = wsl -d $Distribution sudo sane-find-scanner -v 2>&1
    Write-Host $scannerDetection -ForegroundColor Gray

    if ($scannerDetection -match "found scanner") {
        Write-FormattedSuccess "Scanner detected by SANE!"
    }
    else {
        Write-FormattedWarning "Scanner NOT detected by SANE"
        Write-FormattedInfo "Check USB binding and udev rules"
    }

    # 5c: scanimage -L
    Write-Host "`n3. SANE Devices List:" -ForegroundColor Cyan
    $saneDevices = wsl -d $Distribution scanimage -L 2>&1
    Write-Host $saneDevices -ForegroundColor Gray

    # 5d: udev Monitor
    Write-Host "`n4. USB Device Logs (last 10 lines):" -ForegroundColor Cyan
    $usbLogs = wsl -d $Distribution dmesg | tail -10
    Write-Host $usbLogs -ForegroundColor Gray

    return $true
}

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

function Show-InteractiveMenu {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [object]$Config
    )

    Clear-Host
    Show-Banner "ScannerInstall v1.0.2" "Interactive Setup"

    Write-Host ""
    Write-FormattedInfo "Scanner: $($Config.scanner.name) ($($Config.scanner.vendor_id):$($Config.scanner.product_id))"
    Write-FormattedInfo "Distribution: $WslDistribution"
    Write-Host ""

    Write-Host "1) $($lang.menu_check_wsl2)" -ForegroundColor Cyan
    Write-Host "2) $($lang.menu_install_usbipd)" -ForegroundColor Cyan
    Write-Host "3) $($lang.menu_prepare_distro)" -ForegroundColor Cyan
    Write-Host "4) $($lang.menu_attach_usb)" -ForegroundColor Cyan
    Write-Host "5) $($lang.menu_test_scanner)" -ForegroundColor Cyan
    Write-Host "6) $($lang.menu_configure)" -ForegroundColor Cyan
    Write-Host "7) $($lang.menu_view_logs)" -ForegroundColor Cyan
    Write-Host "8) $($lang.menu_exit)`n" -ForegroundColor Cyan

    $choice = Read-Host $lang.select_option

    switch ($choice) {
        "1" { Invoke-WSL2Check -Distribution $WslDistribution -SkipInstall $SkipWslInstall }
        "2" { Invoke-USBIPDInstall }
        "3" { Invoke-DistroPreparation -Distribution $WslDistribution -ScannerConfig $Config }
        "4" { Invoke-USBDeviceBinding -Distribution $WslDistribution -ScannerConfig $Config }
        "5" { Invoke-ScannerTest -Distribution $WslDistribution -ScannerConfig $Config }
        "6" { Write-FormattedInfo "TODO: Epson-specific configuration" }
        "7" { Write-FormattedInfo "TODO: Log viewer" }
        "8" { exit 0 }
        default { Write-FormattedError "Invalid input" }
    }

    Read-Host "Press Enter to continue..."
    Show-InteractiveMenu -Config $Config
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

try {
    # Config laden
    $config = Load-ScannerConfig -ConfigPath $configPath
    if (-not $config) {
        Write-FormattedError "Config could not be loaded!"
        exit 1
    }

    # Interaktives Menu starten
    Show-InteractiveMenu -Config $config
}
catch {
    Write-FormattedError "Error: $_"
    Write-FormattedError $_.ScriptStackTrace
    exit 1
}
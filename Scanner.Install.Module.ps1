# ScannerInstall - PowerShell Hauptmodul v1.0.1 (FIXED)
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
# CONFIGURATION - Scanner Parameter laden
# ============================================================================

$configPath = Join-Path (Split-Path $PSScriptRoot) "config\Scanner.config.json"

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
        "menu_title" = "ScannerInstall v1.0.1 - Interactive Setup"
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
        "menu_title" = "ScannerInstall v1.0.1 - Interaktives Setup"
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
    
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ STEP 1: WSL2 Detection & Installation                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # 1a: WSL2 vorhanden?
    $wsl2Version = wsl --version 2>$null
    if ($wsl2Version) {
        Write-Host "✓ WSL2 ist installiert: $wsl2Version" -ForegroundColor Green
    }
    else {
        Write-Host "✗ WSL2 nicht gefunden. Installation nötig..." -ForegroundColor Yellow
        if ($PSCmdlet.ShouldProcess("WSL2", "Enable and Install")) {
            wsl --install --no-launch
            Write-Host "✓ WSL2 aktiviert. System-Neustart erforderlich!" -ForegroundColor Green
            Read-Host "Nach Neustart dieses Skript erneut ausführen..."
            exit
        }
        return $false
    }
    
    # 1b: Installierte Distributionen auflisten
    Write-Host "`nInstallierte WSL-Distributionen:" -ForegroundColor Cyan
    $wslList = wsl -l --verbose
    Write-Host $wslList
    
    # 1c: Distro Selection
    $selectedDistro = $Distribution
    $distroExists = $wslList | Select-String $Distribution
    
    if (-not $distroExists) {
        Write-Host "`nDistribution '$Distribution' nicht installiert." -ForegroundColor Yellow
        
        if ($PSCmdlet.ShouldProcess("WSL", "Install $Distribution")) {
            Write-Host "Installiere $Distribution..."
            wsl --install -d $Distribution --no-launch
            Write-Host "✓ $Distribution installiert" -ForegroundColor Green
        }
    }
    else {
        Write-Host "✓ Distribution '$selectedDistro' ist vorhanden" -ForegroundColor Green
    }
    
    # 1d: Distribution Versions-Check
    Write-Host "`nVersion Check für $selectedDistro..." -ForegroundColor Cyan
    $versionInfo = wsl -d $selectedDistro cat /etc/lsb-release-codename 2>$null || `
                   wsl -d $selectedDistro cat /etc/os-release | grep "VERSION="
    Write-Host "   $versionInfo" -ForegroundColor Gray
    
    return $true
}

# ============================================================================
# STEP 2: usbipd-win Installation
# ============================================================================

function Invoke-USBIPDInstall {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ STEP 2: usbipd-win Installation                        ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # 2a: Check ob bereits installiert
    $usbipd = Get-Command usbipd -ErrorAction SilentlyContinue
    if ($usbipd) {
        Write-Host "✓ usbipd-win ist bereits installiert" -ForegroundColor Green
        usbipd --version
        return $true
    }
    
    Write-Host "usbipd-win nicht gefunden. Installation..." -ForegroundColor Yellow
    
    if ($PSCmdlet.ShouldProcess("usbipd-win", "Install via winget")) {
        try {
            Write-Host "Installing dorssel.usbipd-win..." -ForegroundColor Cyan
            
            & winget install --interactive --exact "dorssel.usbipd-win" `
                --accept-package-agreements `
                --accept-source-agreements `
                --force 2>&1 | Tee-Object -Variable installLog
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ usbipd-win Installation erfolgreich" -ForegroundColor Green
                
                # Neustart des Services
                Get-Service usbipd -ErrorAction SilentlyContinue | 
                    Restart-Service -Force
                
                Write-Host "✓ usbipd Service neu gestartet" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "✗ Installation fehlgeschlagen. Versuche GitHub Download..." -ForegroundColor Yellow
                
                # Fallback: GitHub Release
                $downloadUrl = "https://github.com/dorssel/usbipd-win/releases/latest"
                Write-Host "Bitte manuell herunterladen: $downloadUrl" -ForegroundColor Cyan
                Start-Process $downloadUrl
                return $false
            }
        }
        catch {
            Write-Error "Fehler bei usbipd Installation: $_"
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
    
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ STEP 3: WSL Distribution vorbereiten                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $vendorId = $ScannerConfig.scanner.vendor_id
    $productId = $ScannerConfig.scanner.product_id
    $scannerName = $ScannerConfig.scanner.name
    
    # FIXED: Use proper variable syntax with ${}
    Write-Host "Ziel-Distribution: $Distribution" -ForegroundColor Cyan
    Write-Host "Scanner: $scannerName ($($vendorId):$($productId))" -ForegroundColor Gray
    
    # 3a: Distro-Erkennung (Ubuntu vs Alpine)
    $distroType = if ($Distribution -match "Alpine") { "alpine" } else { "ubuntu" }
    Write-Host "Distro-Typ erkannt: $distroType" -ForegroundColor Cyan
    
    # 3b: SANE Installation (distro-spezifisch)
    Write-Host "`nInstalliere SANE + Epson Driver..." -ForegroundColor Cyan
    
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
echo "✓ SANE für Alpine installiert"
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
echo "✓ SANE für Ubuntu installiert"
"@
        }
        
        # Script in WSL ausführen
        $saneSetupScript | wsl -d $Distribution /bin/bash
    }
    
    # 3c: Kernel Module Setup (SANE benötigt vhci-hcd)
    Write-Host "`nRichte Kernel Module ein..." -ForegroundColor Cyan
    
    if ($PSCmdlet.ShouldProcess("WSL:$Distribution", "Setup kernel modules")) {
        if ($distroType -eq "alpine") {
            # Alpine OpenRC
            $moduleScript = @"
#!/bin/ash
set -e
echo 'vhci_hcd' | sudo tee /etc/modules-load.d/vhci-hcd.conf
echo 'usbip_core' | sudo tee -a /etc/modules-load.d/vhci-hcd.conf
echo 'usbip_host' | sudo tee -a /etc/modules-load.d/vhci-hcd.conf
echo "✓ Kernel Module konfiguriert (Alpine)"
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
echo "✓ Kernel Module konfiguriert (systemd)"
"@
        }
        
        $moduleScript | wsl -d $Distribution /bin/bash
    }
    
    # 3d: udev Rules Setup
    Write-Host "`nRichte udev Rules ein..." -ForegroundColor Cyan
    
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
echo "✓ udev Rules installiert"
"@
        
        $scriptToRun | wsl -d $Distribution /bin/bash
    }
    
    Write-Host "✓ Distribution vorbereitet" -ForegroundColor Green
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
    
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ STEP 4: USB Device Binding                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $vendorId = $ScannerConfig.scanner.vendor_id
    $productId = $ScannerConfig.scanner.product_id
    
    # 4a: Liste USB Devices
    Write-Host "Verfügbare USB-Geräte:" -ForegroundColor Cyan
    $usbList = usbipd list
    Write-Host $usbList -ForegroundColor Gray
    
    # 4b: Scanner Device finden (FIXED: proper variable syntax)
    $hardwareId = "$vendorId`:`$productId"
    Write-Host "`nSuche nach Scanner ($hardwareId)..." -ForegroundColor Cyan
    
    $scannerDevice = $usbList | Select-String "$vendorId`:$productId"
    
    if (-not $scannerDevice) {
        Write-Host "✗ Scanner mit ID $hardwareId nicht gefunden!" -ForegroundColor Red
        Write-Host "  Bitte Scanner anschließen und erneut versuchen." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✓ Scanner gefunden: $scannerDevice" -ForegroundColor Green
    
    # 4c: Bind zum WSL
    if ($PSCmdlet.ShouldProcess("usbipd", "Bind device $hardwareId to $Distribution")) {
        Write-Host "Verbinde Scanner mit WSL..." -ForegroundColor Cyan
        
        try {
            # Erst unbind falls bereits gebunden
            usbipd unbind --hardware-id="$vendorId`:$productId" -f 2>$null
            
            # Bind
            usbipd bind --hardware-id="$vendorId`:$productId"
            
            # Auto-attach für WSL
            usbipd attach --wsl --hardware-id="$vendorId`:$productId" --auto-attach 2>$null || `
            usbipd attach --wsl --hardware-id="$vendorId`:$productId"
            
            Write-Host "✓ Scanner an WSL gebunden" -ForegroundColor Green
            
            # Verify
            Start-Sleep -Seconds 2
            $attachedDevices = usbipd list | Select-String "Attached"
            Write-Host "Gebundene Geräte:" -ForegroundColor Gray
            Write-Host $attachedDevices -ForegroundColor Gray
            
            return $true
        }
        catch {
            Write-Error "Fehler beim Device Binding: $_"
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
    
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ STEP 5: Scanner Test & Validierung                   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "Führe SANE Tests in WSL aus..." -ForegroundColor Cyan
    
    # 5a: lsmod | grep vhci
    Write-Host "`n1. Kernel Module Check:" -ForegroundColor Cyan
    $moduleCheck = wsl -d $Distribution lsmod
    $vhciModules = $moduleCheck | Select-String "vhci"
    
    if ($vhciModules) {
        Write-Host "✓ vhci Kernel Module aktiv:" -ForegroundColor Green
        Write-Host $vhciModules -ForegroundColor Gray
    }
    else {
        Write-Host "⚠ vhci Kernel Module NICHT aktiv!" -ForegroundColor Yellow
        Write-Host "  Trying: sudo modprobe vhci-hcd" -ForegroundColor Gray
        
        if ($PSCmdlet.ShouldProcess("WSL:$Distribution", "Load vhci-hcd module")) {
            wsl -d $Distribution sudo modprobe vhci-hcd
            wsl -d $Distribution sudo modprobe usbip-core
            wsl -d $Distribution sudo modprobe usbip-host
            Write-Host "✓ Module geladen" -ForegroundColor Green
        }
    }
    
    # 5b: sane-find-scanner
    Write-Host "`n2. SANE Scanner Detection:" -ForegroundColor Cyan
    $scannerDetection = wsl -d $Distribution sudo sane-find-scanner -v 2>&1
    Write-Host $scannerDetection -ForegroundColor Gray
    
    if ($scannerDetection -match "found scanner") {
        Write-Host "✓ Scanner von SANE erkannt!" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Scanner von SANE NICHT erkannt" -ForegroundColor Yellow
        Write-Host "  Prüfe USB Binding und udev Rules" -ForegroundColor Gray
    }
    
    # 5c: scanimage -L
    Write-Host "`n3. SANE Devices List:" -ForegroundColor Cyan
    $saneDevices = wsl -d $Distribution scanimage -L 2>&1
    Write-Host $saneDevices -ForegroundColor Gray
    
    # 5d: udev Monitor
    Write-Host "`n4. USB Device Logs (letzte 10 Zeilen):" -ForegroundColor Cyan
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
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ " -ForegroundColor Cyan -NoNewline
    Write-Host $lang.menu_title -ForegroundColor White -NoNewline
    Write-Host " ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "Scanner: $($Config.scanner.name) ($($Config.scanner.vendor_id):$($Config.scanner.product_id))" -ForegroundColor Yellow
    Write-Host "Distribution: $WslDistribution`n" -ForegroundColor Yellow
    
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
        "6" { Write-Host "TODO: Epson-spezifische Konfiguration" -ForegroundColor Yellow }
        "7" { Write-Host "TODO: Log-Viewer" -ForegroundColor Yellow }
        "8" { exit 0 }
        default { Write-Host "Ungültige Eingabe" -ForegroundColor Red }
    }
    
    Read-Host "Drücke Enter zum Fortfahren..."
    Show-InteractiveMenu -Config $Config
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

try {
    # Config laden
    $config = Load-ScannerConfig -ConfigPath $configPath
    if (-not $config) {
        Write-Error "Config konnte nicht geladen werden!"
        exit 1
    }
    
    # Interaktives Menu starten
    Show-InteractiveMenu -Config $config
}
catch {
    Write-Error "Fehler: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}

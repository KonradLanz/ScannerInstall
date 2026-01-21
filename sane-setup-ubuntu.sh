#!/bin/bash
# ScannerInstall - SANE Setup für Ubuntu/Debian v1.0.0
# (C) 2026 GrEEV.com KG. All rights reserved.
# Dual Licensed: MIT + AGPLv3
#
# Installation von SANE + Epson Scanner Driver
# Konfiguration von udev Rules + Kernel Modules
# Validierung durch sane-find-scanner

set -e  # Exit on error

# ============================================================================
# KONFIGURATION - Scanner Parameter (von Windows PowerShell übergeben)
# ============================================================================

SCANNER_NAME="${1:-DS-80W}"
VENDOR_ID="${2:-04b8}"           # Epson Vendor ID
PRODUCT_ID="${3:-0159}"          # DS-80W Product ID
SCANNER_DRIVER="${4:-epsonscan2}"
SANE_CONFIG="${5:-/etc/sane.d/epson.conf}"
UDEV_RULES="${6:-/etc/udev/rules.d/50-udev-epson.rules}"

# Logging
LOG_DIR="/tmp/scanner-install"
LOG_FILE="$LOG_DIR/sane-setup-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
    echo "[INFO] $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo "✓ $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "⚠ $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "✗ $*" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Script muss mit sudo ausgeführt werden!"
        exit 1
    fi
}

# ============================================================================
# STEP 1: System Detect & Distro Check
# ============================================================================

detect_distro() {
    log_info "Erkenne Linux Distribution..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_PRETTY="$PRETTY_NAME"
        log_success "Distro: $DISTRO_PRETTY"
    else
        log_error "Kann /etc/os-release nicht lesen!"
        exit 1
    fi
    
    # Detect Package Manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        log_success "Package Manager: apt (Debian/Ubuntu)"
    elif command -v apk &> /dev/null; then
        PKG_MANAGER="apk"
        log_success "Package Manager: apk (Alpine)"
    else
        log_error "Kein bekannter Package Manager gefunden!"
        exit 1
    fi
}

# ============================================================================
# STEP 2: Repository Updates
# ============================================================================

update_repositories() {
    log_info "Aktualisiere Paket-Repositories..."
    
    case "$PKG_MANAGER" in
        apt)
            apt-get update -qq || log_warning "apt-get update returned non-zero"
            ;;
        apk)
            apk update -q || log_warning "apk update returned non-zero"
            ;;
    esac
    
    log_success "Repositories aktualisiert"
}

# ============================================================================
# STEP 3: Install SANE + Dependencies
# ============================================================================

install_sane() {
    log_info "Installiere SANE Framework + Epson Driver..."
    
    case "$PKG_MANAGER" in
        apt)
            # Ubuntu/Debian
            PACKAGES=(
                "sane"                      # SANE Framework
                "sane-utils"                # SANE Tools
                "libsane1"                  # SANE Library
                "libsane-epson"             # Epson Backend
                "usbutils"                  # USB Tools
                "usbip"                     # USB/IP Tools
            )
            
            log_info "Installiere Pakete: ${PACKAGES[*]}"
            apt-get install -y "${PACKAGES[@]}" 2>&1 | tee -a "$LOG_FILE"
            
            if [ $? -eq 0 ]; then
                log_success "SANE und Epson Driver installiert (apt)"
            else
                log_error "Installation über apt fehlgeschlagen"
                return 1
            fi
            ;;
            
        apk)
            # Alpine Linux
            PACKAGES=(
                "sane"
                "sane-backends-libsane"
                "sane-backends-epson"
                "usbutils"
                "usbip-tools"
            )
            
            log_info "Installiere Pakete: ${PACKAGES[*]}"
            apk add "${PACKAGES[@]}" 2>&1 | tee -a "$LOG_FILE"
            
            if [ $? -eq 0 ]; then
                log_success "SANE und Epson Driver installiert (apk)"
            else
                log_error "Installation über apk fehlgeschlagen"
                return 1
            fi
            ;;
    esac
}

# ============================================================================
# STEP 4: Configure SANE - Epson Backend
# ============================================================================

configure_sane_epson() {
    log_info "Konfiguriere Epson SANE Backend..."
    
    # Backup existing config
    if [ -f "$SANE_CONFIG" ]; then
        cp "$SANE_CONFIG" "${SANE_CONFIG}.backup-$(date +%s)"
        log_info "Backup der Original-Config erstellt"
    fi
    
    # Append Epson Device Configuration
    cat >> "$SANE_CONFIG" << EOF

# ============================================================================
# Epson $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)
# Auto-configured by ScannerInstall v1.0.0
# ============================================================================

[epson]
# Epson Devices
; usb = VENDOR_ID PRODUCT_ID

# Enable generic libusb scanner
usb = $VENDOR_ID $PRODUCT_ID

# Debug level: 0=none, 1=error, 2=warning, 3=info, 4=debug, 5=trace
debug = 2

EOF
    
    log_success "Epson Backend in $SANE_CONFIG konfiguriert"
}

# ============================================================================
# STEP 5: Kernel Module Setup (vhci-hcd für USB)
# ============================================================================

setup_kernel_modules() {
    log_info "Richte Kernel Module für USB/IP ein..."
    
    # Module, die benötigt werden
    MODULES=("vhci_hcd" "usbip_core" "usbip_host")
    
    # 5a: Sofort laden
    for module in "${MODULES[@]}"; do
        log_info "Lade Kernel Module: $module"
        if modprobe "$module" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "✓ Module $module geladen"
        else
            log_warning "⚠ Module $module konnte nicht geladen werden"
        fi
    done
    
    # 5b: Persistent laden beim Boot (distro-spezifisch)
    case "$PKG_MANAGER" in
        apt)
            # Ubuntu/Debian (systemd)
            log_info "Konfiguriere systemd-modules-load für persistentes Laden..."
            
            cat > /etc/modules-load.d/vhci-hcd.conf << EOF
# USB/IP vhci kernel modules (auto-configured by ScannerInstall)
vhci-hcd
usbip-core
usbip-host
EOF
            
            log_success "Module-Config in /etc/modules-load.d/vhci-hcd.conf geschrieben"
            
            # Enable systemd service
            systemctl enable systemd-modules-load 2>/dev/null || true
            log_success "systemd-modules-load enabled"
            ;;
            
        apk)
            # Alpine Linux (OpenRC - keine systemd)
            log_info "Konfiguriere Alpine OpenRC für persistentes Laden..."
            
            cat > /etc/modules-load.d/vhci-hcd.conf << EOF
# USB/IP vhci kernel modules (auto-configured by ScannerInstall)
vhci_hcd
usbip_core
usbip_host
EOF
            
            # Alpine: Modules in /etc/modules laden beim Boot
            cat >> /etc/modules << EOF
vhci_hcd
usbip_core
usbip_host
EOF
            
            log_success "Module in /etc/modules hinzugefügt (Alpine)"
            ;;
    esac
    
    # Verification
    log_info "Verifiziere geladene Module..."
    lsmod | grep -E "vhci|usbip" || log_warning "Nicht alle Module aktiv"
}

# ============================================================================
# STEP 6: udev Rules - Scanner USB Zugriff
# ============================================================================

setup_udev_rules() {
    log_info "Richte udev Rules für $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID) ein..."
    
    # Backup existing
    if [ -f "$UDEV_RULES" ]; then
        cp "$UDEV_RULES" "${UDEV_RULES}.backup-$(date +%s)"
    fi
    
    # Create udev rules
    cat > "$UDEV_RULES" << EOF
# ============================================================================
# udev rules for $SCANNER_NAME (USB $VENDOR_ID:$PRODUCT_ID)
# Auto-configured by ScannerInstall v1.0.0
# ============================================================================

# Epson Scanner USB Device
SUBSYSTEMS=="usb", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", MODE="0666", GROUP="lpadmin"
SUBSYSTEMS=="usb_device", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", MODE="0666", GROUP="lpadmin"

# SANE Libusb Access
SUBSYSTEM=="usb", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", RUN+="/usr/bin/test -f /usr/bin/sane-find-scanner"

EOF
    
    chmod 644 "$UDEV_RULES"
    log_success "udev Rules geschrieben: $UDEV_RULES"
    
    # Reload udev
    log_info "Lade udev Rules neu..."
    udevadm control --reload-rules 2>&1 | tee -a "$LOG_FILE"
    udevadm trigger --subsystem-match=usb 2>&1 | tee -a "$LOG_FILE"
    
    log_success "udev Rules reloaded"
}

# ============================================================================
# STEP 7: SANE Group Membership
# ============================================================================

setup_sane_group() {
    log_info "Richte SANE Gruppen-Zugriff ein..."
    
    # Create scanimage group if not exists
    if ! getent group lpadmin > /dev/null; then
        log_warning "lpadmin Gruppe existiert nicht, verwende scanner stattdessen"
        SANE_GROUP="scanner"
        groupadd "$SANE_GROUP" 2>/dev/null || true
    else
        SANE_GROUP="lpadmin"
    fi
    
    log_success "SANE Gruppe: $SANE_GROUP"
    
    # Add current user to group (wenn nicht root)
    if [ -n "$SUDO_USER" ]; then
        usermod -aG "$SANE_GROUP" "$SUDO_USER"
        log_success "User $SUDO_USER zur Gruppe $SANE_GROUP hinzugefügt"
    fi
}

# ============================================================================
# STEP 8: Validation & Testing
# ============================================================================

validate_installation() {
    log_info "Validiere SANE Installation..."
    
    echo ""
    log_info "=== 1. SANE Installation Check ==="
    which sane-find-scanner && log_success "sane-find-scanner installed" || log_error "sane-find-scanner NOT found"
    which scanimage && log_success "scanimage installed" || log_error "scanimage NOT found"
    
    echo ""
    log_info "=== 2. Kernel Module Status ==="
    lsmod | grep -E "vhci|usbip" && log_success "Kernel modules loaded" || log_warning "Kernel modules NOT loaded"
    
    echo ""
    log_info "=== 3. udev Rules Check ==="
    [ -f "$UDEV_RULES" ] && log_success "udev Rules file exists" || log_error "udev Rules file NOT found"
    
    echo ""
    log_info "=== 4. SANE Config Check ==="
    [ -f "$SANE_CONFIG" ] && log_success "SANE Config file exists" || log_error "SANE Config file NOT found"
    
    echo ""
    log_info "=== 5. USB Devices (if connected) ==="
    lsusb | grep -i "$VENDOR_ID" && log_success "Scanner USB device found" || log_warning "Scanner USB device NOT found (may not be connected)"
    
    echo ""
    log_info "Installation validation complete. Check logs at: $LOG_FILE"
}

# ============================================================================
# STEP 9: Post-Installation Instructions
# ============================================================================

print_instructions() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║ ScannerInstall - SANE Setup Complete                          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Nächste Schritte:"
    echo ""
    echo "1. Scanner verbinden und WSL-neu booten:"
    echo "   wsl --terminate <Distro>"
    echo "   wsl -d <Distro>"
    echo ""
    echo "2. Scanner erkennen:"
    echo "   sane-find-scanner -v"
    echo "   scanimage -L"
    echo ""
    echo "3. Scanner Test:"
    echo "   scanimage -d epson --mode Color --resolution 100 -x 100 -y 100 --format=pnm > test.pnm"
    echo ""
    echo "4. Bei Problemen:"
    echo "   sudo udevadm monitor --udev --subsystem-match=usb --property"
    echo "   grep -i epson /etc/sane.d/*.conf"
    echo ""
    echo "Log-Datei: $LOG_FILE"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║ ScannerInstall - SANE Setup for Linux                         ║"
    echo "║ Scanner: $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    detect_distro
    update_repositories
    install_sane
    configure_sane_epson
    setup_kernel_modules
    setup_udev_rules
    setup_sane_group
    validate_installation
    print_instructions
    
    log_success "=== SANE Installation abgeschlossen ==="
}

# Execute
main "$@"

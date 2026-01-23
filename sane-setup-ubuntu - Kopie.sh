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
# Hinweis:
# - Wenn explizite Werte übergeben werden, gelten diese zunächst.
# - Danach wird optional per lsusb-Hardwareerkennung geprüft, ob ein besser
#   passender Eintrag gefunden wird → mit Rückfrage vor Override.

SCANNER_NAME="${1:-DS-80W}"
VENDOR_ID="${2:-04b8}"           # Epson Vendor ID
PRODUCT_ID="${3:-0159}"          # DS-80W Product ID (eine Variante)
SCANNER_DRIVER="${4:-epsonscan2}"
SANE_CONFIG="${5:-/etc/sane.d/epson.conf}"
UDEV_RULES="${6:-/etc/udev/rules.d/50-udev-epson.rules}"

# Logging
LOG_DIR="/tmp/scanner-install"
LOG_FILE="$LOG_DIR/sane-setup-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# ============================================================================
# HARDWARE-DATENBANK (mehrere IDs / Modelle)
# ============================================================================
# Format: "Name|VendorID|ProductID"
# Hier kannst du weitere Modelle ergänzen.

KNOWN_SCANNERS=(
    "Epson DS-80W (0166)|04b8|0166"
    "Epson DS-80W (0159)|04b8|0159"
    "Epson DS-80W (0120 Alt)|04b8|0120"
    # Beispiele/Platzhalter – bei Bedarf ausbauen:
    "Brother DCP-9022CDW|04f9|0266"
    "HP OfficeJet J5700|03f0|4102"
)

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

prompt_yn() {
    # prompt_yn "Frage" [default_y|n]
    local prompt="$1"
    local default="${2:-y}"
    local answer

    while true; do
        local hint="[y/n]"
        [[ "$default" == "y" ]] && hint="[Y/n]" || hint="[y/N]"
        read -r -p "$prompt $hint " answer
        answer="${answer:-$default}"
        case "$answer" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            *) echo "Bitte 'y' oder 'n' eingeben." ;;
        esac
    done
}

# ============================================================================
# STEP 0: Auto-Detection via lsusb (mehrere Hardware-IDs)
# ============================================================================

auto_detect_scanner() {
    log_info "Suche bekannte Scanner via lsusb..."

    if ! command -v lsusb >/dev/null 2>&1; then
        log_warning "lsusb nicht gefunden – installiere usbutils..."
        if prompt_yn "usbutils (lsusb) via Paketmanager installieren?" "y"; then
            if command -v apt-get >/dev/null 2>&1; then
                apt-get update -qq || true
                apt-get install -y usbutils 2>&1 | tee -a "$LOG_FILE" || log_warning "usbutils-Installation fehlgeschlagen"
            fi
        else
            log_warning "lsusb nicht verfügbar, Überspringe Auto-Detection."
            return
        fi
    fi

    local lsusb_out
    lsusb_out="$(lsusb 2>/dev/null || true)"

    if [[ -z "$lsusb_out" ]]; then
        log_warning "lsusb liefert keine Ausgaben – kein USB-Scanner erkannt?"
        return
    fi

    local matches=()
    local idx=0

    for entry in "${KNOWN_SCANNERS[@]}"; do
        IFS="|" read -r name vid pid <<<"$entry"
        if echo "$lsusb_out" | grep -iq "ID ${vid}:${pid}"; then
            matches+=("$entry")
            log_success "Gefundener Scanner: $name (${vid}:${pid})"
        fi
    done

    if [[ ${#matches[@]} -eq 0 ]]; then
        log_warning "Kein bekannter Scanner aus der Datenbank via lsusb gefunden."
        return
    fi

    echo ""
    log_info "Gefundene bekannte Scanner (per lsusb):"
    idx=1
    for entry in "${matches[@]}"; do
        IFS="|" read -r name vid pid <<<"$entry"
        echo "  [$idx] $name (${vid}:${pid})"
        ((idx++))
    done
    echo ""

    if [[ ${#matches[@]} -eq 1 ]]; then
        # Nur ein Gerät – Rückfrage ob verwenden
        IFS="|" read -r name vid pid <<<"${matches[0]}"
        if prompt_yn "Gefundenen Scanner '$name' (${vid}:${pid}) verwenden und aktuelle Parameter überschreiben?" "y"; then
            SCANNER_NAME="$name"
            VENDOR_ID="$vid"
            PRODUCT_ID="$pid"
            log_success "Scanner-Parameter gesetzt auf: $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)"
        else
            log_info "Behalte manuell gesetzte Parameter: $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)"
        fi
    else
        # Mehrere Geräte – Menü
        while true; do
            read -r -p "Bitte gewünschten Scanner wählen [1-${#matches[@]}] oder '0' für Abbrechen: " choice
            if [[ "$choice" == "0" ]]; then
                log_info "Auto-Detection abgebrochen. Behalte: $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)"
                break
            fi
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#matches[@]} )); then
                local sel="${matches[choice-1]}"
                IFS="|" read -r name vid pid <<<"$sel"
                if prompt_yn "Scanner '$name' (${vid}:${pid}) verwenden und aktuelle Parameter überschreiben?" "y"; then
                    SCANNER_NAME="$name"
                    VENDOR_ID="$vid"
                    PRODUCT_ID="$pid"
                    log_success "Scanner-Parameter gesetzt auf: $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)"
                else
                    log_info "Behalte manuell gesetzte Parameter: $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)"
                fi
                break
            else
                echo "Ungültige Auswahl."
            fi
        done
    fi
}

# ============================================================================
# STEP 1: System Detect & Distro Check
# ============================================================================

detect_distro() {
    log_info "Erkenne Linux Distribution..."

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
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

    if ! prompt_yn "Paketlisten aktualisieren (update)?" "y"; then
        log_warning "Überspringe Repository-Updates auf Wunsch des Anwenders."
        return
    fi

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

            log_info "Folgende Pakete würden installiert werden: ${PACKAGES[*]}"
            if ! prompt_yn "Pakete jetzt installieren (apt-get install)?" "y"; then
                log_warning "Pakete werden NICHT installiert (apt)."
                return
            fi

            apt-get install -y "${PACKAGES[@]}" 2>&1 | tee -a "$LOG_FILE"

            log_success "SANE und Epson Driver Installationslauf (apt) abgeschlossen"
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

            log_info "Folgende Pakete würden installiert werden: ${PACKAGES[*]}"
            if ! prompt_yn "Pakete jetzt installieren (apk add)?" "y"; then
                log_warning "Pakete werden NICHT installiert (apk)."
                return
            fi

            apk add "${PACKAGES[@]}" 2>&1 | tee -a "$LOG_FILE"

            log_success "SANE und Epson Driver Installationslauf (apk) abgeschlossen"
            ;;
    esac
}

# ============================================================================
# STEP 4: Configure SANE - Epson Backend
# ============================================================================

configure_sane_epson() {
    log_info "Konfiguriere Epson SANE Backend..."
    log_info "Ziel-Config: $SANE_CONFIG"

    if ! prompt_yn "SANE-Config für Epson in $SANE_CONFIG anpassen/ergänzen?" "y"; then
        log_warning "SANE-Config-Anpassung übersprungen."
        return
    fi

    # Backup existing config
    if [ -f "$SANE_CONFIG" ]; then
        local backup="${SANE_CONFIG}.backup-$(date +%s)"
        cp "$SANE_CONFIG" "$backup"
        log_info "Backup der Original-Config erstellt: $backup"
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

    if ! prompt_yn "Kernel-Module für USB/IP (vhci_hcd, usbip_*) laden & persistent konfigurieren?" "y"; then
        log_warning "Kernel-Module-Setup übersprungen."
        return
    fi

    # Module, die benötigt werden
    MODULES=("vhci_hcd" "usbip_core" "usbip_host")

    # 5a: Sofort laden
    for module in "${MODULES[@]}"; do
        log_info "Lade Kernel Module: $module"
        if modprobe "$module" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Module $module geladen"
        else
            log_warning "Module $module konnte nicht geladen werden"
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
    log_info "Ziel-Datei: $UDEV_RULES"

    if ! prompt_yn "udev-Regeln für diesen Scanner schreiben/überschreiben?" "y"; then
        log_warning "udev-Regel-Erstellung übersprungen."
        return
    fi

    # Backup existing
    if [ -f "$UDEV_RULES" ]; then
        local backup="${UDEV_RULES}.backup-$(date +%s)"
        cp "$UDEV_RULES" "$backup"
        log_info "Backup bestehender udev-Regeln: $backup"
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

    if prompt_yn "udev-Regeln jetzt neu laden und triggern?" "y"; then
        log_info "Lade udev Rules neu..."
        udevadm control --reload-rules 2>&1 | tee -a "$LOG_FILE"
        udevadm trigger --subsystem-match=usb 2>&1 | tee -a "$LOG_FILE"
        log_success "udev Rules reloaded"
    else
        log_warning "Neuladen der udev-Regeln übersprungen – ggf. manueller Neustart nötig."
    fi
}

# ============================================================================
# STEP 7: SANE Group Membership
# ============================================================================

setup_sane_group() {
    log_info "Richte SANE Gruppen-Zugriff ein..."

    if ! prompt_yn "Benutzergruppen für Scannerzugriff (lpadmin/scanner) anpassen?" "y"; then
        log_warning "Gruppen-/Permissions-Setup übersprungen."
        return
    fi

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
        log_warning "Ab- und erneutes Anmelden nötig, damit Gruppenrechte greifen."
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
    lsusb | grep -i "$VENDOR_ID:$PRODUCT_ID" && log_success "Scanner USB device found ($VENDOR_ID:$PRODUCT_ID)" || log_warning "Scanner USB device NOT found (may not be connected)"

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

    # Hardware-Auto-Detection (mehrere IDs) vor Distro-Check
    auto_detect_scanner

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

main "$@"

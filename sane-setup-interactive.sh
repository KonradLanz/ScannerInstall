#!/bin/bash
################################################################################
# ScannerInstall - Interactive SANE Setup Script v2.0
# Purpose: Auto-detect and configure multiple scanner types with user prompts
# Author: KonradLanz (GrEEV.com KG)
# License: AGPL-3.0 / MIT (Dual Licensed)
# Created: 2026-01-23
################################################################################

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION: Scanner Hardware IDs Database
# ──────────────────────────────────────────────────────────────────────────────

declare -A SCANNER_DB=(
    # Epson Scanners
    ["epson_ds80w"]="04b8:0120|04b8:0121|04b8:0122"  # DS-80W / ES-50 variants
    ["epson_ds70"]="04b8:0110|04b8:0111"               # DS-70
    ["epson_rx10"]="04b8:0901"                          # RX-10 / RX-20
    ["epson_ff120"]="04b8:010a"                         # FF-120
    
    # Brother Scanners
    ["brother_dcp9022cdw"]="04f9:0266|04f9:0267"      # DCP-9022CDW
    ["brother_mfc7360"]="04f9:00a7"                    # MFC-7360N
    ["brother_mfc9340"]="04f9:020e"                    # MFC-9340CDW
    ["brother_dcp7055"]="04f9:00a0|04f9:00a1"         # DCP-7055 series
    
    # HP Scanners (HPAIO)
    ["hp_officejet_j5700"]="03f0:4102|03f0:4103"      # OfficeJet J5700
    ["hp_scanjet_pro"]="03f0:0c17|03f0:0c18"          # ScanJet Pro
    ["hp_laserjet_m428"]="03f0:0753"                   # LaserJet M428 MFP
    
    # Fujitsu Scanners (iX)
    ["fujitsu_ix100"]="04c5:1249"                      # ScanSnap iX100
    ["fujitsu_ix500"]="04c5:1204"                      # ScanSnap iX500
    
    # Canon Scanners
    ["canon_dr_f120"]="1a86:7302|1a86:7303"           # imageFORMULA DR-F120
    ["canon_lide_220"]="04a9:1912"                     # CanoScan LiDE220
)

declare -A SCANNER_BACKEND=(
    ["epson_ds80w"]="epsonds,epsonscan2"
    ["epson_ds70"]="epsonds,epsonscan2"
    ["epson_rx10"]="epson"
    ["epson_ff120"]="epson"
    ["brother_dcp9022cdw"]="brother4,brother5"
    ["brother_mfc7360"]="brother4"
    ["brother_mfc9340"]="brother4"
    ["brother_dcp7055"]="brother4"
    ["hp_officejet_j5700"]="hpaio"
    ["hp_scanjet_pro"]="hpaio"
    ["hp_laserjet_m428"]="hpaio"
    ["fujitsu_ix100"]="fujitsu"
    ["fujitsu_ix500"]="fujitsu"
    ["canon_dr_f120"]="canon"
    ["canon_lide_220"]="pixma"
)

# ──────────────────────────────────────────────────────────────────────────────
# GLOBAL VARIABLES
# ──────────────────────────────────────────────────────────────────────────────

SANE_CONF="/etc/sane.d"
SANE_DLL_CONF="${SANE_CONF}/dll.conf"
SANE_DLL_D="${SANE_CONF}/dll.d"
UDEV_RULES_DIR="/etc/udev/rules.d"
BACKUP_DIR="/var/backups/sane-setup-$(date +%Y%m%d_%H%M%S)"
DETECTED_SCANNERS=()
CHANGES_MADE=()
DRY_RUN=false
INTERACTIVE=true

# ──────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

log_info() { echo -e "ℹ️  \033[36m$*\033[0m"; }
log_success() { echo -e "✅ \033[32m$*\033[0m"; }
log_warn() { echo -e "⚠️  \033[33m$*\033[0m"; }
log_error() { echo -e "❌ \033[31m$*\033[0m"; }
log_debug() { [[ "$DEBUG" == "1" ]] && echo -e "🔧 \033[35m[DEBUG] $*\033[0m"; }

# Prompt user for yes/no
prompt_yn() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$INTERACTIVE" != "true" ]]; then
        log_debug "Non-interactive mode: defaulting to '$default'"
        return $([[ "$default" == "y" ]] && echo 0 || echo 1)
    fi
    
    while true; do
        echo -ne "\033[36m? $prompt \033[33m[y/n]\033[0m (default: $default): "
        read -r response
        response="${response:-$default}"
        
        case "$response" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "  Please answer 'y' or 'n'" ;;
        esac
    done
}

# Backup config files before modification
backup_config() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    cp -p "$file" "$BACKUP_DIR/$(basename "$file")"
    log_info "Backed up: $file → $BACKUP_DIR"
}

# Restore from backup
restore_backup() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "No backups found (expected: $BACKUP_DIR)"
        return 1
    fi
    
    for backup_file in "$BACKUP_DIR"/*; do
        original="${backup_file#*_backup_*}"
        original="$SANE_CONF/${original##*/}"
        
        if [[ -f "$backup_file" ]]; then
            cp -p "$backup_file" "$original"
            log_success "Restored: $original"
        fi
    done
    
    log_success "All configs restored from $BACKUP_DIR"
}

# ──────────────────────────────────────────────────────────────────────────────
# HARDWARE DETECTION
# ──────────────────────────────────────────────────────────────────────────────

detect_usb_scanners() {
    log_info "Scanning for USB scanners..."
    
    if ! command -v lsusb &>/dev/null; then
        log_warn "lsusb not found - installing usbutils"
        sudo apt-get update -qq && sudo apt-get install -y usbutils &>/dev/null
    fi
    
    local output
    output=$(sudo lsusb 2>/dev/null || lsusb 2>/dev/null) || {
        log_error "Could not enumerate USB devices"
        return 1
    }
    
    local vendor_product
    while read -r line; do
        # Extract vendor:product ID from lsusb output
        # Format: Bus 001 Device 003: ID 04b8:0120 Seiko Epson Corp. ...
        if [[ $line =~ ID\ ([0-9a-f]{4}):([0-9a-f]{4}) ]]; then
            vendor_product="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
            
            # Search in database
            for scanner_key in "${!SCANNER_DB[@]}"; do
                if [[ "${SCANNER_DB[$scanner_key]}" == *"$vendor_product"* ]]; then
                    DETECTED_SCANNERS+=("$scanner_key|$vendor_product")
                    log_success "Detected: $scanner_key ($vendor_product)"
                    break
                fi
            done
        fi
    done <<< "$output"
    
    if [[ ${#DETECTED_SCANNERS[@]} -eq 0 ]]; then
        log_warn "No known scanners detected"
        log_info "Run 'lsusb' manually to see connected USB devices"
        return 1
    fi
    
    return 0
}

detect_sane_scanners() {
    log_info "Checking SANE detection..."
    
    if ! command -v scanimage &>/dev/null; then
        log_warn "sane-utils not yet installed, skipping SANE detection"
        return 0
    fi
    
    log_info "SANE-detected devices (non-privileged):"
    scanimage -L 2>/dev/null || true
    
    log_info "SANE-detected devices (with sudo):"
    sudo scanimage -L 2>/dev/null || true
}

# ──────────────────────────────────────────────────────────────────────────────
# BACKEND CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

enable_backend() {
    local backend="$1"
    local backend_file="$SANE_CONF/${backend}.conf"
    
    # Check if already enabled in dll.conf
    if grep -q "^${backend}$" "$SANE_DLL_CONF" 2>/dev/null; then
        log_debug "Backend '$backend' already enabled in dll.conf"
        return 0
    fi
    
    # Check if commented out
    if grep -q "^#${backend}$\|^#\s*${backend}$" "$SANE_DLL_CONF" 2>/dev/null; then
        log_info "Backend '$backend' found (commented)"
        if prompt_yn "Uncomment backend '$backend' in dll.conf?"; then
            backup_config "$SANE_DLL_CONF"
            sed -i "/^#\s*${backend}$/s/^#\s*//" "$SANE_DLL_CONF"
            CHANGES_MADE+=("Enabled backend: $backend")
            log_success "Enabled backend: $backend"
            return 0
        fi
        return 1
    fi
    
    # Not found - add new entry
    log_info "Backend '$backend' not found in dll.conf"
    if prompt_yn "Add backend '$backend' to dll.conf?"; then
        backup_config "$SANE_DLL_CONF"
        echo "$backend" >> "$SANE_DLL_CONF"
        CHANGES_MADE+=("Added backend: $backend")
        log_success "Added backend: $backend"
        return 0
    fi
    
    return 1
}

configure_backend() {
    local scanner_key="$1"
    local vendor_product="$2"
    local backends="${SCANNER_BACKEND[$scanner_key]}"
    
    log_info "Configuring backends for: $scanner_key ($vendor_product)"
    
    IFS=',' read -ra backend_array <<< "$backends"
    for backend in "${backend_array[@]}"; do
        enable_backend "$backend"
    done
}

add_udev_rule() {
    local vendor="$1"
    local product="$2"
    local scanner_name="$3"
    local rule_file="${UDEV_RULES_DIR}/65-scanner-${scanner_name}.rules"
    
    log_info "Setting up udev rule for $scanner_name"
    
    local rule="SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"${vendor}\", ATTRS{idProduct}==\"${product}\", MODE=\"0664\", GROUP=\"lp\""
    
    if [[ -f "$rule_file" ]]; then
        if grep -q "ATTRS{idVendor}==\"${vendor}\"" "$rule_file"; then
            log_debug "udev rule already exists for $scanner_name"
            return 0
        fi
    fi
    
    if prompt_yn "Create udev rule for $scanner_name (vendor:product ${vendor}:${product})?"; then
        backup_config "$rule_file" 2>/dev/null || true
        echo "$rule" | sudo tee "$rule_file" > /dev/null
        CHANGES_MADE+=("Created udev rule: $rule_file")
        log_success "Created udev rule: $rule_file"
        
        if prompt_yn "Reload udev rules now?"; then
            sudo udevadm control --reload-rules
            sudo udevadm trigger
            log_success "udev rules reloaded"
        fi
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PERMISSION SETUP
# ──────────────────────────────────────────────────────────────────────────────

setup_scanner_group() {
    local user="${1:-$SUDO_USER}"
    
    if [[ -z "$user" ]]; then
        log_warn "Could not determine user for group assignment"
        return 1
    fi
    
    log_info "Ensuring scanner group exists..."
    sudo groupadd -f scanner
    
    log_info "Adding user '$user' to scanner and lp groups..."
    if prompt_yn "Add '$user' to scanner and lp groups?"; then
        sudo usermod -a -G scanner,lp "$user"
        CHANGES_MADE+=("User '$user' added to scanner,lp groups")
        log_success "User '$user' added to groups"
        log_warn "User must log out and back in for group changes to take effect"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# PACKAGE INSTALLATION
# ──────────────────────────────────────────────────────────────────────────────

install_sane_packages() {
    local packages=(
        "sane"
        "sane-utils"
        "libsane1"
    )
    
    # Additional vendor packages
    if [[ " ${DETECTED_SCANNERS[*]} " == *"epson"* ]]; then
        packages+=("epsonscan2")
    fi
    if [[ " ${DETECTED_SCANNERS[*]} " == *"brother"* ]]; then
        packages+=("brother-scanner-driver-bin")
    fi
    if [[ " ${DETECTED_SCANNERS[*]} " == *"hp"* ]]; then
        packages+=("hplip" "libhplip0")
    fi
    
    log_info "Required packages:"
    printf '  - %s\n' "${packages[@]}"
    
    if prompt_yn "Install packages?"; then
        log_info "Updating package list..."
        sudo apt-get update -qq || true
        
        log_info "Installing SANE packages..."
        # shellcheck disable=SC2086
        sudo apt-get install -y ${packages[@]} 2>&1 | grep -E "Setting up|already|Done|Processing" || true
        
        CHANGES_MADE+=("Installed packages: ${packages[*]}")
        log_success "Packages installed"
        return 0
    fi
    
    return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# TESTING
# ──────────────────────────────────────────────────────────────────────────────

test_sane() {
    log_info "Running SANE tests..."
    
    echo
    log_info "Testing as regular user:"
    if scanimage -L 2>/dev/null; then
        log_success "scanimage -L (user) succeeded"
    else
        log_warn "scanimage -L (user) failed - may need permissions"
    fi
    
    echo
    log_info "Testing with sudo:"
    if sudo scanimage -L 2>/dev/null; then
        log_success "scanimage -L (sudo) succeeded"
    else
        log_error "scanimage -L (sudo) failed"
    fi
    
    echo
    if prompt_yn "Run scanimage --test to verify scanner?"; then
        if scanimage --test 2>&1; then
            log_success "Test scan succeeded"
        else
            log_warn "Test scan failed - check device configuration"
        fi
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY & ROLLBACK
# ──────────────────────────────────────────────────────────────────────────────

show_summary() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           SANE Setup - Configuration Summary               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    
    if [[ ${#CHANGES_MADE[@]} -eq 0 ]]; then
        log_info "No changes were made"
        return 0
    fi
    
    echo
    log_success "Changes made:"
    printf '  %s\n' "${CHANGES_MADE[@]}"
    
    echo
    log_info "Backup location: $BACKUP_DIR"
    echo
    
    if prompt_yn "Restore from backup (revert changes)?"; then
        restore_backup
        exit 0
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN WORKFLOW
# ──────────────────────────────────────────────────────────────────────────────

main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ScannerInstall - Interactive SANE Setup v2.0               ║"
    echo "║  GrEEV.com KG | AGPL-3.0 / MIT (Dual Licensed)             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    
    # Check root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo"
        exit 1
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=true ;;
            --non-interactive) INTERACTIVE=false ;;
            --debug) DEBUG=1 ;;
            --help)
                cat << 'EOF'
Usage: sudo ./sane-setup-interactive.sh [OPTIONS]

Options:
  --dry-run              Show what would be done without making changes
  --non-interactive      Skip all prompts (use defaults)
  --debug                Enable debug output
  --help                 Show this help message

Examples:
  sudo ./sane-setup-interactive.sh                    # Interactive setup
  sudo ./sane-setup-interactive.sh --dry-run          # Preview changes
  sudo ./sane-setup-interactive.sh --non-interactive  # Automated setup
EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY-RUN mode (no changes will be made)"
        INTERACTIVE=false
    fi
    
    # === WORKFLOW ===
    
    # 1. Detect hardware
    echo
    log_info "Phase 1: Hardware Detection"
    echo "─────────────────────────────────"
    detect_usb_scanners || log_warn "Manual setup may be required"
    
    # 2. Detect SANE status
    echo
    log_info "Phase 2: SANE Status Check"
    echo "─────────────────────────────────"
    detect_sane_scanners
    
    # 3. Install packages
    echo
    log_info "Phase 3: Package Installation"
    echo "─────────────────────────────────"
    if [[ "$DRY_RUN" != "true" ]]; then
        install_sane_packages
    else
        log_info "[DRY-RUN] Would install sane packages"
    fi
    
    # 4. Configure backends
    echo
    log_info "Phase 4: Backend Configuration"
    echo "─────────────────────────────────"
    if [[ ${#DETECTED_SCANNERS[@]} -gt 0 ]]; then
        for scanner_entry in "${DETECTED_SCANNERS[@]}"; do
            IFS='|' read -r scanner_key vendor_product <<< "$scanner_entry"
            IFS=':' read -r vendor product <<< "$vendor_product"
            
            if [[ "$DRY_RUN" != "true" ]]; then
                configure_backend "$scanner_key" "$vendor_product"
                add_udev_rule "$vendor" "$product" "$scanner_key"
            else
                log_info "[DRY-RUN] Would configure: $scanner_key ($vendor_product)"
            fi
        done
    fi
    
    # 5. Setup permissions
    echo
    log_info "Phase 5: Permission Setup"
    echo "─────────────────────────────────"
    if [[ "$DRY_RUN" != "true" ]]; then
        setup_scanner_group "$SUDO_USER"
    else
        log_info "[DRY-RUN] Would setup scanner group permissions"
    fi
    
    # 6. Test
    echo
    log_info "Phase 6: Testing"
    echo "─────────────────────────────────"
    if [[ "$DRY_RUN" != "true" ]]; then
        test_sane
    else
        log_info "[DRY-RUN] Would run SANE tests"
    fi
    
    # Summary
    echo
    show_summary
}

# ──────────────────────────────────────────────────────────────────────────────

main "$@"

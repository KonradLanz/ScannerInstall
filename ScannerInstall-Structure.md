# ScannerInstall - Projektstruktur v1.0.0

Basiert auf: **ExecutionPolicy-Foundation Template Repository**

## Repository Struktur

```
ScannerInstall/
├── README.md                                 # Hauptdokumentation
├── LICENSE                                   # MIT + AGPLv3 Dual-License
├── .gitignore                               # Temp files, logs
├── .gitattributes                           # CRLF handling
│
├── Start.bat                                # Batch Wrapper (ExecutionPolicy Bypass)
├── Start.ps1                                # PowerShell Bootstrap
├── StartWithGithub.ps1                      # GitHub Repo Init (base from ExecutionPolicy-Foundation)
│
├── src/
│   ├── Scanner.Install.Module.ps1           # Hauptmodul - PowerShell Host
│   ├── Scanner.Config.ps1                   # Scanner Konfiguration (Parameter)
│   └── unblock-files.ps1                    # Unblock mit Audit
│
├── scripts/
│   ├── 1-check-wsl2.ps1                     # WSL2 Detection & Install
│   ├── 2-install-usbipd.ps1                 # usbipd-win via winget
│   ├── 3-prepare-wsl-distro.ps1             # Distro Detection & SSH Setup
│   ├── 4-attach-usb-device.ps1              # USB Device Binding
│   └── 5-test-scanner.ps1                   # Validation Script
│
├── linux/
│   ├── sane-setup.sh                        # SANE + Epson Driver (Ubuntu/Debian)
│   ├── sane-setup-alpine.sh                 # SANE für Alpine
│   ├── scanner-kernel-module.sh             # vhci-hcd modprobe + systemd service
│   ├── udev-rules-epson.sh                  # udev rules Management
│   └── docker-sane-setup.sh                 # Optional: Docker Container Setup
│
├── config/
│   ├── Scanner.config.json                  # Scanner Modell-Definition
│   ├── epson.conf.template                  # SANE Epson Config Template
│   ├── 50-epson.rules.template              # udev rules Template
│   └── vhci-hcd-module.conf                 # modprobe configuration
│
├── tests/
│   ├── test-wsl2-detection.ps1              # WSL2 Existenz-Tests
│   ├── test-usbipd-binding.ps1              # USB Binding Validation
│   └── test-scanner-detection.sh            # SANE Scanner Detection
│
├── docs/
│   ├── INSTALLATION.md                      # Schritt-für-Schritt Anleitung
│   ├── SCANNER_MODELS.md                    # Unterstützte Scanner
│   ├── TROUBLESHOOTING.md                   # Häufige Probleme
│   ├── DISTRO_MATRIX.md                     # Ubuntu/Alpine Support Matrix
│   └── USBIPD_REFERENCE.md                  # usbipd-win Kommando Referenz
│
├── logs/                                    # .gitignore: *.log, *.txt
│   └── .gitkeep
│
└── .attic/                                  # Alte Versionen (nicht gepusht)
    └── v0.9.0-alpha/
```

## Phase 1: Haupteinstiegspunkt (Windows PowerShell)

### Start.bat → Start.ps1 → Scanner.Install.Module.ps1

**Ausführungsflow:**
1. `Start.bat` - Batch Wrapper (ExecutionPolicy Bypass per /r flag)
2. `Start.ps1` - PowerShell Host (Version Check, Module Load)
3. `Scanner.Install.Module.ps1` - Interaktiver Menu:
   ```
   ┌─────────────────────────────────────────┐
   │  ScannerInstall v1.0.0                  │
   │                                         │
   │  1) Check WSL2 & Install                │
   │  2) Install usbipd-win                  │
   │  3) Prepare WSL Distribution            │
   │  4) Attach USB Scanner Device           │
   │  5) Test Scanner & SANE                 │
   │  6) Configure Epson DS-80W              │
   │  7) View Logs                           │
   │  8) Exit                                │
   └─────────────────────────────────────────┘
   ```

## Phase 2: Scanner-Parameter (Konfigurierbar)

### config/Scanner.config.json

```json
{
  "scanner": {
    "name": "Epson DS-80W",
    "model": "DS-80W",
    "vendor_id": "04b8",
    "product_id": "0159",
    "driver": "epsonscan2",
    "sane_device": "epson:libusb:001:001",
    "config_files": [
      "/etc/sane.d/epson.conf",
      "/etc/udev/rules.d/50-udev-epson.rules"
    ],
    "kernel_modules": ["vhci_hcd", "usbip_core"]
  }
}
```

**Leicht austauschbar für:**
- Fujitsu iX500 (04c5:1041)
- Canon IMAGERUNNER (Canon inkl.)
- Ricoh (ricoh-specific)

## Phase 3: WSL2 + Distribution Detection

### scripts/1-check-wsl2.ps1

Features:
- ✅ WSL2 Existenz-Prüfung
- ✅ Installierte Distributionen auflisten
- ✅ Standarddistro auswählen ODER neu installieren
- ✅ Ubuntu 22.04 / Alpine 3.19 Support
- ✅ SSH-Keys Setup für remote Zugriff

## Phase 4: usbipd-win Installation & Binding

### scripts/2-install-usbipd.ps1

```powershell
# Automatisch via winget
winget install --interactive --exact "dorssel.usbipd-win" `
  --accept-package-agreements `
  --accept-source-agreements

# oder Alternative aus GitHub (falls winget fehlschlägt):
# https://github.com/dorssel/usbipd-win/releases

# Nach Installation: usbipd bind --hardware-id=<id>
```

## Phase 5: Linux-Seite - SANE + Kernel Module

### linux/sane-setup.sh (Ubuntu/Debian)

```bash
#!/bin/bash
# SANE + Epson epsonscan2 Setup für Ubuntu/Debian
set -e

SCANNER_NAME="${1:-DS-80W}"
VENDOR_ID="${2:-04b8}"
PRODUCT_ID="${3:-0159}"

# 1. Dependencies installieren
sudo apt-get update
sudo apt-get install -y sane sane-utils libsane1

# 2. Epson SANE Backend
sudo apt-get install -y libsane-epson

# 3. Kernel Module für USB
sudo modprobe vhci-hcd
sudo modprobe usbip-core
sudo modprobe usbip-host

# 4. udev rules
sudo tee /etc/udev/rules.d/50-udev-epson.rules << EOF
# Epson $SCANNER_NAME ($VENDOR_ID:$PRODUCT_ID)
SUBSYSTEM=="usb", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", MODE="0666"
SUBSYSTEM=="usb_device", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", MODE="0666"
EOF

# 5. Kernel Module beim Systemstart
echo "vhci-hcd" | sudo tee /etc/modules-load.d/vhci-hcd.conf
echo "usbip-core" | sudo tee -a /etc/modules-load.d/vhci-hcd.conf

# 6. Test
sudo sane-find-scanner -v
lsmod | grep vhci
```

### linux/sane-setup-alpine.sh (Alpine Linux)

```bash
#!/bin/bash
# SANE Setup für Alpine (OpenRC statt systemd)
set -e

# Alpine-spezifisch:
sudo apk add sane sane-backends-libsane sane-backends-epson

# Kernel Module - Alpine nutzt OpenRC!
echo "vhci_hcd" | sudo tee /etc/modules-load.d/vhci-hcd.conf
# OpenRC service statt systemd → scripts/5-sysconfig-alpine.rc

# Rest analog...
```

## Phase 6: Automatisches Kernel-Modul-Loading

### scripts/5-kernel-module-setup.ps1 (Windows PowerShell)

Mittels WSL Remote-Execution + SSH:

```powershell
# Distro ermitteln (Ubuntu/Alpine/Debian)
$distro = (wsl -l --verbose | Select-String "Running").split()[0]

# SSH-basierte Ausführung
if ($distro -match "Ubuntu") {
    wsl -d $distro -u root bash -c "echo 'vhci-hcd' | tee /etc/modules-load.d/vhci-hcd.conf"
    wsl -d $distro -u root systemctl enable networking  # systemd syntax
} elseif ($distro -match "Alpine") {
    wsl -d $distro -u root ash -c "echo 'vhci-hcd' >> /etc/modules"
    wsl -d $distro -u root rc-service networking restart  # OpenRC syntax
}
```

## Phase 7: udev Rules & Scanner-Zugriff

### config/50-epson.rules.template

```bash
# Epson DS-80W SANE
SUBSYSTEMS=="usb", ATTRS{idVendor}=="04b8", ATTRS{idProduct}=="0159", MODE="0666", GROUP="lpadmin"
SUBSYSTEMS=="usb_device", ATTRS{idVendor}=="04b8", ATTRS{idProduct}=="0159", MODE="0666", GROUP="lpadmin"

# SANE daemon access
SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="04b8", ATTRS{idProduct}=="0159", RUN+="sane-find-scanner %E{DEVNAME}"
```

## Phase 8: Testing & Validation

### tests/test-scanner-detection.sh

```bash
#!/bin/bash
# Scanner Detection Testsuite

echo "=== SANE Scanner Detection ==="
sudo sane-find-scanner -v

echo "=== SANE Devices List ==="
scanimage -L

echo "=== vhci Kernel Module Status ==="
lsmod | grep vhci

echo "=== udev Monitor (USB Events) ==="
sudo udevadm monitor --udev --subsystem-match=usb --property &
sleep 5
kill $!

echo "=== Scanner-Device Check ==="
ls -la /dev/usb* 2>/dev/null || echo "No USB devices found"

echo "=== SANE Configuration ==="
cat /etc/sane.d/epson.conf | grep -v "^#" | grep -v "^$"
```

## Lizenzierung & Konventionen (ExecutionPolicy-Foundation Stil)

```
# (C) 2026 GrEEV.com KG. All rights reserved.
# 
# Dual Licensed:
# - MIT License (Permissive use in commercial products)
# - AGPLv3 (Network Copyleft for SaaS modifications)
# 
# Choose either license for your use case.
```

## Release Management

| Version | Status | Release Date | Notes |
|---------|--------|--------------|-------|
| 0.9.0-alpha | Prototype | 2026-01-18 | Initial DS-80W setup |
| 1.0.0 | Stable | 2026-01-21 | Multi-scanner, multi-distro support |
| 1.1.0 | Planned | TBD | Docker support, Alpine improvements |

## Git Workflow

1. **Clone from ExecutionPolicy-Foundation Template:**
   ```powershell
   gh repo create ScannerInstall --template KonradLanz/ExecutionPolicy-Foundation --public --clone
   ```

2. **Develop locally** in `C:\Users\koni\ScannerInstall\`

3. **Push to GitHub:**
   ```powershell
   git add .
   git commit -m "feat: add multi-scanner support for v1.0.0"
   git push origin main
   ```

4. **Optional: Gitea staging** (für nicht-öffentliche Daten)
   ```powershell
   git remote add qnap https://gitea.qnap.local/koni/scanner-install.git
   git push qnap main  # Nur gefilterte Daten
   ```

---

**Nächste Schritte:**
1. ✅ Struktur-Overview (DIESE DATEI)
2. 🔲 Start.bat + Start.ps1 von ExecutionPolicy-Foundation anpassen
3. 🔲 Scanner.Install.Module.ps1 schreiben (Menü + Koordination)
4. 🔲 scripts/*.ps1 implementieren (WSL, usbipd, etc.)
5. 🔲 linux/*.sh scripts implementieren (SANE, udev, kernel modules)
6. 🔲 config/Scanner.config.json Schema standardisieren
7. 🔲 tests/*.ps1 + tests/*.sh schreiben
8. 🔲 docs/ komplettieren
9. 🔲 v1.0.0 Tag setzen & GitHub pushen

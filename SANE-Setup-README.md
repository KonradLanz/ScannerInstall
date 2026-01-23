# ScannerInstall - Interactive SANE Setup v2.0

**Multi-Hardware-Scanner-Konfiguration mit interaktiven Rückfragen und Backup**

```
GrEEV.com KG | AGPL-3.0 / MIT (Dual Licensed)
Support: support@greev.com | www.greev.com
```

---

## 🎯 Features

✅ **Auto-Detektion** von 15+ Scanner-Modellen (Epson, Brother, HP, Fujitsu, Canon)  
✅ **Intelligente Rückfragen** bei jeder Änderung (Backup, Bestätigung)  
✅ **Hardware-ID-Datenbank** mit Vendor/Product-Codes  
✅ **Backend-Aktivierung** (epsonds, brother4, hpaio, etc.)  
✅ **udev-Regeln** für USB-Zugriff  
✅ **Permission-Setup** (scanner + lp groups)  
✅ **Automatische Backups** vor jeder Änderung  
✅ **Dry-Run & Non-Interactive Modi** für CI/CD  

---

## 📋 Unterstützte Scanner

| Hersteller | Modelle | Backend |
|-----------|---------|---------|
| **Epson** | DS-80W, DS-70, RX-10, FF-120 | epsonds, epsonscan2 |
| **Brother** | DCP-9022CDW, MFC-7360, DCP-7055 | brother4, brother5 |
| **HP** | OfficeJet J5700, ScanJet Pro | hpaio |
| **Fujitsu** | ScanSnap iX100, iX500 | fujitsu |
| **Canon** | imageFORMULA DR-F120, LiDE220 | canon, pixma |

---

## 🚀 Verwendung

### Option 1: PowerShell (Windows → WSL)

```powershell
# Repo klonen
git clone https://github.com/KonradLanz/ScannerInstall.git
cd ScannerInstall

# Setup starten (interaktiv)
.\Start-ScannerSetup.ps1

# Oder mit Optionen
.\Start-ScannerSetup.ps1 -DryRun              # Vorschau ohne Änderungen
.\Start-ScannerSetup.ps1 -NonInteractive      # Automatisiert (CI/CD)
.\Start-ScannerSetup.ps1 -Debug               # Mit Debug-Ausgabe
```

### Option 2: Bash (Linux/WSL direkt)

```bash
git clone https://github.com/KonradLanz/ScannerInstall.git
cd ScannerInstall

# Setup starten (interaktiv)
sudo ./sane-setup-interactive.sh

# Oder mit Optionen
sudo ./sane-setup-interactive.sh --dry-run              # Vorschau
sudo ./sane-setup-interactive.sh --non-interactive      # Automatisiert
sudo ./sane-setup-interactive.sh --debug                # Debug
```

---

## 🔄 Workflow

Das Script führt 6 Phasen automatisch durch:

### Phase 1: Hardware-Detektion
- `lsusb` durchsucht nach bekannten Scanner-IDs
- Zeigt erkannte Modelle an (z.B. "Detected: epson_ds80w (04b8:0120)")

### Phase 2: SANE-Status-Check
- `scanimage -L` als Benutzer und sudo
- Zeigt aktuelle SANE-Erkennungen

### Phase 3: Paket-Installation
- `sane`, `sane-utils`, `libsane1`
- Vendor-spezifische Pakete (epsonscan2, brother-scanner-driver-bin, hplip)
- **Rückfrage vor Installation** ← Du gibst Bestätigung!

### Phase 4: Backend-Konfiguration
- Aktiviert benötigte Backends in `/etc/sane.d/dll.conf`
- Erstellt udev-Regeln in `/etc/udev/rules.d/`
- **Rückfrage für jedes Backend** ← Du kannst einzelne überspringen!

### Phase 5: Permission-Setup
- Erstellt `scanner` Group (falls nicht vorhanden)
- Fügt deinen Benutzer zu `scanner` + `lp` Groups hinzu
- **Mit Rückfrage** ← Bestätigung notwendig

### Phase 6: Testing
- Testet `scanimage -L` als Benutzer und sudo
- Optional: `scanimage --test` für Funktionsprüfung
- **Mit Rückfrage** ← Du kannst Tests überspringen

---

## 📝 Beispiel-Session

```bash
$ sudo ./sane-setup-interactive.sh

╔══════════════════════════════════════════════════════════════╗
║  ScannerInstall - Interactive SANE Setup v2.0               ║
║  GrEEV.com KG | AGPL-3.0 / MIT (Dual Licensed)             ║
╚══════════════════════════════════════════════════════════════╝

ℹ️  Phase 1: Hardware Detection
─────────────────────────────────
ℹ️  Scanning for USB scanners...
✅ Detected: epson_ds80w (04b8:0120)
✅ Detected: brother_dcp9022cdw (04f9:0266)

ℹ️  Phase 2: SANE Status Check
─────────────────────────────────
ℹ️  Checking SANE detection...
ℹ️  SANE-detected devices (non-privileged):
device `epsonscan2:networkscanner:esci2:network:192.168.1.8' is a EPSON network scanner flatbed scanner

ℹ️  Phase 3: Package Installation
─────────────────────────────────
ℹ️  Required packages:
  - sane
  - sane-utils
  - libsane1
  - epsonscan2
  - brother-scanner-driver-bin
? Install packages? [y/n] (default: n): y
✅ Packages installed

ℹ️  Phase 4: Backend Configuration
─────────────────────────────────
ℹ️  Configuring backends for: epson_ds80w (04b8:0120)
ℹ️  Backend 'epsonds' not found in dll.conf
? Add backend 'epsonds' to dll.conf? [y/n] (default: n): y
✅ Added backend: epsonds
? Add backend 'epsonscan2' to dll.conf? [y/n] (default: n): y
✅ Added backend: epsonscan2

ℹ️  Setting up udev rule for epson_ds80w
? Create udev rule for epson_ds80w (vendor:product 04b8:0120)? [y/n] (default: n): y
✅ Created udev rule: /etc/udev/rules.d/65-scanner-epson_ds80w.rules
? Reload udev rules now? [y/n] (default: n): y
✅ udev rules reloaded

ℹ️  Phase 5: Permission Setup
─────────────────────────────────
? Add 'koni' to scanner and lp groups? [y/n] (default: n): y
✅ User 'koni' added to groups
⚠️  User must log out and back in for group changes to take effect

ℹ️  Phase 6: Testing
─────────────────────────────────
ℹ️  Running SANE tests...
✅ scanimage -L (user) succeeded
✅ scanimage -L (sudo) succeeded

╔══════════════════════════════════════════════════════════════╗
║           SANE Setup - Configuration Summary               ║
╚══════════════════════════════════════════════════════════════╝

✅ Changes made:
  Added backend: epsonds
  Added backend: epsonscan2
  Created udev rule: /etc/udev/rules.d/65-scanner-epson_ds80w.rules
  User 'koni' added to scanner,lp groups

ℹ️  Backup location: /var/backups/sane-setup-20260123_110530
? Restore from backup (revert changes)? [y/n] (default: n): n

✅ Done!
```

---

## 🔧 Konfiguration Anpassen

### Hardware-IDs hinzufügen

Bearbeite `SCANNER_DB` in `sane-setup-interactive.sh`:

```bash
declare -A SCANNER_DB=(
    ["dein_scanner"]="vendorID:productID|vendorID2:productID2"
)

declare -A SCANNER_BACKEND=(
    ["dein_scanner"]="backend1,backend2"
)
```

Finde die Vendor/Product-IDs mit:
```bash
lsusb
# Beispiel: Bus 001 Device 003: ID 04b8:0120 Seiko Epson Corp.
#                                    ^^^^^^ Vendor
#                                          ^^^^^^ Product
```

---

## 🐛 Troubleshooting

### Scanner wird nicht erkannt

```bash
# 1. Manuell mit lsusb checken
lsusb | grep -i scanner

# 2. Mit SANE debuggen
SANE_DEBUG_DLL=5 scanimage -L

# 3. Manuell Backend-String aus Hardware-ID bauen und übergeben
pct-scanner-script --device 'epsonds:libusb:001:002' --lineart -Y 2025
```

### Permissions fehlen

```bash
# Manuell zu Groups hinzufügen
sudo usermod -a -G scanner,lp $USER

# Gruppen checken
groups
```

### Backup zurückrollen

```bash
# Letzte Backups anzeigen
ls -la /var/backups/sane-setup-*/

# Manuell zurückrollen
sudo cp /var/backups/sane-setup-YYYYMMDD_HHMMSS/dll.conf /etc/sane.d/dll.conf
```

---

## 📦 Installation von Abhängigkeiten

Das Script installiert automatisch:

| Paket | Zweck |
|-------|-------|
| `sane` | SANE Framework |
| `sane-utils` | `scanimage`, `scanadf` CLI |
| `libsane1` | SANE Library |
| `epsonscan2` | Epson-Treiber (wenn Epson erkannt) |
| `brother-scanner-driver-bin` | Brother-Treiber (wenn Brother erkannt) |
| `hplip` | HP-Treiber (wenn HP erkannt) |

---

## 🔌 Nach dem Setup

1. **Log out und back in** (für Group-Änderungen)
   ```bash
   exit  # oder neue Shell-Session
   ```

2. **Testen mit pct-scanner-script**
   ```bash
   pct-scanner-script --lineart -Y 2025
   ```

3. **Oder mit scanhelper / pct-scanner-py**
   ```bash
   scanhelper --device 'epsonds:libusb:001:002' --feed --output-dir ./scans/
   ```

---

## 📖 Dokumentation

- SANE Dokumentation: https://sane-project.gitlab.io/
- Backend-Configs: `/etc/sane.d/*.conf`
- udev-Regeln: `/etc/udev/rules.d/`
- Backups: `/var/backups/sane-setup-*/`

---

## 📄 Lizenzierung

Dual Licensed:
- **AGPL-3.0** für Open-Source-Projekte
- **MIT** für kommerzielle Nutzung
- **Professional Support**: EUR 499/year

Kontakt: support@greev.com | www.greev.com

---

## 🤝 Beitragen

Issues & PRs auf GitHub welcome!
https://github.com/KonradLanz/ScannerInstall

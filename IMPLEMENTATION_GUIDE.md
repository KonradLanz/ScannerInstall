# ScannerInstall - Implementierungs-Anleitung v1.0.0
# Schritt-für-Schritt Aufbau des GitHub-Ready Projekts

## Phase 1: Repository Setup (ExecutionPolicy-Foundation Template)

### 1.1 Neues Repo von Template erstellen

```powershell
# PowerShell 7+
cd C:\Temp\GitHub

# Mit gh CLI
gh repo create ScannerInstall `
  --template KonradLanz/ExecutionPolicy-Foundation `
  --public `
  --clone

cd ScannerInstall

# ODER manuell:
# 1. GitHub Web: https://github.com/new?template=KonradLanz/ExecutionPolicy-Foundation
# 2. Repository Name: ScannerInstall
# 3. Create repository
# 4. Lokal clonen

git clone https://github.com/<DEIN_USERNAME>/ScannerInstall.git
cd ScannerInstall
```

### 1.2 Remote-Konfiguration (falls nötig zu Gitea)

```powershell
# Template upstream speichern (Optional, für Updates)
git remote add template https://github.com/KonradLanz/ExecutionPolicy-Foundation.git

# Gitea staging (nur gefilterte Daten, später - siehe PCT-Scanner Projekt)
# git remote add qnap https://gitea.qnap.local/koni/scanner-install.git
```

---

## Phase 2: Projekt-Struktur aufbauen

### 2.1 Ordner-Struktur erstellen

```powershell
# Im Root des geklonten Repos:
mkdir src, scripts, linux, config, tests, docs, logs

New-Item -ItemType File -Path "src/.gitkeep"
New-Item -ItemType File -Path "linux/.gitkeep"
New-Item -ItemType File -Path "config/.gitkeep"
New-Item -ItemType File -Path "tests/.gitkeep"
New-Item -ItemType File -Path "logs/.gitkeep"
```

### 2.2 .gitignore aktualisieren

```bash
# Anhängend zu existierendem .gitignore:

# ScannerInstall specific
logs/**/*.log
logs/**/*.txt
*.backup
*.bak

# Temp & Work Files
.temp/
*.swp
*.swo
*~

# WSL specific
.wsl/
wsl_distro_backup/

# Scanner Config (sensitive)
config/**/private-*.json
config/**/secrets.json

# Test Artifacts
test-output/
test-results/
*.pnm
*.tiff
```

---

## Phase 3: Dateien ins Repo kopieren

### 3.1 PowerShell Module (src/)

**Dateien aus den generierten Downloads:**

```powershell
# Kopiere aus Artifacts:
# → Scanner.Install.Module.ps1 → src/
# → Scanner.Config.ps1 → src/  (später erstellen)
# → unblock-files.ps1 → src/

Copy-Item Scanner.Install.Module.ps1 -Destination src/
# (Config + Unblock folgen später)
```

**Start.ps1 anpassen (von ExecutionPolicy-Foundation):**

```powershell
# Start.ps1 sollte bereits im Root sein
# Anpassen für ScannerInstall:

# Zeile ~20-30:
# Bei "select main script" auch "Scanner.Install.Module.ps1" hinzufügen

# Alternativ: Direkter Einstieg
# . .\src\Scanner.Install.Module.ps1
```

### 3.2 Linux-Scripts (linux/)

```powershell
# Linux-Scripts hochladen (kopieren aus Artifacts):
Copy-Item sane-setup-ubuntu.sh -Destination linux/
Copy-Item sane-setup-alpine.sh -Destination linux/  # später erstellen
Copy-Item scanner-kernel-module.sh -Destination linux/
Copy-Item udev-rules-epson.sh -Destination linux/
```

### 3.3 Konfiguration (config/)

```powershell
# JSON Config hochladen:
Copy-Item Scanner.config.json -Destination config/

# Templates für Linux-Seite
New-Item -ItemType File -Path config/epson.conf.template
New-Item -ItemType File -Path config/50-epson.rules.template
```

---

## Phase 4: First Commit & Push

```powershell
cd C:\Temp\GitHub\ScannerInstall

# Status prüfen
git status

# Alle neuen Dateien stageen
git add .

# Commit
git commit -m "feat: initial ScannerInstall v1.0.0 structure

- Add PowerShell main module (Scanner.Install.Module.ps1)
- Add Linux SANE setup scripts (ubuntu/alpine)
- Add universal Scanner.config.json
- Add project documentation structure
- Based on ExecutionPolicy-Foundation template

BREAKING: Initial version, API may change"

# Push to GitHub
git push -u origin main

# Tag setzen für Release
git tag -a v1.0.0 -m "Initial release: ScannerInstall v1.0.0 with DS-80W support"
git push origin v1.0.0
```

---

## Phase 5: Dokumentation (docs/)

### 5.1 README.md

```markdown
# ScannerInstall v1.0.0

Universal Scanner Installation & USB-Binding for WSL2 + Linux

## Quick Start

```powershell
# Windows PowerShell
.\Start.bat

# Select: Scanner.Install.Module.ps1
```

## Features

- ✅ WSL2 Detection & Distribution Management (Ubuntu/Alpine/Debian)
- ✅ usbipd-win Installation (winget)
- ✅ SANE Framework Setup (distro-specific)
- ✅ Kernel Module Configuration (systemd/OpenRC)
- ✅ udev Rules Management
- ✅ Universal Scanner Parameter (Epson DS-80W, extensible)

## Supported Scanners

| Scanner | Vendor ID | Product ID | Status |
|---------|-----------|------------|--------|
| Epson DS-80W | 04b8 | 0159 | ✅ Tested |
| Epson DS-530 | 04b8 | 012e | 🔲 Planned |
| Fujitsu iX500 | 04c5 | 1041 | 🔲 Planned |

## Installation

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for detailed steps.

## License

Dual Licensed: MIT + AGPLv3
(C) 2026 GrEEV.com KG
```

### 5.2 INSTALLATION.md (Schritt-für-Schritt)

```markdown
# ScannerInstall - Installationsanleitung

## Voraussetzungen

- Windows 10/11 mit WSL2
- PowerShell 5.1+ oder PowerShell 7.5+
- Administrator-Rechte
- Git installiert

## Schritt 1: Repository klonen

```powershell
git clone https://github.com/<USER>/ScannerInstall.git
cd ScannerInstall
```

## Schritt 2: PowerShell Script ausführen

```powershell
.\Start.bat
# oder
.\Start.ps1 -ScriptName "Scanner.Install.Module.ps1" -Language de
```

## Schritt 3: Interaktives Menu

```
1) Check WSL2 & Install
2) Install usbipd-win
3) Prepare WSL Distribution
4) Attach USB Scanner
5) Test Scanner
```

## Schritt 4: Scanner anschließen

Verbinde Scanner via USB nach Schritt 3.

## Schritt 5: Scanner validieren

```bash
# In WSL
sane-find-scanner -v
scanimage -L
```

Siehe [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) bei Problemen.
```

### 5.3 SCANNER_MODELS.md

```markdown
# Unterstützte Scanner-Modelle

## Epson DS-80W (Standard)

- **Vendor ID:** 04b8
- **Product ID:** 0159
- **Driver:** epsonscan2
- **Type:** Document Scanner mit Automatic Document Feeder
- **Status:** ✅ Getestet und funktionierend

### Custom Scanner hinzufügen

Edit `config/Scanner.config.json`:

```json
{
  "scanner": {
    "name": "Mein Scanner",
    "vendor_id": "XXXX",
    "product_id": "YYYY",
    "driver": "driver_name",
    ...
  }
}
```

Dann:
```powershell
.\Scanner.Install.Module.ps1 -ScannerModel "Mein Scanner"
```
```

---

## Phase 6: Testing lokale Workflows

### 6.1 WSL2 + Distribution testen

```powershell
# Schritt 1 laufen lassen
.\Start.bat
# Menü → 1

# Prüfe WSL Status
wsl -l --verbose

# Ubuntu neu starten
wsl --terminate Ubuntu-22.04
wsl -d Ubuntu-22.04 -u root bash
```

### 6.2 SANE Setup testen (in WSL)

```bash
# SSH in WSL:
# oder: wsl -d Ubuntu-22.04 -u root bash

# Manuell SANE einrichten:
cd /tmp/ScannerInstall
bash sane-setup.sh "DS-80W" "04b8" "0159"

# Resultat checken:
sane-find-scanner -v
scanimage -L
lsmod | grep vhci
```

### 6.3 usbipd Test (in PowerShell)

```powershell
# usbipd list
usbipd list

# Manuell binden (falls vorhanden)
usbipd bind --hardware-id=04b8:0159
usbipd attach --wsl --hardware-id=04b8:0159 --auto-attach
```

---

## Phase 7: GitHub Actions (Optional - später)

```yaml
# .github/workflows/test-sane.yml (später)
name: Test SANE Installation

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Test SANE Setup
        run: bash linux/sane-setup.sh
```

---

## Phase 8: Release & Versioning

```powershell
# Nach abgeschlossenen Tests:

git tag -a v1.0.0-rc1 -m "Release Candidate 1"
git push origin v1.0.0-rc1

# Nach Feedback:
git tag -a v1.0.0 -m "Stable Release - DS-80W fully tested"
git push origin v1.0.0

# GitHub Releases erstellen:
# https://github.com/<USER>/ScannerInstall/releases
```

---

## Weitere Schritte (Roadmap)

### v1.1.0 (Geplant)
- [ ] Docker-Container Variante (alpine-based)
- [ ] Mehrere Scanner gleichzeitig unterstützen
- [ ] GUI für Scanner-Auswahl (PowerShell ISE)
- [ ] CI/CD Testing auf GitHub Actions

### v1.2.0
- [ ] Fujitsu iX500 Support
- [ ] Canon IMAGERUNNER Support
- [ ] Ricoh Scanner Support
- [ ] OCR Pipeline Integration (tesseract)

### Later
- [ ] Gitea Integration für Private Repos
- [ ] QNAP Native Installation
- [ ] Docker Compose Full Stack

---

## Lizenzierung

```
(C) 2026 GrEEV.com KG. All rights reserved.

Dual Licensed:
- MIT License: Use freely in commercial products
- AGPLv3: Network Copyleft for SaaS modifications

Choose either license for your use case.
```

## Support

- **Issues:** https://github.com/<USER>/ScannerInstall/issues
- **Discussions:** https://github.com/<USER>/ScannerInstall/discussions
- **Docs:** [docs/](docs/)

---

**Bereit zum Starten? Los geht's! 🚀**

```powershell
cd C:\Temp\GitHub\ScannerInstall
.\Start.bat
```

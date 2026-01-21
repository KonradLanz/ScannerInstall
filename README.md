# ExecutionPolicy Foundation v2.0.0

**GrEEV.com KG - Professional PowerShell Execution Policy Management**

> Manage PowerShell ExecutionPolicy safely across Windows 10/11, handle Zone.Identifier issues, and detect Group Policy locks.

---

## 🚀 Quick Start

### Option 1: Direct PowerShell (RECOMMENDED)

```powershell
cd C:\Users\koni\ExecutionPolicy-Foundation

.\Start.ps1 -Language de
```

✅ **Auto-unblocks Zone.Identifier automatically**

### Option 2: Via Batch File

```batch
cd C:\Users\koni\ExecutionPolicy-Foundation

Start.bat Start.ps1 de
```

### Option 3: English Version

```powershell
.\Start.ps1 -Language en
```

---

## 📋 Features

✅ **ExecutionPolicy Detection**
- Checks all scopes (MachinePolicy, UserPolicy, Process, CurrentUser, LocalMachine)
- Detects Group Policy locks
- Prevents bypass attempts

✅ **Zone.Identifier Handling**
- Auto-unblocks downloaded .ps1 files
- Removes NTFS ADS (Alternate Data Streams)
- Safe for enterprise environments

✅ **Internationalization**
- Full English support
- Vollständige deutsche Unterstützung
- All messages, errors, and documentation localized

✅ **Professional Support**
- EUR 499/year - 48-hour response SLA
- Priority bug fixes
- Deployment consultation
- Email: support@greev.com

---

## 📦 File Structure

```
ExecutionPolicy-Foundation/
├── Start.bat                    Batch launcher (calls PowerShell)
├── Start.ps1                    Main script (EN/DE, auto-unblock)
├── unblock-files_v1.0.0.ps1     Standalone unblock utility
├── setup.ps1                    Setup template (customize)
├── README.md                    This file
├── INSTALLATION-GUIDE.md        Detailed setup & Git workflow
├── PROFESSIONAL-SUPPORT.md      Support agreement & pricing
├── LICENSE                      AGPLv3 Community License
├── MIT-LICENSE                  MIT Commercial License
└── .gitattributes               Git configuration
```

---

## 📖 Usage

### Basic Execution

```powershell
# English version
.\Start.ps1

# German version
.\Start.ps1 -Language de

# Show current policies
.\Start.ps1 -ShowPolicies

# With custom script
.\Start.ps1 -ScriptName "setup.ps1" -Language de
```

### What It Does

1. ✓ Sets UTF-8 console encoding (Box-drawing characters)
2. ✓ Auto-unblocks all .ps1 files (Zone.Identifier removal)
3. ✓ Checks ExecutionPolicy on all scopes
4. ✓ Detects Group Policy locks
5. ✓ Executes your custom scripts

---

## 🔐 Licensing

Choose the license that fits your use case:

### Tier 1: Community (FREE - AGPLv3)
```
✓ Open source projects
✓ Community support (GitHub Issues)
✓ Free forever
✗ Closed-source not allowed
✗ SaaS requires code disclosure
```

**Use:** Open source projects, individual use, educational purposes

### Tier 2: Developer (FREE - MIT)
```
✓ Commercial software
✓ SaaS allowed
✓ Closed-source OK
✓ Free forever
✗ No support included
```

**Use:** Commercial applications, SaaS products, proprietary software

### Tier 3: Professional Support (EUR 499/year)
```
✓ Add to ANY license (AGPLv3 or MIT)
✓ 48-hour response SLA
✓ Priority bug fixes
✓ Deployment consultation
✓ Quarterly health checks
```

**Use:** Enterprise deployments, mission-critical systems, commercial support

---

## 🔧 Advanced: Custom Scripts

Edit `setup.ps1` to add your own functionality:

```powershell
# setup.ps1
Write-Host "Your custom script here"

# Use the Config from Start.ps1
if ($Language -eq "de") {
    Write-Host "Deutsch"
} else {
    Write-Host "English"
}
```

Then run:

```powershell
.\Start.ps1 -ScriptName "setup.ps1" -Language de
```

---

## ⚡ Troubleshooting

### "Script cannot be loaded" Error

Start.ps1 **automatically removes Zone.Identifier**, but if it fails:

```powershell
Unblock-File -Path .\Start.ps1
.\Start.ps1
```

### ExecutionPolicy Still Blocked

If Group Policy locks ExecutionPolicy to "Restricted":

```powershell
Get-ExecutionPolicy -List
```

**Solution:** Contact your IT administrator to modify the Group Policy Object (GPO)

### UTF-8 Characters Not Displaying

Encoding is set automatically, but if needed:

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
.\Start.ps1
```

---

## 📞 Support

### Community Support (FREE)
- GitHub Issues: https://github.com/greev/ExecutionPolicy-Foundation/issues
- Documentation: See INSTALLATION-GUIDE.md

### Professional Support (EUR 499/year)
- **Email:** support@greev.com
- **SLA:** 48-hour response guarantee
- **Includes:** Priority fixes, consultation, quarterly reviews

### Custom Development
- **Email:** office@greev.com
- **Rate:** EUR 89/hour (development), EUR 299/day (consulting)
- **Projects:** EUR 1500+ (full integration)

---

## 🔄 Code Signing (Roadmap)

**Currently:** Unsigned (auto-unblock handles this)

**Future (v2.1.0):** 
- FastSSL Code Signing Certificate (EUR 120/year)
- All scripts digitally signed
- Trusted across Windows without warnings
- GitHub Actions CI/CD for auto-signing

---

## 📝 License

Dual Licensed under:

1. **AGPLv3** - Community/Open Source
   - See LICENSE file
   - https://www.gnu.org/licenses/agpl-3.0.html

2. **MIT** - Commercial
   - See MIT-LICENSE file
   - https://opensource.org/licenses/MIT

**SPDX:** (AGPL-3.0-or-later OR MIT)

---

## 👥 About GrEEV.com KG

**GrEEV.com KG** is an Austrian IT infrastructure and standardization company based in Vienna.

**Focus Areas:**
- Digital identity and eIDAS standards
- IT security and standardization
- Infrastructure as Code
- Open source solutions

**Contact:**
- Website: https://www.greev.com
- General: office@greev.com
- Support: support@greev.com
- Location: Graz, Austria

---

## 📊 Version History

| Version | Date | Changes |
|---------|------|---------|
| v2.0.0 | 2026-01-19 | ✓ Support Model, EN/DE, Auto-Unblock, Unsigned |
| v1.0.0 | 2026-01-18 | Initial release |

---

## 🎯 Next Steps

1. ✅ Download all files
2. ✅ Run `.\Start.ps1 -Language de` to test
3. ✅ Customize `setup.ps1` for your needs
4. ✅ Push to GitHub (or your repository)
5. ✅ Optional: Subscribe to Professional Support

---

**Generated:** January 19, 2026  
**Status:** ✅ PRODUCTION READY  
**Version:** v2.0.0  
**Copyright © 2026 GrEEV.com KG**

SPDX-License-Identifier: (AGPL-3.0-or-later OR MIT)


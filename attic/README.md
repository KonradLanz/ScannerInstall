# ExecutionPolicy Foundation v2.0.0

**GrEEV.com KG** - Robust PowerShell execution framework with GPO detection and Zone.Identifier handling.

**Dual Licensed** | **FREE** with optional Professional Support

---

## 🚀 Quick Start

### Option A: Batch Wrapper (Recommended)

```batch
Start.bat
Start.bat setup.ps1
Start.bat script.ps1 de
```

### Option B: PowerShell Native

```powershell
.\Start.ps1 -ShowPolicies
.\Start.ps1 -ScriptName setup.ps1 -Language de
.\Start.ps1 -ScriptName verify.ps1 -WhatIf
```

---

## 📋 How It Works

### Two-Layer Protection

Windows blocks PowerShell scripts in two ways:

1. **ExecutionPolicy** (System-level) - PowerShell built-in policy
2. **Zone.Identifier** (File-level) - NTFS stream marking files as "from Internet"

This framework handles **both**:

```
Start.bat / Start.ps1
│
├─ Phase 1: Validate script exists
├─ Phase 2: Check for GPO restrictions
│  └─ If MachinePolicy=Restricted → FATAL (requires IT admin)
├─ Phase 3: Unblock downloaded files
│  └─ Remove Zone.Identifier from all .ps1 files
├─ Phase 4: Execute main script
│  └─ Run with -ExecutionPolicy Bypass
└─ Phase 5: Error diagnostics
   └─ Provide actionable error messages
```

---

## 📄 Licensing & Support

### FREE Options

**AGPLv3 (Community)**
- ✓ Open source projects
- ✓ Individual developers
- ✗ Closed-source or SaaS

**MIT (Developer)**
- ✓ Commercial software
- ✓ SaaS allowed
- ✓ Closed-source OK
- ✗ No support included

### Professional Support (EUR 499/year)

**Add Professional Support to EITHER license:**
- ✓ 48-hour guaranteed response time (SLA)
- ✓ Priority bug fixes and security patches
- ✓ Deployment consultation and guidance
- ✓ Direct email support: support@greev.com
- ✓ Quarterly health check and updates review

### License Comparison Table

| Feature | Community | Developer | + Professional |
|---------|-----------|-----------|-----------------|
| **License** | AGPLv3 | MIT | AGPLv3 or MIT |
| **Cost** | Free | Free | EUR 499/year |
| **Commercial Use** | No | **Yes** | **Yes** |
| **Closed Source** | No | **Yes** | **Yes** |
| **SaaS Allowed** | If open | **Yes** | **Yes** |
| **Email Support** | No | No | **Yes (48h)** |
| **Priority Fixes** | No | No | **Yes** |
| **Consulting** | No | No | **Yes** |
| **Response Time** | N/A | N/A | **48h SLA** |

---

## 📞 Getting Support

### Free Community Support
- GitHub Issues for bug reports
- Community contributions
- Self-service troubleshooting

### Professional Support (EUR 499/year)

1. Contact: **office@greev.com**
2. Request Professional Support Agreement
3. Receive: support email account, ticket system
4. Email: **support@greev.com** with issues
5. We respond within 48 hours (24 for security)

### Custom Development

Need custom scripts or modifications?

- **EUR 89/hour** - Script development
- **EUR 299/day** - Consulting and architecture
- **EUR 1500+** - Full integration projects

Contact: **office@greev.com**

---

## 📁 Files Included

| File | Purpose |
|------|---------|
| `Start.bat` | Batch launcher for double-click execution |
| `Start.ps1` | PowerShell launcher with advanced options |
| `unblock-files_v1.0.0.ps1` | Zone.Identifier unlocker utility |
| `setup.ps1` | Setup/initialization script template |
| `README.md` | This documentation |
| `LICENSE` | AGPLv3 Community License text |
| `MIT-LICENSE` | MIT Developer License text |
| `PROFESSIONAL-SUPPORT.md` | Professional Support Agreement |
| `.gitattributes` | Git configuration (line endings) |

---

## 🔧 Troubleshooting

### "ExecutionPolicy is locked by Group Policy"

Your IT administrator has set system-wide policy. Cannot bypass.

**Solution:** Contact IT and request `RemoteSigned` policy.

### "File cannot be loaded because it is from the Internet"

File has Zone.Identifier mark from being downloaded.

**Solution:** 
```powershell
.\unblock-files_v1.0.0.ps1
# Or use Start.bat which handles this automatically
```

### Script runs but exits with error

Check:
1. Does it require administrator rights? → Run as Administrator
2. Are dependencies installed? → Check documentation
3. Run with `-Verbose` for detailed output

---

## 🔄 Git Integration

### Initial GitHub Upload

```powershell
cd C:\Users\koni\ExecutionPolicy-Foundation\

git add .
git commit -m "feat: GrEEV.com KG ExecutionPolicy Foundation v2.0.0

- Dual licensed (AGPLv3/MIT)
- Professional support option
- Zone.Identifier handling
- GPO detection
- Multi-language (EN/DE)"

git push origin main
```

### View Repository

```powershell
gh repo view --web
```

---

## 💼 Integration Guide

### Step 1: Copy Framework Files

```powershell
Copy-Item -Path "Start.bat", "Start.ps1", "unblock-files_v1.0.0.ps1" `
  -Destination "C:\YourProject\"
```

### Step 2: Create Your Main Script

Create `setup.ps1` in the project folder.

### Step 3: Run with Wrapper

```batch
Start.bat setup.ps1
```

Or:

```powershell
.\Start.ps1 -ScriptName setup.ps1
```

---

## 🌍 Multi-Language Support

All scripts support **English (en)** and **German (de)**:

```powershell
# English (default)
.\Start.ps1 -Language en

# German
.\Start.ps1 -Language de
```

---

## 📊 Version History

**v2.0.0** (2026-01-18)
- Dual Licensed (AGPLv3/MIT)
- Professional Support model
- EN/DE localization
- GrEEV.com branding
- Enhanced error handling

**v1.0.0** (2025)
- Initial release
- Zone.Identifier handling
- ExecutionPolicy bypass

---

## 📞 Contact & Support

**GrEEV.com KG**
- Website: [www.greev.com](https://www.greev.com)
- Email: [office@greev.com](mailto:office@greev.com)
- Support: [support@greev.com](mailto:support@greev.com)
- Location: Graz, Austria

---

## 📄 License Information

### Quick Summary

Choose **one** of these:

1. **AGPLv3** (FREE) - For open source projects
2. **MIT** (FREE) - For commercial/SaaS projects
3. **MIT + Professional Support** (EUR 499/year) - For enterprises

### Full License Texts

- See `LICENSE` for AGPLv3 full text
- See `MIT-LICENSE` for MIT full text
- See `PROFESSIONAL-SUPPORT.md` for support terms

### SPDX Identifier

```
SPDX-License-Identifier: (AGPL-3.0-or-later OR MIT)
```

---

## 🏢 About GrEEV.com KG

GrEEV.com KG specializes in:
- IT Infrastructure Automation
- PowerShell Development
- Open Source Software
- Digital Identity Standards (eIDAS)
- Container Orchestration

**ExecutionPolicy Foundation** is our open-source contribution to the PowerShell community.

---

**Copyright © 2026 GrEEV.com KG. All rights reserved.**

Dual Licensed under AGPLv3 and MIT.


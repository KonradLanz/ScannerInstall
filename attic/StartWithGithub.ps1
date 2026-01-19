# ================================================================
# EXECUTIONPOLICY FOUNDATION - VOLLSTÄNDIGER GITHUB UPLOAD
# ================================================================

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  ExecutionPolicy Foundation - Git Setup & GitHub Upload    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ================================================================
# 1. INSTALLATION
# ================================================================

Write-Host "`n[SCHRITT 1/5] Git installieren..." -ForegroundColor Yellow
winget install Git.Git --accept-package-agreements --accept-source-agreements --quiet 2>$null
Start-Sleep -Seconds 2
git --version

Write-Host "`n[SCHRITT 2/5] GitHub CLI installieren..." -ForegroundColor Yellow
winget install GitHub.cli --accept-package-agreements --accept-source-agreements --quiet 2>$null
Start-Sleep -Seconds 2
gh version

Write-Host "`n[SCHRITT 3/5] Git konfigurieren..." -ForegroundColor Yellow
git config --global user.name "KonradLanz"
git config --global user.email "office@greev.com"
git config --global init.defaultBranch main
Write-Host "✓ Git konfiguriert" -ForegroundColor Green

Write-Host "`n[SCHRITT 4/5] GitHub authentifizieren (Browser wird geöffnet)..." -ForegroundColor Yellow
gh auth login --web 2>$null
Write-Host "✓ GitHub Auth fertig" -ForegroundColor Green

# ================================================================
# 2. DATEIEN KOPIEREN
# ================================================================

Write-Host "`n[SCHRITT 5/5] Dateien vorbereiten..." -ForegroundColor Yellow

$targetDir = "C:\Users\koni\ExecutionPolicy-Foundation"
$sourceDir = "$env:USERPROFILE\Downloads"

cd $targetDir

# Dateien kopieren
@("Start.bat", "Start.ps1", "unblock-files_v1.0.0.ps1", ".gitattributes", "README.md", "setup.ps1") | ForEach-Object {
    if (Test-Path "$sourceDir\$_") {
        Copy-Item -Path "$sourceDir\$_" -Destination $targetDir -Force
        Write-Host "  ✓ $_" -ForegroundColor Green
    }
}

# ================================================================
# 3. GIT COMMIT & PUSH
# ================================================================

Write-Host "`n[GIT] Staging all files..." -ForegroundColor Cyan
git add .

Write-Host "[GIT] Creating commit..." -ForegroundColor Cyan
git commit -m "feat: ExecutionPolicy Foundation v2.0.0

- Parametrized Start.bat and Start.ps1 launchers
- GPO detection with actionable error messages
- Zone.Identifier unblocking for ZIP downloads
- Dual-language support (EN/DE)
- WhatIf dry-run mode" 2>$null

Write-Host "[GIT] Pushing to GitHub..." -ForegroundColor Cyan
gh repo create ExecutionPolicy-Foundation `
    --public `
    --source=. `
    --push `
    --description "Robust PowerShell execution framework with GPO detection" 2>$null

# ================================================================
# 4. FERTIG
# ================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    ✓ FERTIG! ✓                           ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`nGitHub URL:" -ForegroundColor Cyan
gh repo view --json url -q '.url'

Write-Host "`n→ Repository wird im Browser geöffnet..." -ForegroundColor Yellow
gh repo view --web


#!/usr/bin/env powershell
# ============================================================
# EXECUTIONPOLICY FOUNDATION - VOLLSTÄNDIGER GITHUB UPLOAD
# v2.0.0 | GrEEV.com KG | Optimiert für PS 5.1 + 7.5+
# ============================================================

param(
    [string]$GitUsername = "KonradLanz",
    [string]$GitEmail = "office@greev.com",
    [string]$TargetDir = "C:\Users\koni\ExecutionPolicy-Foundation",
    [switch]$SkipInstall = $false,
    [switch]$DryRun = $false
)

# Initialize
$LASTEXITCODE = 0
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  ExecutionPolicy Foundation - Git Setup & GitHub Upload    ║" -ForegroundColor Cyan
Write-Host "║  v2.0.0 | GrEEV.com KG | Support: support@greev.com        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# FUNCTIONS
# ============================================================

function Test-CommandExists {
    param([string]$Command)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

function Invoke-WingetInstall {
    param([string]$PackageId, [string]$PackageName)
    
    Write-Host "  Installing $PackageName..." -ForegroundColor Yellow
    
    # Use -h (silent) instead of --quiet (which doesn't exist)
    & winget install $PackageId `
        --accept-package-agreements `
        --accept-source-agreements `
        -h 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARN Winget installation may have issues, but continuing..." -ForegroundColor Yellow
    }
    
    # Refresh PATH to pickup newly installed tools
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Start-Sleep -Seconds 2
}

# ============================================================
# 1. INSTALLATION
# ============================================================

if (-not $SkipInstall) {
    Write-Host "[SCHRITT 1/5] Abhängigkeiten überprüfen..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check and install Git
    if (-not (Test-CommandExists "git")) {
        Invoke-WingetInstall "Git.Git" "Git"
    } else {
        Write-Host "  OK Git bereits installiert" -ForegroundColor Green
    }
    
    # Verify Git installation
    if (Test-CommandExists "git") {
        $gitVersion = & git --version 2>&1
        Write-Host "  OK $gitVersion" -ForegroundColor Green
    } else {
        Write-Host "  X Git konnte nicht installiert werden!" -ForegroundColor Red
        exit 1
    }
    
    # Check and install GitHub CLI
    Write-Host ""
    if (-not (Test-CommandExists "gh")) {
        Invoke-WingetInstall "GitHub.cli" "GitHub CLI"
    } else {
        Write-Host "  OK GitHub CLI bereits installiert" -ForegroundColor Green
    }
    
    # Verify GitHub CLI installation
    if (Test-CommandExists "gh") {
        $ghVersion = & gh --version 2>&1
        Write-Host "  OK $ghVersion" -ForegroundColor Green
    } else {
        Write-Host "  WARN GitHub CLI konnte nicht installiert werden. Versuche trotzdem weiterzumachen..." -ForegroundColor Yellow
    }
} else {
    Write-Host "[SCHRITT 1/5] Installation übersprungen (--SkipInstall)" -ForegroundColor Yellow
}

# ============================================================
# 2. GIT KONFIGURATION
# ============================================================

Write-Host ""
Write-Host "[SCHRITT 2/5] Git konfigurieren..." -ForegroundColor Yellow

& git config --global user.name $GitUsername
& git config --global user.email $GitEmail
& git config --global init.defaultBranch main

Write-Host "  OK Git User: $GitUsername" -ForegroundColor Green
Write-Host "  OK Git Email: $GitEmail" -ForegroundColor Green
Write-Host "  OK Default Branch: main" -ForegroundColor Green

# ============================================================
# 3. GITHUB AUTHENTICATION
# ============================================================

Write-Host ""
Write-Host "[SCHRITT 3/5] GitHub Authentifizierung..." -ForegroundColor Yellow

if (Test-CommandExists "gh") {
    # Check if already authenticated
    $authStatus = & gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Opening browser for GitHub authentication..." -ForegroundColor Yellow
        & gh auth login --web 2>&1 | Out-Null
        Write-Host "  OK GitHub Auth fertig" -ForegroundColor Green
    } else {
        Write-Host "  OK Bereits authentifiziert" -ForegroundColor Green
    }
} else {
    Write-Host "  WARN GitHub CLI nicht verfügbar - überspringe GitHub Auth" -ForegroundColor Yellow
}

# ============================================================
# 4. ARBEITSVERZEICHNIS VORBEREITEN
# ============================================================

Write-Host ""
Write-Host "[SCHRITT 4/5] Arbeitsverzeichnis vorbereiten..." -ForegroundColor Yellow

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Host "  OK Verzeichnis erstellt: $TargetDir" -ForegroundColor Green
} else {
    Write-Host "  OK Verzeichnis existiert: $TargetDir" -ForegroundColor Green
}

Push-Location $TargetDir

# Initialize git repository if not already initialized
if (-not (Test-Path "$TargetDir\.git")) {
    Write-Host "  Initialisiere Git Repository..." -ForegroundColor Cyan
    & git init | Out-Null
    & git branch -M main | Out-Null
    Write-Host "  OK Git Repository initialisiert" -ForegroundColor Green
} else {
    Write-Host "  OK Git Repository existiert bereits" -ForegroundColor Green
}

# ============================================================
# 5. GIT COMMIT & PUSH
# ============================================================

Write-Host ""
Write-Host "[SCHRITT 5/5] Git Commit und Push..." -ForegroundColor Yellow

# Check if there are changes
$status = & git status --porcelain 2>&1
if ($status) {
    Write-Host "  [GIT] Staging all files..." -ForegroundColor Cyan
    & git add . | Out-Null
    
    $commitMsg = @"
feat: ExecutionPolicy Foundation v2.0.0 - GrEEV.com KG

- Dual-licensed (AGPLv3 / MIT)
- Auto-unblock Zone.Identifier on PS files
- UTF-8 encoding support
- EN/DE localization
- PowerShell 5.1 + 7.5+ compatible
- Smart batch launcher with version detection
- GPO detection with actionable error messages
- Professional support: EUR 499/year

Support: support@greev.com
License: AGPL-3.0-or-later OR MIT
"@
    
    Write-Host "  [GIT] Creating commit..." -ForegroundColor Cyan
    & git commit -m $commitMsg 2>&1 | Out-Null
    
    if (-not $DryRun) {
        Write-Host "  [GIT] Pushing to GitHub..." -ForegroundColor Cyan
        
        if (Test-CommandExists "gh") {
            # Create and push repository
            $repoName = "ExecutionPolicy-Foundation"
            
            # Check if repo already exists
            $existingRepo = & gh repo view $repoName --json name 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  OK Repository existiert bereits, pushe nur..." -ForegroundColor Green
                & git push -u origin main 2>&1 | Out-Null
            } else {
                Write-Host "  Creating new repository on GitHub..." -ForegroundColor Yellow
                & gh repo create $repoName `
                    --public `
                    --source=. `
                    --push `
                    --description "Robust PowerShell execution framework with GPO detection and dual licensing" `
                    2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  OK Repository erstellt und gepusht" -ForegroundColor Green
                } else {
                    Write-Host "  WARN Repository-Erstellung könnte fehlgeschlagen sein" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  X GitHub CLI nicht verfügbar - kann nicht zu GitHub pushen" -ForegroundColor Red
        }
    } else {
        Write-Host "  [DRY-RUN] Push übersprungen" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ℹ Keine Änderungen zum Commit" -ForegroundColor Cyan
}

# ============================================================
# 6. FERTIG
# ============================================================

Pop-Location

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    OK FERTIG! OK                           ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if (Test-CommandExists "gh") {
    Write-Host "GitHub Repository:" -ForegroundColor Cyan
    & gh repo view ExecutionPolicy-Foundation --json url -q '.url' 2>&1
    Write-Host ""
    Write-Host "→ Repository wird im Browser geöffnet..." -ForegroundColor Yellow
    & gh repo view ExecutionPolicy-Foundation --web 2>&1 | Out-Null
} else {
    Write-Host "Repository: https://github.com/$GitUsername/ExecutionPolicy-Foundation" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Support & Lizenz:" -ForegroundColor Gray
Write-Host "  - Professional Support: support@greev.com | EUR 499/year" -ForegroundColor Gray
Write-Host "  - License: AGPL-3.0-or-later OR MIT" -ForegroundColor Gray
Write-Host ""

exit 0

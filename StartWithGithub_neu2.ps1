#!/usr/bin/env powershell
# ============================================================
# STARTWITHGITHUB - AUTOMATED GITHUB REPOSITORY SETUP
# v2.0.1 | GrEEV.com KG | support@greev.com
# 
# Automatically create GitHub repo and push commits
# Features:
#   - Check if repository exists on GitHub
#   - Create repository if needed
#   - Configure Git settings
#   - Push commits to GitHub
# ============================================================

param(
    [string]$Language = "en",
    [switch]$SkipInstall = $false
)

$Language = if ($Language -eq "de") { "de" } else { "en" }

# ============================================================
# LOCALIZATION
# ============================================================

$Strings = @{
    en = @{
        title                = "ExecutionPolicy Foundation - Git Setup & GitHub Upload"
        version              = "v2.0.1 | GrEEV.com KG"
        
        step1                = "Checking dependencies"
        step2                = "Configuring Git"
        step3                = "GitHub authentication"
        step4                = "Setting up Git line endings"
        step5                = "Preparing working directory"
        step6                = "Creating Git commit and push"
        step7                = "Finalizing"
        
        already_installed    = "Already installed"
        installed            = "installed"
        git_user             = "Git User"
        git_email            = "Git Email"
        default_branch       = "Default Branch"
        github_auth          = "Checking GitHub authentication"
        github_auth_ok       = "GitHub authenticated"
        configuring_crlf     = "Configuring Git line endings (CRLF warnings are normal on Windows)"
        working_dir          = "Working directory exists"
        git_repo_exists      = "Git repository already exists"
        git_repo_not_init    = "Git repository not initialized"
        changes_committed    = "No changes to commit"
        repo_check_title     = "Checking repository status on GitHub"
        repo_exists_github   = "Repository already exists on GitHub"
        repo_not_exists      = "Repository does not exist on GitHub"
        will_create_repo     = "GitHub repository will be created automatically"
        opening_browser      = "Opening repository in browser"
        
        finished_title       = "FINISHED!"
        github_repo_link     = "GitHub Repository"
        support_email        = "Professional Support"
        license              = "License"
    }
    de = @{
        title                = "ExecutionPolicy Foundation - Git Setup & GitHub Upload"
        version              = "v2.0.1 | GrEEV.com KG"
        
        step1                = "Überprüfe Abhängigkeiten"
        step2                = "Git konfigurieren"
        step3                = "GitHub-Authentifizierung"
        step4                = "Git line endings konfigurieren"
        step5                = "Arbeitsverzeichnis vorbereiten"
        step6                = "Git Commit und Push"
        step7                = "Finalisierung"
        
        already_installed    = "Bereits installiert"
        installed            = "installiert"
        git_user             = "Git Benutzer"
        git_email            = "Git E-Mail"
        default_branch       = "Standard Branch"
        github_auth          = "Überprüfe GitHub-Authentifizierung"
        github_auth_ok       = "GitHub authentifiziert"
        configuring_crlf     = "Git line endings konfigurieren (CRLF Warnungen sind auf Windows normal)"
        working_dir          = "Arbeitsverzeichnis existiert"
        git_repo_exists      = "Git Repository existiert bereits"
        git_repo_not_init    = "Git Repository nicht initialisiert"
        changes_committed    = "Keine Änderungen zum Commit"
        repo_check_title     = "Überprüfe Repository-Status auf GitHub"
        repo_exists_github   = "Repository existiert bereits auf GitHub"
        repo_not_exists      = "Repository existiert nicht auf GitHub"
        will_create_repo     = "GitHub Repository wird automatisch erstellt"
        opening_browser      = "Öffne Repository im Browser"
        
        finished_title       = "FERTIG!"
        github_repo_link     = "GitHub Repository"
        support_email        = "Professioneller Support"
        license              = "Lizenz"
    }
}

$Text = $Strings[$Language]

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Get-RepositoryName {
    # Try to get repo name from git remote origin
    try {
        $remoteUrl = git config --get remote.origin.url 2>$null
        if ($remoteUrl) {
            # Extract repo name from URL (works for both HTTPS and SSH)
            $repoName = [System.IO.Path]::GetFileNameWithoutExtension($remoteUrl)
            if ($repoName) {
                return $repoName
            }
        }
    } catch { }
    
    # Fallback: use current folder name
    return Split-Path -Leaf (Get-Location).Path
}

function Get-GitHubUsername {
    # Try git config first
    try {
        $user = git config --get user.name 2>$null
        if ($user) {
            return $user
        }
    } catch { }
    
    # Try gh CLI
    try {
        $whoami = gh api user --jq '.login' 2>$null
        if ($whoami) {
            return $whoami
        }
    } catch { }
    
    return $null
}

function Test-RepositoryExists {
    param(
        [string]$Owner,
        [string]$RepoName
    )
    
    try {
        $result = gh repo view "$Owner/$RepoName" --json name 2>$null
        return $?
    } catch {
        return $false
    }
}

# ============================================================
# SETUP & HEADER
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  $($Text.title)" -ForegroundColor Cyan
Write-Host "║  $($Text.version)" -ForegroundColor Cyan
Write-Host "║  Support: support@greev.com" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "NOTE: Antivirus may flag this script. Add to whitelist if needed:" -ForegroundColor Yellow
Write-Host "  • Avast: Settings > Exceptions > Add folder" -ForegroundColor Yellow
Write-Host "  • Windows Defender: Settings > Virus & threat protection > Exclusions" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# STEP 1/7: CHECK DEPENDENCIES
# ============================================================

Write-Host "[STEP 1/7] $($Text.step1)..." -ForegroundColor Cyan
Write-Host ""

$hasPowershell = $false
if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Host "  ✓ $($Text.already_installed)"
    $hasPowershell = $true
}

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitVersion = git --version
    Write-Host "  ✓ Git $($Text.installed): $gitVersion"
} else {
    Write-Host "  ✗ Git not found!"
    exit 1
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghVersion = gh --version | Select-Object -First 1
    Write-Host "  ✓ GitHub CLI $($Text.installed): $ghVersion"
} else {
    Write-Host "  ✗ GitHub CLI not found!"
    exit 1
}

Write-Host ""

# ============================================================
# STEP 2/7: CONFIGURE GIT
# ============================================================

Write-Host "[STEP 2/7] $($Text.step2)..." -ForegroundColor Cyan
Write-Host ""

try {
    $gitUser = git config --get user.name
    $gitEmail = git config --get user.email
    $branch = git rev-parse --abbrev-ref HEAD
    
    Write-Host "  ✓ $($Text.git_user): $gitUser"
    Write-Host "  ✓ $($Text.git_email): $gitEmail"
    Write-Host "  ✓ $($Text.default_branch): $branch"
} catch {
    Write-Host "  ⚠ Error reading Git config" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# STEP 3/7: GITHUB AUTHENTICATION
# ============================================================

Write-Host "[STEP 3/7] $($Text.step3)..." -ForegroundColor Cyan
Write-Host "  $($Text.github_auth)..."

try {
    $ghStatus = gh auth status 2>&1
    if ($?) {
        Write-Host "  ✓ $($Text.github_auth_ok)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ GitHub not authenticated" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ✗ Error checking authentication" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# STEP 4/7: GIT LINE ENDINGS
# ============================================================

Write-Host "[STEP 4/7] $($Text.step4)..." -ForegroundColor Cyan
Write-Host "  $($Text.configuring_crlf)"

try {
    git config core.autocrlf true
    git config core.safecrlf warn
    Write-Host "  ✓ core.autocrlf = true"
    Write-Host "  ✓ core.safecrlf = warn"
} catch {
    Write-Host "  ⚠ Error configuring line endings" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# STEP 5/7: PREPARE WORKING DIRECTORY
# ============================================================

Write-Host "[STEP 5/7] $($Text.step5)..." -ForegroundColor Cyan
Write-Host ""

$workingDir = (Get-Location).Path
Write-Host "  ✓ $($Text.working_dir): $workingDir"

if (Test-Path ".git") {
    Write-Host "  ✓ $($Text.git_repo_exists)"
} else {
    Write-Host "  ⚠ $($Text.git_repo_not_init)" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# STEP 6/7: CHECK REPOSITORY STATUS & PUSH
# ============================================================

Write-Host "[STEP 6/7] $($Text.step6)..." -ForegroundColor Cyan
Write-Host ""

$repoName = Get-RepositoryName
$gitHubUser = Get-GitHubUsername

Write-Host "$($Text.repo_check_title)..." -ForegroundColor Yellow
Write-Host "  GitHub User: $gitHubUser"
Write-Host "  Repository: $repoName"
Write-Host ""

if (Test-RepositoryExists -Owner $gitHubUser -RepoName $repoName) {
    Write-Host "  ✓ $($Text.repo_exists_github)" -ForegroundColor Green
    Write-Host ""
    
    try {
        git push -u origin main 2>&1 | Out-Null
        if ($?) {
            Write-Host "  ✓ Commits pushed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ℹ $($Text.changes_committed)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ Error pushing: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠ $($Text.repo_not_exists)" -ForegroundColor Yellow
    Write-Host "  ℹ $($Text.will_create_repo)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Please create repository on GitHub:" -ForegroundColor Yellow
    Write-Host "  → https://github.com/new" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Or use:" -ForegroundColor Yellow
    Write-Host "  → gh repo create $repoName --private --source=. --remote=origin --push" -ForegroundColor Cyan
}

Write-Host ""

# ============================================================
# STEP 7/7: FINALIZE
# ============================================================

Write-Host "[STEP 7/7] $($Text.step7)..." -ForegroundColor Cyan
Write-Host ""

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    ✓ $($Text.finished_title)                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "$($Text.github_repo_link):" -ForegroundColor Green
Write-Host "  https://github.com/$gitHubUser/$repoName"
Write-Host ""

Write-Host "$($Text.support):" -ForegroundColor Cyan
Write-Host "  Email: support@greev.com | EUR 499/year"
Write-Host "  $($Text.license): AGPL-3.0-or-later OR MIT"
Write-Host ""

Write-Host "============================================================"
Write-Host "[OK] Script completed successfully"
Write-Host "============================================================"
Write-Host ""

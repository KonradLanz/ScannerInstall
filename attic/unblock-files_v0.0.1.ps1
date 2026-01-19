<#
.SYNOPSIS
    Unblock all PowerShell scripts from Zone.Identifier restriction

.DESCRIPTION
    Recursively scans directory and removes Zone.Identifier:3 marks
    that Windows adds to downloaded files (e.g., GitHub ZIP downloads).

.PARAMETER Path
    Root directory to scan (default: script directory)

.PARAMETER Language
    Output language: 'en' or 'de' (default: en)

.PARAMETER Recursive
    Search subdirectories (default: true)

.PARAMETER WhatIf
    Show what would happen without making changes

.EXAMPLE
    .\unblock-files_v1.0.0.ps1
    .\unblock-files_v1.0.0.ps1 -Language de
    .\unblock-files_v1.0.0.ps1 -Path "C:\Projects" -WhatIf
    .\unblock-files_v1.0.0.ps1 --version
    .\unblock-files_v1.0.0.ps1 --help

.NOTES
    Version: 1.0.0
    Date: 2026-01-18
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$Path,

    [Parameter(Position = 1)]
    [ValidateSet('en', 'de')]
    [string]$Language = 'en',

    [switch]$Recursive = $true
)

# ============================================================================
# HANDLE --version, --help, --checksum
# ============================================================================

$script:Config = @{
    Name = 'unblock-files'
    Version = '1.0.0'
    Date = '2026-01-18'
}

# Check for special flags (before param binding)
if ($args -contains '--version') {
    Write-Host "$($script:Config.Name) v$($script:Config.Version) $($script:Config.Date)"
    exit 0
}

if ($args -contains '--help') {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

if ($args -contains '--checksum') {
    $hash = Get-FileHash -Path $MyInvocation.MyCommand.Path -Algorithm SHA256
    Write-Host $hash.Hash
    exit 0
}

# ============================================================================
# CONFIGURATION & STRINGS
# ============================================================================

if (-not $Path) {
    $Path = $PSScriptRoot
    if (-not $Path) { $Path = Get-Location }
}

$script:Strings = @{
    en = @{
        title = "Unblock-Files v{0}"
        scanning = "Scanning for Zone.Identifier marks in: {0}"
        found_count = "Found {0} file(s) with Zone.Identifier:3 (Internet)"
        found_none = "No files with Zone.Identifier found - all clean"
        unblocking = "Unblocking files..."
        unblocked = "Unblocked: {0}"
        unblock_error = "Failed to unblock: {0} - {1}"
        summary = "Summary: {0} scanned, {1} marked, {2} unblocked"
        whatif = "[WhatIf] Would unblock: {0}"
    }
    de = @{
        title = "Unblock-Files v{0}"
        scanning = "Suche Zone.Identifier-Markierungen in: {0}"
        found_count = "{0} Datei(en) mit Zone.Identifier:3 (Internet) gefunden"
        found_none = "Keine Dateien mit Zone.Identifier gefunden - alles sauber"
        unblocking = "Entsperre Dateien..."
        unblocked = "Entsperrt: {0}"
        unblock_error = "Fehler beim Entsperren: {0} - {1}"
        summary = "Zusammenfassung: {0} geprueft, {1} markiert, {2} entsperrt"
        whatif = "[WhatIf] Wuerde entsperren: {0}"
    }
}

$msg = $script:Strings[$Language]

# ============================================================================
# FUNCTIONS
# ============================================================================

function Test-ZoneIdentifier {
    param([string]$FilePath)

    try {
        $streams = Get-Item -Path $FilePath -Stream * -ErrorAction SilentlyContinue
        return ($streams.Stream -contains 'Zone.Identifier')
    }
    catch {
        return $false
    }
}

function Get-ZoneIdentifierValue {
    param([string]$FilePath)

    try {
        $content = Get-Content -Path $FilePath -Stream Zone.Identifier -ErrorAction SilentlyContinue
        $zoneLine = $content | Where-Object { $_ -match '^ZoneId=' }
        if ($zoneLine -match 'ZoneId=(\d+)') {
            return [int]$Matches[1]
        }
    }
    catch {}

    return $null
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host ($msg.title -f $script:Config.Version) -ForegroundColor Cyan
Write-Host ""

# Scan for files
Write-Host ($msg.scanning -f $Path) -ForegroundColor Gray

$searchParams = @{
    Path = $Path
    Filter = "*.ps1"
    ErrorAction = 'SilentlyContinue'
}

if ($Recursive) {
    $searchParams['Recurse'] = $true
}

$allFiles = @(Get-ChildItem @searchParams)
$markedFiles = @($allFiles | Where-Object { Test-ZoneIdentifier $_.FullName })

Write-Host ""

if ($markedFiles.Count -eq 0) {
    Write-Host "[✓] $($msg.found_none)" -ForegroundColor Green
    Write-Host ""
    Write-Host ($msg.summary -f $allFiles.Count, 0, 0) -ForegroundColor Gray
    exit 0
}

Write-Host "[!] $($msg.found_count -f $markedFiles.Count)" -ForegroundColor Yellow
Write-Host ""

# List marked files
foreach ($file in $markedFiles) {
    $relativePath = $file.FullName.Replace($Path, '').TrimStart('\', '/')
    $zoneId = Get-ZoneIdentifierValue $file.FullName
    Write-Host "    • $relativePath (ZoneId=$zoneId)" -ForegroundColor DarkYellow
}

Write-Host ""

# Unblock files
if ($WhatIf) {
    Write-Host "[WhatIf] $($msg.unblocking)" -ForegroundColor Yellow
} else {
    Write-Host $msg.unblocking -ForegroundColor White
}

$unblocked = 0
foreach ($file in $markedFiles) {
    $relativePath = $file.FullName.Replace($Path, '').TrimStart('\', '/')

    if ($WhatIf) {
        Write-Host "    $($msg.whatif -f $relativePath)" -ForegroundColor Yellow
        $unblocked++
    }
    else {
        try {
            Unblock-File -Path $file.FullName -ErrorAction Stop
            Write-Host "    [✓] $($msg.unblocked -f $relativePath)" -ForegroundColor Green
            $unblocked++
        }
        catch {
            Write-Host "    [✗] $($msg.unblock_error -f $relativePath, $_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host ($msg.summary -f $allFiles.Count, $markedFiles.Count, $unblocked) -ForegroundColor Cyan
Write-Host ""

exit 0


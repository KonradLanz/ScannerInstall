# ================================================================
#
#  GrEEV.com KG - ZONE.IDENTIFIER UNLOCKER v1.0.0             
#  www.greev.com | office@greev.com | Dual Licensed (MIT/AGPLv3)
#  
# Copyright (C) 2026 GrEEV.com KG. All rights reserved.
# License: AGPLv3 (OSS) | MIT (Commercial) | See LICENSE files
# SPDX-License-Identifier: (AGPL-3.0-or-later OR MIT)
# ================================================================

<#
.SYNOPSIS
    Removes Zone.Identifier alternate data stream from files

.DESCRIPTION
    When files are downloaded from the internet, Windows adds a Zone.Identifier
    alternate data stream that marks them as unsafe (untrusted). This script
    removes that marker from specified files, allowing them to execute.

.PARAMETER Path
    Path to directory or file. Default: current script directory

.PARAMETER Filter
    File filter pattern. Default: *.ps1

.PARAMETER Recurse
    Search subdirectories recursively

.EXAMPLE
    .\unblock-files_v1.0.0.ps1
    # Unblocks all .ps1 files in current directory

    .\unblock-files_v1.0.0.ps1 -Path "C:\Scripts" -Recurse
    # Unblocks all .ps1 files in C:\Scripts and subdirectories

.NOTES
    This script requires administrative privileges to remove Zone.Identifier
    streams on files in protected directories.
#>

param(
    [string]$Path = (Split-Path -Parent $MyInvocation.MyCommandPath),
    [string]$Filter = "*.ps1",
    [switch]$Recurse = $false,
    [string]$Language = "en"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Localization
$Strings = @{
    en = @{
        title           = "Zone.Identifier Unlocker"
        unblocking_from = "Unblocking Zone.Identifier from downloaded files"
        path_label      = "Path:"
        filter_label    = "Filter:"
        found_count     = "Found {0} file(s):"
        no_files        = "No files found matching filter."
        unblocked_count = "Successfully unblocked: {0} / {1}"
        success         = "✓"
        error           = "✗"
    }
    de = @{
        title           = "Zone.Identifier Entsperrer"
        unblocking_from = "Zone.Identifier wird von heruntergeladenen Dateien entfernt"
        path_label      = "Pfad:"
        filter_label    = "Filter:"
        found_count     = "Gefunden {0} Datei(en):"
        no_files        = "Keine Dateien gefunden, die dem Filter entsprechen."
        unblocked_count = "Erfolgreich entsperrt: {0} / {1}"
        success         = "✓"
        error           = "✗"
    }
}

$Lang = if ($Language -eq "de") { "de" } else { "en" }
$Str = $Strings[$Lang]

Write-Host ""
Write-Host "╔================================================================╗" -ForegroundColor Cyan
Write-Host "║  $($Str.title)                                                 ║" -ForegroundColor Cyan
Write-Host "╚================================================================╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "$($Str.path_label) $Path" -ForegroundColor Yellow
Write-Host "$($Str.filter_label) $Filter" -ForegroundColor Yellow
Write-Host ""

$params = @{
    Path        = $Path
    Filter      = $Filter
    ErrorAction = "SilentlyContinue"
}

if ($Recurse) {
    $params.Recurse = $true
}

$files = @(Get-ChildItem @params)

if ($files.Count -eq 0) {
    Write-Host $Str.no_files -ForegroundColor Yellow
    exit 0
}

Write-Host "$($Str.found_count -f $files.Count)" -ForegroundColor Cyan
Write-Host ""

$unblocked = 0
foreach ($file in $files) {
    try {
        Unblock-File -Path $file.FullName -ErrorAction Stop
        Write-Host "  $($Str.success) $($file.Name)" -ForegroundColor Green
        $unblocked++
    } catch {
        Write-Host "  $($Str.error) $($file.Name): $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "$($Str.unblocked_count -f $unblocked, $files.Count)" -ForegroundColor Green
Write-Host ""


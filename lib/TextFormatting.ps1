# PowerShell Text Formatting Module
# Part of ExecutionPolicy-Foundation
# SPDX-License-Identifier: AGPL-3.0-or-later OR MIT
# (C) 2026 GrEEV.com KG

<#
.SYNOPSIS
    Standardized text formatting and UI helpers for ExecutionPolicy-Foundation
    
.DESCRIPTION
    Provides consistent box drawing, text alignment, and line wrapping.
    Handles console width constraints properly.
    
.EXAMPLE
    . ".\lib\TextFormatting.ps1"
    Show-Banner "MyApp v1.0"
    Show-Section "PREFLIGHT CHECKS"
    Write-FormattedError "Something went wrong"
#>

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║ CONFIGURATION                                                              ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# Maximum console width (avoid text wrapping on narrow terminals)
[int]$CONSOLE_MAX_WIDTH = 80

# Box drawing characters (Box-drawing art)
[string]$BOX_TOP_LEFT = "╔"
[string]$BOX_TOP_RIGHT = "╗"
[string]$BOX_BOTTOM_LEFT = "╚"
[string]$BOX_BOTTOM_RIGHT = "╝"
[string]$BOX_HORIZONTAL = "═"
[string]$BOX_VERTICAL = "║"
[string]$BOX_CROSS = "╬"

# Unicode symbols
[string]$SYMBOL_CHECK = "✓"
[string]$SYMBOL_CROSS = "✗"
[string]$SYMBOL_WARNING = "⚠"
[string]$SYMBOL_INFO = "ℹ"
[string]$SYMBOL_SUCCESS = "✓"
[string]$SYMBOL_ERROR = "✗"

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║ HELPER FUNCTIONS                                                           ║
# ╚════════════════════════════════════════════════════════════════════════════╝

function Get-ConsoleWidth {
    <#
    .SYNOPSIS
        Gets current console width, with fallback for constrained terminals
    #>
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -lt 40) { return 80 }
        if ($width -gt $CONSOLE_MAX_WIDTH) { return $CONSOLE_MAX_WIDTH }
        return $width
    }
    catch {
        return $CONSOLE_MAX_WIDTH
    }
}

function Truncate-Text {
    <#
    .SYNOPSIS
        Truncates text to fit console width, adding … if needed
    #>
    param(
        [string]$Text,
        [int]$MaxWidth = (Get-ConsoleWidth)
    )
    
    if ($Text.Length -le $MaxWidth) {
        return $Text
    }
    return $Text.Substring(0, $MaxWidth - 1) + "…"
}

function Pad-Text {
    <#
    .SYNOPSIS
        Pads text to exact width (left/center/right alignment)
    #>
    param(
        [string]$Text,
        [int]$Width,
        [ValidateSet("Left", "Center", "Right")]
        [string]$Align = "Left"
    )
    
    if ($Text.Length -ge $Width) {
        return Truncate-Text $Text $Width
    }
    
    switch ($Align) {
        "Left" {
            return $Text.PadRight($Width)
        }
        "Center" {
            $leftPad = [Math]::Floor(($Width - $Text.Length) / 2)
            $rightPad = $Width - $Text.Length - $leftPad
            return (" " * $leftPad) + $Text + (" " * $rightPad)
        }
        "Right" {
            return $Text.PadLeft($Width)
        }
    }
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║ BOX DRAWING FUNCTIONS                                                      ║
# ╚════════════════════════════════════════════════════════════════════════════╝

function Show-BoxLine {
    <#
    .SYNOPSIS
        Draws a single box line (used internally)
    #>
    param(
        [string]$Type = "middle",  # "top", "middle", "bottom"
        [string]$Content = "",
        [int]$Width = (Get-ConsoleWidth)
    )
    
    $innerWidth = $Width - 4  # Account for borders and spaces
    
    switch ($Type) {
        "top" {
            return "$BOX_TOP_LEFT$($BOX_HORIZONTAL * $Width)$BOX_TOP_RIGHT"
        }
        "bottom" {
            return "$BOX_BOTTOM_LEFT$($BOX_HORIZONTAL * $Width)$BOX_BOTTOM_RIGHT"
        }
        "middle" {
            if ([string]::IsNullOrWhiteSpace($Content)) {
                return "$BOX_VERTICAL$(' ' * ($Width + 2))$BOX_VERTICAL"
            }
            
            $content = Pad-Text $Content ($innerWidth) "Left"
            return "$BOX_VERTICAL $content $BOX_VERTICAL"
        }
    }
}

function Show-Banner {
    <#
    .SYNOPSIS
        Displays a centered banner with box border
        
    .PARAMETER Title
        Main title text
        
    .PARAMETER Subtitle
        Optional subtitle text
        
    .PARAMETER Width
        Box width (defaults to console width)
    #>
    param(
        [string]$Title,
        [string]$Subtitle = "",
        [int]$Width = (Get-ConsoleWidth)
    )
    
    $bannerWidth = $Width - 4
    
    Write-Host
    Write-Host (Show-BoxLine -Type "top" -Width $bannerWidth)
    Write-Host (Show-BoxLine -Type "middle" -Content (Pad-Text $Title $bannerWidth "Center") -Width $bannerWidth)
    
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
        Write-Host (Show-BoxLine -Type "middle" -Content (Pad-Text $Subtitle $bannerWidth "Center") -Width $bannerWidth)
    }
    
    Write-Host (Show-BoxLine -Type "bottom" -Width $bannerWidth)
    Write-Host
}

function Show-Section {
    <#
    .SYNOPSIS
        Displays a section header with box border
        
    .PARAMETER Title
        Section title
        
    .PARAMETER Width
        Box width (defaults to console width)
    #>
    param(
        [string]$Title,
        [int]$Width = (Get-ConsoleWidth)
    )
    
    $sectionWidth = $Width - 4
    
    Write-Host
    Write-Host (Show-BoxLine -Type "top" -Width $sectionWidth)
    Write-Host (Show-BoxLine -Type "middle" -Content (Pad-Text $Title $sectionWidth "Left") -Width $sectionWidth)
    Write-Host (Show-BoxLine -Type "bottom" -Width $sectionWidth)
    Write-Host
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║ COLORED OUTPUT FUNCTIONS                                                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝

function Write-FormattedSuccess {
    <#
    .SYNOPSIS
        Writes formatted success message
    #>
    param(
        [string]$Message,
        [string]$Details = ""
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp] [$($SYMBOL_SUCCESS.PadRight(1))] [SUCCESS]"
    
    Write-Host $prefix -ForegroundColor Green -NoNewline
    Write-Host " $(Truncate-Text $Message)" -ForegroundColor White
    
    if ($Details) {
        Write-Host $Details -ForegroundColor Gray
    }
}

function Write-FormattedInfo {
    <#
    .SYNOPSIS
        Writes formatted info message
    #>
    param(
        [string]$Message,
        [string]$Details = ""
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp] [$($SYMBOL_INFO.PadRight(1))] [INFO]"
    
    Write-Host $prefix -ForegroundColor Cyan -NoNewline
    Write-Host " $(Truncate-Text $Message)" -ForegroundColor White
    
    if ($Details) {
        Write-Host $Details -ForegroundColor Gray
    }
}

function Write-FormattedWarning {
    <#
    .SYNOPSIS
        Writes formatted warning message
    #>
    param(
        [string]$Message,
        [string]$Details = ""
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp] [$($SYMBOL_WARNING.PadRight(1))] [WARNING]"
    
    Write-Host $prefix -ForegroundColor Yellow -NoNewline
    Write-Host " $(Truncate-Text $Message)" -ForegroundColor White
    
    if ($Details) {
        Write-Host $Details -ForegroundColor Gray
    }
}

function Write-FormattedError {
    <#
    .SYNOPSIS
        Writes formatted error message
    #>
    param(
        [string]$Message,
        [string]$Details = ""
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp] [$($SYMBOL_ERROR.PadRight(1))] [ERROR]"
    
    Write-Host $prefix -ForegroundColor Red -NoNewline
    Write-Host " $(Truncate-Text $Message)" -ForegroundColor White
    
    if ($Details) {
        Write-Host $Details -ForegroundColor Gray
    }
}

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║ SUMMARY/FOOTER FUNCTIONS                                                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝

function Show-Summary {
    <#
    .SYNOPSIS
        Displays a summary status block
    #>
    param(
        [hashtable]$Items,  # @{"WSL2" = "✓"; "Git" = "✗"}
        [int]$Width = (Get-ConsoleWidth)
    )
    
    Show-Section "SUMMARY" -Width $Width
    
    foreach ($item in $Items.GetEnumerator()) {
        $status = $item.Value
        $name = $item.Key
        Write-Host "  $name : $status"
    }
    
    Write-Host
}

function Show-Footer {
    <#
    .SYNOPSIS
        Displays footer with contact/support info (respects console width)
    #>
    param(
        [string]$Email = "office@greev.com",
        [string]$Website = "https://github.com/KonradLanz/ScannerInstall/issues",
        [int]$Width = (Get-ConsoleWidth)
    )
    
    Write-Host "============================================================"
    Write-Host "Issues? Visit: $Website"
    Write-Host "Support: $Email"
    Write-Host "============================================================"
}

# Export functions
Export-ModuleMember -Function @(
    'Get-ConsoleWidth',
    'Truncate-Text',
    'Pad-Text',
    'Show-BoxLine',
    'Show-Banner',
    'Show-Section',
    'Write-FormattedSuccess',
    'Write-FormattedInfo',
    'Write-FormattedWarning',
    'Write-FormattedError',
    'Show-Summary',
    'Show-Footer'
) -Variable @(
    'CONSOLE_MAX_WIDTH',
    'SYMBOL_CHECK',
    'SYMBOL_CROSS',
    'SYMBOL_WARNING',
    'SYMBOL_INFO',
    'SYMBOL_SUCCESS',
    'SYMBOL_ERROR'
)

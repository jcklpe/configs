[CmdletBinding()]
param(
    [string]$ConfigsRoot,
    [switch]$ReplaceExisting
)

$ErrorActionPreference = 'Stop'
if (-not $ConfigsRoot) { $ConfigsRoot = Split-Path -Parent $PSScriptRoot }
$ConfigsRoot = (Resolve-Path -LiteralPath $ConfigsRoot).Path
$sourceConfig = Join-Path $ConfigsRoot 'tabby\config.windows.yaml'
$tabbyDirectory = Join-Path $env:APPDATA 'tabby'
$liveConfig = Join-Path $tabbyDirectory 'config.yaml'
if (-not (Test-Path -LiteralPath $sourceConfig -PathType Leaf)) {
    throw "Missing Windows Tabby config: $sourceConfig"
}
New-Item -ItemType Directory -Path $tabbyDirectory -Force | Out-Null
$existingConfig = Get-Item -LiteralPath $liveConfig -ErrorAction SilentlyContinue
$alreadyLinked = $existingConfig -and $existingConfig.LinkType -eq 'SymbolicLink' -and $existingConfig.Target -eq $sourceConfig
if (-not $alreadyLinked) {
    if (Get-Process -Name Tabby -ErrorAction SilentlyContinue) {
        throw 'Close Tabby before linking its config so it cannot save the old settings over the new ones.'
    }
    if ($existingConfig -and -not $ReplaceExisting) {
        throw 'An existing Tabby config was found. Review it, then rerun with -ReplaceExisting to back it up before linking.'
    }
    $backupConfig = $null
    if ($existingConfig) {
        if ($existingConfig.PSIsContainer) { throw "Expected a config file: $liveConfig" }
        $backupConfig = Join-Path $tabbyDirectory ('config.before-configs-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.yaml')
        Copy-Item -LiteralPath $liveConfig -Destination $backupConfig
        Remove-Item -LiteralPath $liveConfig
        Write-Output "Previous config backed up to $backupConfig"
    }
    try {
        New-Item -ItemType SymbolicLink -Path $liveConfig -Target $sourceConfig | Out-Null
    } catch {
        if ($backupConfig) { Copy-Item -LiteralPath $backupConfig -Destination $liveConfig }
        throw
    }
}
Write-Output "Tabby config linked to $sourceConfig"

# Register the repo's terminal fonts for the current Windows user.
$userFontsDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontRegistry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -ItemType Directory -Path $userFontsDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $fontRegistry)) { New-Item -Path $fontRegistry | Out-Null }
if (-not ('ConfigsTabbyFonts' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ConfigsTabbyFonts {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern int AddFontResourceEx(string path, uint flags, IntPtr reserved);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool SendNotifyMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
}
"@
}
foreach ($font in @(
    @{ File = 'FiraCodeNerdFontMono-Regular.ttf'; Name = 'FiraCode Nerd Font Mono Regular (TrueType)' },
    @{ File = 'FiraCodeNerdFontMono-Bold.ttf'; Name = 'FiraCode Nerd Font Mono Bold (TrueType)' }
)) {
    $fontSource = Join-Path (Join-Path $ConfigsRoot 'fonts') $font.File
    $fontDestination = Join-Path $userFontsDirectory $font.File
    if (-not (Test-Path -LiteralPath $fontDestination) -or (Get-FileHash -LiteralPath $fontSource).Hash -ne (Get-FileHash -LiteralPath $fontDestination).Hash) {
        Copy-Item -LiteralPath $fontSource -Destination $fontDestination -Force
    }
    New-ItemProperty -Path $fontRegistry -Name $font.Name -Value $fontDestination -PropertyType String -Force | Out-Null
    [ConfigsTabbyFonts]::AddFontResourceEx($fontDestination, 0, [IntPtr]::Zero) | Out-Null
}
[ConfigsTabbyFonts]::SendNotifyMessage([IntPtr]0xffff, 0x001d, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
Write-Output 'FiraCode Nerd Font Mono installed. Open Tabby to use the theme and default WSL profile.'

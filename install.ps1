<#
.SYNOPSIS
    One-liner installer for Claude Code Account Switcher (Windows)
.DESCRIPTION
    Usage: iwr -useb https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$RepoUrl = "https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main"
$InstallDir = if ($env:CCSWITCH_INSTALL_DIR) { $env:CCSWITCH_INSTALL_DIR } else { Join-Path $env:USERPROFILE ".local\bin" }
$ScriptName = "ccswitch.ps1"

Write-Host "Claude Code Account Switcher - Installer"
Write-Host "========================================="
Write-Host ""

# Create install directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Download script
Write-Host "Downloading ccswitch.ps1..."
$scriptPath = Join-Path $InstallDir $ScriptName
Invoke-WebRequest -Uri "$RepoUrl/ccswitch.ps1" -OutFile $scriptPath -UseBasicParsing

Write-Host ""
Write-Host "Installed to: $scriptPath"
Write-Host ""

# Create a .cmd wrapper for easier execution
$cmdWrapper = Join-Path $InstallDir "ccswitch.cmd"
$cmdContent = @"
@echo off
powershell.exe -ExecutionPolicy Bypass -File "$scriptPath" %*
"@
Set-Content -Path $cmdWrapper -Value $cmdContent -Encoding ASCII

Write-Host "Created wrapper: $cmdWrapper"
Write-Host ""

# Check if install dir is in PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$InstallDir*") {
    Write-Host "Add to PATH by running (as Administrator for system-wide, or without for current user):"
    Write-Host ""
    Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$InstallDir', 'User')"
    Write-Host ""
    Write-Host "Or add manually via: System Properties > Environment Variables > PATH"
    Write-Host ""
}

Write-Host "Usage:"
Write-Host "  ccswitch --help"
Write-Host "  ccswitch --add-account"
Write-Host "  ccswitch --list"
Write-Host "  ccswitch --switch"
Write-Host ""
Write-Host "Installation complete!"

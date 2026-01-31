<#
.SYNOPSIS
    Multi-Account Switcher for Claude Code (Windows PowerShell)
.DESCRIPTION
    Simple tool to manage and switch between multiple Claude Code accounts on Windows.
.NOTES
    Requires PowerShell 5.1+ or PowerShell 7+
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [Parameter(Position = 0)]
    [string]$Command,
    [Parameter(Position = 1, ValueFromRemainingArguments)]
    [string[]]$Arguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$script:BACKUP_DIR = Join-Path $env:USERPROFILE ".claude-switch-backup"
$script:SEQUENCE_FILE = Join-Path $script:BACKUP_DIR "sequence.json"
$script:ALIAS_DIR = if ($env:CCSWITCH_ALIAS_DIR) { $env:CCSWITCH_ALIAS_DIR } else { Join-Path $script:BACKUP_DIR "aliases" }

# Get Claude configuration file path with fallback
function Get-ClaudeConfigPath {
    $primaryConfig = Join-Path $env:USERPROFILE ".claude\.claude.json"
    $fallbackConfig = Join-Path $env:USERPROFILE ".claude.json"
    
    if (Test-Path $primaryConfig) {
        try {
            $content = Get-Content $primaryConfig -Raw | ConvertFrom-Json
            if ($content.oauthAccount) {
                return $primaryConfig
            }
        } catch {}
    }
    
    return $fallbackConfig
}

# Validate JSON file
function Test-JsonFile {
    param([string]$Path)
    try {
        Get-Content $Path -Raw | ConvertFrom-Json | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Validate email format
function Test-Email {
    param([string]$Email)
    return $Email -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
}

# Validate alias format
function Test-Alias {
    param([string]$AliasName)
    return $AliasName -match '^[a-zA-Z][a-zA-Z0-9_-]*$'
}

# Safe JSON write with validation
function Write-JsonSafe {
    param(
        [string]$Path,
        [object]$Content
    )
    
    $tempFile = "$Path.$([guid]::NewGuid().ToString('N').Substring(0,8)).tmp"
    try {
        $json = $Content | ConvertTo-Json -Depth 10
        Set-Content -Path $tempFile -Value $json -Encoding UTF8
        
        # Validate
        Get-Content $tempFile -Raw | ConvertFrom-Json | Out-Null
        
        Move-Item -Path $tempFile -Destination $Path -Force
    } catch {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        throw "Error: Generated invalid JSON - $_"
    }
}

# Setup directories
function Initialize-Directories {
    @($script:BACKUP_DIR, (Join-Path $script:BACKUP_DIR "configs"), (Join-Path $script:BACKUP_DIR "credentials"), $script:ALIAS_DIR) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
}

# Initialize sequence.json
function Initialize-SequenceFile {
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        $initContent = @{
            activeAccountNumber = $null
            lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            sequence = @()
            accounts = @{}
        }
        Write-JsonSafe -Path $script:SEQUENCE_FILE -Content $initContent
    }
}

# Check if Claude Code is running
function Test-ClaudeRunning {
    $processes = Get-Process -Name "claude" -ErrorAction SilentlyContinue
    return $null -ne $processes
}

# Wait for Claude to close
function Wait-ClaudeClose {
    if ($script:Force) {
        Write-Host "Skipping Claude Code process check (--Force enabled)"
        return
    }
    
    if (-not (Test-ClaudeRunning)) {
        return
    }
    
    Write-Host "Claude Code is running. Please close it first."
    Write-Host "Waiting for Claude Code to close..."
    Write-Host "(Or use -Force to skip this check)"
    
    while (Test-ClaudeRunning) {
        Start-Sleep -Seconds 1
    }
    
    Write-Host "Claude Code closed. Continuing..."
}

# Get current account email
function Get-CurrentAccount {
    $configPath = Get-ClaudeConfigPath
    if (-not (Test-Path $configPath)) {
        return "none"
    }
    
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($config.oauthAccount -and $config.oauthAccount.emailAddress) {
            return $config.oauthAccount.emailAddress
        }
    } catch {}
    
    return "none"
}

# Read credentials
function Read-Credentials {
    $credFile = Join-Path $env:USERPROFILE ".claude\.credentials.json"
    if (Test-Path $credFile) {
        return Get-Content $credFile -Raw
    }
    return ""
}

# Write credentials
function Write-Credentials {
    param([string]$Credentials)
    
    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
    
    $credFile = Join-Path $claudeDir ".credentials.json"
    Set-Content -Path $credFile -Value $Credentials -Encoding UTF8
}

# Read account credentials from backup
function Read-AccountCredentials {
    param([string]$AccountNum, [string]$Email)
    
    $credFile = Join-Path $script:BACKUP_DIR "credentials\.claude-credentials-$AccountNum-$Email.json"
    if (Test-Path $credFile) {
        return Get-Content $credFile -Raw
    }
    return ""
}

# Write account credentials to backup
function Write-AccountCredentials {
    param([string]$AccountNum, [string]$Email, [string]$Credentials)
    
    $credFile = Join-Path $script:BACKUP_DIR "credentials\.claude-credentials-$AccountNum-$Email.json"
    Set-Content -Path $credFile -Value $Credentials -Encoding UTF8
}

# Read account config from backup
function Read-AccountConfig {
    param([string]$AccountNum, [string]$Email)
    
    $configFile = Join-Path $script:BACKUP_DIR "configs\.claude-config-$AccountNum-$Email.json"
    if (Test-Path $configFile) {
        return Get-Content $configFile -Raw
    }
    return ""
}

# Write account config to backup
function Write-AccountConfig {
    param([string]$AccountNum, [string]$Email, [string]$Config)
    
    $configFile = Join-Path $script:BACKUP_DIR "configs\.claude-config-$AccountNum-$Email.json"
    Set-Content -Path $configFile -Value $Config -Encoding UTF8
}

# Resolve account identifier (number, email, or alias)
function Resolve-AccountIdentifier {
    param([string]$Identifier)
    
    if ($Identifier -match '^\d+$') {
        return $Identifier
    }
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        return $null
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    
    # Try email
    foreach ($key in $sequence.accounts.PSObject.Properties.Name) {
        if ($sequence.accounts.$key.email -eq $Identifier) {
            return $key
        }
    }
    
    # Try alias
    foreach ($key in $sequence.accounts.PSObject.Properties.Name) {
        if ($sequence.accounts.$key.alias -eq $Identifier) {
            return $key
        }
    }
    
    return $null
}

# Check if account exists by email
function Test-AccountExists {
    param([string]$Email)
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        return $false
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    foreach ($key in $sequence.accounts.PSObject.Properties.Name) {
        if ($sequence.accounts.$key.email -eq $Email) {
            return $true
        }
    }
    return $false
}

# Check if alias exists
function Test-AliasExists {
    param([string]$AliasName, [string]$ExcludeAccount = "")
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        return $false
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    foreach ($key in $sequence.accounts.PSObject.Properties.Name) {
        if ($sequence.accounts.$key.alias -eq $AliasName -and $key -ne $ExcludeAccount) {
            return $true
        }
    }
    return $false
}

# Get next account number
function Get-NextAccountNumber {
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        return 1
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    $maxNum = 0
    foreach ($key in $sequence.accounts.PSObject.Properties.Name) {
        $num = [int]$key
        if ($num -gt $maxNum) { $maxNum = $num }
    }
    return $maxNum + 1
}

# Add account command
function Invoke-AddAccount {
    Initialize-Directories
    Initialize-SequenceFile
    
    $currentEmail = Get-CurrentAccount
    
    if ($currentEmail -eq "none") {
        Write-Host "Error: No active Claude account found. Please log in first."
        exit 1
    }
    
    if (Test-AccountExists -Email $currentEmail) {
        Write-Host "Account $currentEmail is already managed."
        exit 0
    }
    
    $accountNum = Get-NextAccountNumber
    
    # Backup current credentials and config
    $currentCreds = Read-Credentials
    $configPath = Get-ClaudeConfigPath
    $currentConfig = Get-Content $configPath -Raw
    
    if ([string]::IsNullOrEmpty($currentCreds)) {
        Write-Host "Error: No credentials found for current account"
        exit 1
    }
    
    # Get account UUID
    $configObj = $currentConfig | ConvertFrom-Json
    $accountUuid = $configObj.oauthAccount.accountUuid
    
    # Store backups
    Write-AccountCredentials -AccountNum $accountNum -Email $currentEmail -Credentials $currentCreds
    Write-AccountConfig -AccountNum $accountNum -Email $currentEmail -Config $currentConfig
    
    # Update sequence.json
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    $sequence.accounts | Add-Member -NotePropertyName $accountNum -NotePropertyValue @{
        email = $currentEmail
        uuid = $accountUuid
        added = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    } -Force
    $sequence.sequence += [int]$accountNum
    $sequence.activeAccountNumber = [int]$accountNum
    $sequence.lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-JsonSafe -Path $script:SEQUENCE_FILE -Content $sequence
    
    Write-Host "Added Account $accountNum`: $currentEmail"
}

# Remove account command
function Invoke-RemoveAccount {
    param([string]$Identifier)
    
    if ([string]::IsNullOrEmpty($Identifier)) {
        Write-Host "Usage: ccswitch.ps1 --remove-account <account_number|email|alias>"
        exit 1
    }
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        Write-Host "Error: No accounts are managed yet"
        exit 1
    }
    
    $accountNum = Resolve-AccountIdentifier -Identifier $Identifier
    if ([string]::IsNullOrEmpty($accountNum)) {
        Write-Host "Error: No account found: $Identifier"
        exit 1
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    
    if (-not $sequence.accounts.PSObject.Properties.Name -contains $accountNum) {
        Write-Host "Error: Account-$accountNum does not exist"
        exit 1
    }
    
    $email = $sequence.accounts.$accountNum.email
    $accountAlias = $sequence.accounts.$accountNum.alias
    
    if ($sequence.activeAccountNumber -eq [int]$accountNum) {
        Write-Host "Warning: Account-$accountNum ($email) is currently active"
    }
    
    $confirm = Read-Host "Are you sure you want to permanently remove Account-$accountNum ($email)? [y/N]"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled"
        exit 0
    }
    
    # Remove alias shortcut if exists
    if ($accountAlias) {
        $shortcutFile = Join-Path $script:ALIAS_DIR "$accountAlias.cmd"
        if (Test-Path $shortcutFile) {
            Remove-Item $shortcutFile -Force
            Write-Host "Removed shortcut: $accountAlias"
        }
    }
    
    # Remove backup files
    $credFile = Join-Path $script:BACKUP_DIR "credentials\.claude-credentials-$accountNum-$email.json"
    $configFile = Join-Path $script:BACKUP_DIR "configs\.claude-config-$accountNum-$email.json"
    if (Test-Path $credFile) { Remove-Item $credFile -Force }
    if (Test-Path $configFile) { Remove-Item $configFile -Force }
    
    # Update sequence.json
    $sequence.accounts.PSObject.Properties.Remove($accountNum)
    $sequence.sequence = @($sequence.sequence | Where-Object { $_ -ne [int]$accountNum })
    $sequence.lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-JsonSafe -Path $script:SEQUENCE_FILE -Content $sequence
    
    Write-Host "Account-$accountNum ($email) has been removed"
}

# List accounts command
function Invoke-List {
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        Write-Host "No accounts are managed yet."
        $response = Read-Host "No managed accounts found. Add current account to managed list? [Y/n]"
        if ($response -ne "n" -and $response -ne "N") {
            Invoke-AddAccount
        }
        exit 0
    }
    
    $currentEmail = Get-CurrentAccount
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    
    # Find active account number
    $activeAccountNum = ""
    if ($currentEmail -ne "none") {
        foreach ($key in $sequence.accounts.PSObject.Properties.Name) {
            if ($sequence.accounts.$key.email -eq $currentEmail) {
                $activeAccountNum = $key
                break
            }
        }
    }
    
    Write-Host "Accounts:"
    foreach ($num in $sequence.sequence) {
        $account = $sequence.accounts."$num"
        $aliasStr = if ($account.alias) { " [$($account.alias)]" } else { "" }
        $activeStr = if ("$num" -eq $activeAccountNum) { " (active)" } else { "" }
        Write-Host "  $num`: $($account.email)$aliasStr$activeStr"
    }
}

# Perform switch
function Invoke-PerformSwitch {
    param([string]$TargetAccount)
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    $currentAccount = $sequence.activeAccountNumber
    $targetEmail = $sequence.accounts.$TargetAccount.email
    $currentEmail = Get-CurrentAccount
    
    # Backup current account
    $currentCreds = Read-Credentials
    $configPath = Get-ClaudeConfigPath
    $currentConfig = Get-Content $configPath -Raw
    
    Write-AccountCredentials -AccountNum $currentAccount -Email $currentEmail -Credentials $currentCreds
    Write-AccountConfig -AccountNum $currentAccount -Email $currentEmail -Config $currentConfig
    
    # Retrieve target account
    $targetCreds = Read-AccountCredentials -AccountNum $TargetAccount -Email $targetEmail
    $targetConfig = Read-AccountConfig -AccountNum $TargetAccount -Email $targetEmail
    
    if ([string]::IsNullOrEmpty($targetCreds) -or [string]::IsNullOrEmpty($targetConfig)) {
        Write-Host "Error: Missing backup data for Account-$TargetAccount"
        exit 1
    }
    
    # Activate target account
    Write-Credentials -Credentials $targetCreds
    
    # Merge oauthAccount
    $targetConfigObj = $targetConfig | ConvertFrom-Json
    $currentConfigObj = $currentConfig | ConvertFrom-Json
    $currentConfigObj.oauthAccount = $targetConfigObj.oauthAccount
    
    Write-JsonSafe -Path $configPath -Content $currentConfigObj
    
    # Update state
    $sequence.activeAccountNumber = [int]$TargetAccount
    $sequence.lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-JsonSafe -Path $script:SEQUENCE_FILE -Content $sequence
    
    Write-Host "Switched to Account-$TargetAccount ($targetEmail)"
    Invoke-List
    Write-Host ""
    Write-Host "Please restart Claude Code to use the new authentication."
    Write-Host ""
}

# Switch to next account
function Invoke-Switch {
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        Write-Host "Error: No accounts are managed yet"
        exit 1
    }
    
    $currentEmail = Get-CurrentAccount
    if ($currentEmail -eq "none") {
        Write-Host "Error: No active Claude account found"
        exit 1
    }
    
    # Check if current account is managed
    if (-not (Test-AccountExists -Email $currentEmail)) {
        Write-Host "Notice: Active account '$currentEmail' was not managed."
        Invoke-AddAccount
        $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
        $accountNum = $sequence.activeAccountNumber
        Write-Host "It has been automatically added as Account-$accountNum."
        Write-Host "Please run 'ccswitch.ps1 --switch' again to switch to the next account."
        exit 0
    }
    
    Wait-ClaudeClose
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    $activeAccount = $sequence.activeAccountNumber
    $sequenceArr = @($sequence.sequence)
    
    # Find next account
    $currentIndex = 0
    for ($i = 0; $i -lt $sequenceArr.Count; $i++) {
        if ($sequenceArr[$i] -eq $activeAccount) {
            $currentIndex = $i
            break
        }
    }
    
    $nextIndex = ($currentIndex + 1) % $sequenceArr.Count
    $nextAccount = $sequenceArr[$nextIndex]
    
    Invoke-PerformSwitch -TargetAccount $nextAccount
}

# Switch to specific account
function Invoke-SwitchTo {
    param([string]$Identifier)
    
    if ([string]::IsNullOrEmpty($Identifier)) {
        Write-Host "Usage: ccswitch.ps1 --switch-to <account_number|email|alias>"
        exit 1
    }
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        Write-Host "Error: No accounts are managed yet"
        exit 1
    }
    
    $targetAccount = Resolve-AccountIdentifier -Identifier $Identifier
    if ([string]::IsNullOrEmpty($targetAccount)) {
        Write-Host "Error: No account found: $Identifier"
        exit 1
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    if (-not $sequence.accounts.PSObject.Properties.Name -contains $targetAccount) {
        Write-Host "Error: Account-$targetAccount does not exist"
        exit 1
    }
    
    Wait-ClaudeClose
    Invoke-PerformSwitch -TargetAccount $targetAccount
}

# Set alias command
function Invoke-SetAlias {
    param([string]$Identifier, [string]$AliasName)
    
    if ([string]::IsNullOrEmpty($Identifier) -or [string]::IsNullOrEmpty($AliasName)) {
        Write-Host "Usage: ccswitch.ps1 --set-alias <account_number|email> <alias_name>"
        exit 1
    }
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        Write-Host "Error: No accounts are managed yet"
        exit 1
    }
    
    if (-not (Test-Alias -AliasName $AliasName)) {
        Write-Host "Error: Invalid alias format. Use alphanumeric, dash, underscore. Must start with letter."
        exit 1
    }
    
    $accountNum = Resolve-AccountIdentifier -Identifier $Identifier
    if ([string]::IsNullOrEmpty($accountNum)) {
        Write-Host "Error: Account not found: $Identifier"
        exit 1
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    
    if (-not $sequence.accounts.PSObject.Properties.Name -contains $accountNum) {
        Write-Host "Error: Account-$accountNum does not exist"
        exit 1
    }
    
    if (Test-AliasExists -AliasName $AliasName -ExcludeAccount $accountNum) {
        Write-Host "Error: Alias '$AliasName' is already used by another account"
        exit 1
    }
    
    $email = $sequence.accounts.$accountNum.email
    $sequence.accounts.$accountNum | Add-Member -NotePropertyName "alias" -NotePropertyValue $AliasName -Force
    $sequence.lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-JsonSafe -Path $script:SEQUENCE_FILE -Content $sequence
    
    Write-Host "Set alias '$AliasName' for Account-$accountNum ($email)"
}

# Clear alias command
function Invoke-ClearAlias {
    param([string]$Identifier)
    
    if ([string]::IsNullOrEmpty($Identifier)) {
        Write-Host "Usage: ccswitch.ps1 --clear-alias <account_number|email|alias>"
        exit 1
    }
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        Write-Host "Error: No accounts are managed yet"
        exit 1
    }
    
    $accountNum = Resolve-AccountIdentifier -Identifier $Identifier
    if ([string]::IsNullOrEmpty($accountNum)) {
        Write-Host "Error: Account not found: $Identifier"
        exit 1
    }
    
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    
    if (-not $sequence.accounts.PSObject.Properties.Name -contains $accountNum) {
        Write-Host "Error: Account-$accountNum does not exist"
        exit 1
    }
    
    $email = $sequence.accounts.$accountNum.email
    $currentAlias = $sequence.accounts.$accountNum.alias
    
    if ([string]::IsNullOrEmpty($currentAlias)) {
        Write-Host "Account-$accountNum ($email) has no alias set"
        exit 0
    }
    
    # Remove shortcut if exists
    $shortcutFile = Join-Path $script:ALIAS_DIR "$currentAlias.cmd"
    if (Test-Path $shortcutFile) {
        Remove-Item $shortcutFile -Force
    }
    
    # Remove alias property
    $sequence.accounts.$accountNum.PSObject.Properties.Remove("alias")
    $sequence.lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-JsonSafe -Path $script:SEQUENCE_FILE -Content $sequence
    
    Write-Host "Cleared alias '$currentAlias' from Account-$accountNum ($email)"
}

# Create shortcut command
function Invoke-CreateShortcut {
    param([string]$AliasName)
    
    if ([string]::IsNullOrEmpty($AliasName)) {
        Write-Host "Usage: ccswitch.ps1 --create-shortcut <alias_name>"
        exit 1
    }
    
    if (-not (Test-Path $script:SEQUENCE_FILE)) {
        Write-Host "Error: No accounts are managed yet"
        exit 1
    }
    
    # Find account with this alias
    $sequence = Get-Content $script:SEQUENCE_FILE -Raw | ConvertFrom-Json
    $accountNum = $null
    foreach ($key in $sequence.accounts.PSObject.Properties.Name) {
        if ($sequence.accounts.$key.alias -eq $AliasName) {
            $accountNum = $key
            break
        }
    }
    
    if ([string]::IsNullOrEmpty($accountNum)) {
        Write-Host "Error: No account found with alias '$AliasName'"
        exit 1
    }
    
    Initialize-Directories
    
    $scriptPath = $PSCommandPath
    $shortcutFile = Join-Path $script:ALIAS_DIR "$AliasName.cmd"
    
    # Create .cmd shortcut
    $cmdContent = @"
@echo off
REM Shortcut to switch to Claude Code account: $AliasName
powershell.exe -ExecutionPolicy Bypass -File "$scriptPath" -Force --switch-to "$AliasName"
"@
    
    Set-Content -Path $shortcutFile -Value $cmdContent -Encoding ASCII
    
    $email = $sequence.accounts.$accountNum.email
    
    Write-Host "Created shortcut: $shortcutFile"
    Write-Host "  Switches to: Account-$accountNum ($email)"
    Write-Host ""
    Write-Host "To use from anywhere, add to PATH:"
    Write-Host "  `$env:PATH += `";$script:ALIAS_DIR`""
    Write-Host ""
    Write-Host "Or add permanently via System Properties > Environment Variables"
    Write-Host ""
    Write-Host "Then run: $AliasName"
}

# Remove shortcut command
function Invoke-RemoveShortcut {
    param([string]$AliasName)
    
    if ([string]::IsNullOrEmpty($AliasName)) {
        Write-Host "Usage: ccswitch.ps1 --remove-shortcut <alias_name>"
        exit 1
    }
    
    $shortcutFile = Join-Path $script:ALIAS_DIR "$AliasName.cmd"
    
    if (-not (Test-Path $shortcutFile)) {
        Write-Host "Error: Shortcut '$AliasName' does not exist"
        exit 1
    }
    
    Remove-Item $shortcutFile -Force
    Write-Host "Removed shortcut: $AliasName"
}

# Show usage
function Show-Usage {
    Write-Host "Multi-Account Switcher for Claude Code (Windows)"
    Write-Host "Usage: ccswitch.ps1 [-Force] [COMMAND]"
    Write-Host ""
    Write-Host "Global Flags:"
    Write-Host "  -Force                               Skip Claude Code process check"
    Write-Host ""
    Write-Host "Account Commands:"
    Write-Host "  --add-account                        Add current account to managed accounts"
    Write-Host "  --remove-account <num|email|alias>   Remove account"
    Write-Host "  --list                               List all managed accounts"
    Write-Host "  --switch                             Rotate to next account in sequence"
    Write-Host "  --switch-to <num|email|alias>        Switch to specific account"
    Write-Host ""
    Write-Host "Alias Commands:"
    Write-Host "  --set-alias <num|email> <alias>      Set alias for an account"
    Write-Host "  --clear-alias <num|email|alias>      Remove alias from an account"
    Write-Host "  --create-shortcut <alias>            Create .cmd shortcut for alias"
    Write-Host "  --remove-shortcut <alias>            Remove shortcut"
    Write-Host ""
    Write-Host "Other:"
    Write-Host "  --help                               Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\ccswitch.ps1 --add-account"
    Write-Host "  .\ccswitch.ps1 --list"
    Write-Host "  .\ccswitch.ps1 --switch"
    Write-Host "  .\ccswitch.ps1 -Force --switch"
    Write-Host "  .\ccswitch.ps1 --switch-to 2"
    Write-Host "  .\ccswitch.ps1 --set-alias 1 claude-pro"
    Write-Host "  .\ccswitch.ps1 --switch-to claude-pro"
    Write-Host "  .\ccswitch.ps1 --create-shortcut claude-pro"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  CCSWITCH_ALIAS_DIR                   Directory for alias shortcuts"
}

# Main
$script:Force = $Force

switch ($Command) {
    "--add-account" { Invoke-AddAccount }
    "--remove-account" { Invoke-RemoveAccount -Identifier $Arguments[0] }
    "--list" { Invoke-List }
    "--switch" { Invoke-Switch }
    "--switch-to" { Invoke-SwitchTo -Identifier $Arguments[0] }
    "--set-alias" { Invoke-SetAlias -Identifier $Arguments[0] -AliasName $Arguments[1] }
    "--clear-alias" { Invoke-ClearAlias -Identifier $Arguments[0] }
    "--create-shortcut" { Invoke-CreateShortcut -AliasName $Arguments[0] }
    "--remove-shortcut" { Invoke-RemoveShortcut -AliasName $Arguments[0] }
    "--help" { Show-Usage }
    "" { Show-Usage }
    default {
        Write-Host "Error: Unknown command '$Command'"
        Show-Usage
        exit 1
    }
}

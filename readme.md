# Multi-Account Switcher for Claude Code

A simple tool to manage and switch between multiple Claude Code accounts on macOS, Linux, WSL, and Windows.

## Features

- **Multi-account management**: Add, remove, and list Claude Code accounts
- **Quick switching**: Switch between accounts with simple commands
- **Cross-platform**: Works on macOS, Linux, WSL, and Windows (PowerShell)
- **Secure storage**: Uses system keychain (macOS) or protected files (Linux/WSL/Windows)
- **Account aliases**: Assign friendly names to accounts for easier switching
- **Shortcut commands**: Create standalone commands like `claude-pro` to switch instantly
- **Settings preservation**: Only switches authentication - your themes, settings, and preferences remain unchanged

## Quick Install

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main/install.ps1 | iex
```

## Manual Installation

### macOS / Linux / WSL

```bash
curl -O https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main/ccswitch.sh
chmod +x ccswitch.sh
```

### Windows

Download `ccswitch.ps1` from the repository or:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main/ccswitch.ps1" -OutFile "ccswitch.ps1"
```

## Usage

### Basic Commands

**macOS / Linux / WSL:**

```bash
# Add current account to managed accounts
./ccswitch.sh --add-account

# List all managed accounts
./ccswitch.sh --list

# Switch to next account in sequence
./ccswitch.sh --switch

# Switch to specific account by number, email, or alias
./ccswitch.sh --switch-to 2
./ccswitch.sh --switch-to user2@example.com
./ccswitch.sh --switch-to claude-pro

# Remove an account
./ccswitch.sh --remove-account user2@example.com

# Show help
./ccswitch.sh --help
```

**Windows (PowerShell):**

```powershell
# Add current account to managed accounts
.\ccswitch.ps1 --add-account

# List all managed accounts
.\ccswitch.ps1 --list

# Switch to next account in sequence
.\ccswitch.ps1 --switch

# Switch to specific account
.\ccswitch.ps1 --switch-to 2
.\ccswitch.ps1 --switch-to user2@example.com
.\ccswitch.ps1 --switch-to claude-pro

# Remove an account
.\ccswitch.ps1 --remove-account user2@example.com

# Show help
.\ccswitch.ps1 --help
```

### Alias Commands

Aliases let you assign friendly names to accounts for easier switching.

**macOS / Linux / WSL:**

```bash
# Set alias for an account
./ccswitch.sh --set-alias 1 claude-pro
./ccswitch.sh --set-alias user@example.com work-account

# Clear alias from an account
./ccswitch.sh --clear-alias claude-pro

# Create standalone shortcut command
./ccswitch.sh --create-shortcut claude-pro

# Remove shortcut
./ccswitch.sh --remove-shortcut claude-pro
```

**Windows (PowerShell):**

```powershell
# Set alias for an account
.\ccswitch.ps1 --set-alias 1 claude-pro
.\ccswitch.ps1 --set-alias user@example.com work-account

# Clear alias from an account
.\ccswitch.ps1 --clear-alias claude-pro

# Create standalone shortcut command (.cmd file)
.\ccswitch.ps1 --create-shortcut claude-pro

# Remove shortcut
.\ccswitch.ps1 --remove-shortcut claude-pro
```

### Using Shortcut Commands

After creating a shortcut, you can switch accounts by just running the alias name:

```bash
# After: ./ccswitch.sh --create-shortcut claude-pro
# Add alias directory to PATH (one-time setup):
export PATH="$PATH:$HOME/.claude-switch-backup/aliases"

# Then simply run:
claude-pro
```

**Windows:**

```powershell
# After: .\ccswitch.ps1 --create-shortcut claude-pro
# Add alias directory to PATH (one-time setup):
$env:PATH += ";$env:USERPROFILE\.claude-switch-backup\aliases"

# Then simply run:
claude-pro
```

### First Time Setup

1. **Log into Claude Code** with your first account (make sure you're actively logged in)
2. Run `--add-account` to add it to managed accounts
3. **Log out** and log into Claude Code with your second account
4. Run `--add-account` again
5. Now you can switch between accounts with `--switch`
6. **Important**: After each switch, restart Claude Code to use the new authentication

> **What gets switched:** Only your authentication credentials change. Your themes, settings, preferences, and chat history remain exactly the same.

## Requirements

### macOS / Linux / WSL

- Bash 3.2+
- `jq` (JSON processor)

**Installing jq:**

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# RHEL/CentOS
sudo yum install jq

# Arch
sudo pacman -S jq
```

### Windows

- PowerShell 5.1+ or PowerShell 7+
- No additional dependencies required

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CCSWITCH_INSTALL_DIR` | Installation directory for one-liner install | `~/.local/bin` |
| `CCSWITCH_ALIAS_DIR` | Directory for alias shortcut commands | `~/.claude-switch-backup/aliases` |

## How It Works

The switcher stores account authentication data separately:

- **macOS**: Credentials in Keychain, OAuth info in `~/.claude-switch-backup/`
- **Linux/WSL**: Both credentials and OAuth info in `~/.claude-switch-backup/` with restricted permissions
- **Windows**: Both credentials and OAuth info in `%USERPROFILE%\.claude-switch-backup\` 

When switching accounts, it:

1. Backs up the current account's authentication data
2. Restores the target account's authentication data
3. Updates Claude Code's authentication files

## Troubleshooting

### If a switch fails

- Check that you have accounts added: `--list`
- Verify Claude Code is closed before switching (or use `--force` to skip check)
- Try switching back to your original account

### If you can't add an account

- Make sure you're logged into Claude Code first
- Check that you have `jq` installed (macOS/Linux only)
- Verify you have write permissions to your home directory

### If Claude Code doesn't recognize the new account

- Make sure you restarted Claude Code after switching
- Check the current account: `--list` (look for "(active)")

### Windows-specific issues

- If PowerShell blocks script execution, run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- If shortcuts don't work, ensure the alias directory is in your PATH

## Cleanup/Uninstall

To stop using this tool and remove all data:

1. Note your current active account: `--list`
2. Remove the backup directory:
   - macOS/Linux: `rm -rf ~/.claude-switch-backup`
   - Windows: `Remove-Item -Recurse -Force "$env:USERPROFILE\.claude-switch-backup"`
3. Delete the script(s)

Your current Claude Code login will remain active.

## Security Notes

- Credentials stored in macOS Keychain or files with 600 permissions
- Authentication files are stored with restricted permissions
- The tool requires Claude Code to be closed during account switches (use `--force` to override)

## License

MIT License - see LICENSE file for details

## Thanks

Forked from: https://github.com/ming86/cc-account-switcher

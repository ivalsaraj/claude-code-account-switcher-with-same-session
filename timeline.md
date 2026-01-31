# Timeline - Claude Code Account Switcher

## 2025-01-31 - Windows Support + Alias Feature

### Changes Made

1. **ccswitch.sh - Added alias support**
   - Added `ALIAS_DIR` configuration variable (default: `~/.claude-switch-backup/aliases`)
   - Extended `resolve_account_identifier()` to resolve aliases in addition to numbers/emails
   - Added `validate_alias()` function (alphanumeric, dash, underscore, must start with letter)
   - Added `alias_exists()` function to check for duplicate aliases
   - Added `cmd_set_alias` - sets alias for an account
   - Added `cmd_clear_alias` - removes alias from an account
   - Added `cmd_create_shortcut` - creates executable bash script in alias directory
   - Added `cmd_remove_shortcut` - removes shortcut script
   - Updated `cmd_list` to display aliases in format: `1: email@example.com [alias-name]`
   - Updated `cmd_remove_account` to clean up alias shortcuts when account is removed
   - Updated `show_usage` with new alias commands and examples

2. **ccswitch.ps1 - New Windows PowerShell implementation**
   - Full feature parity with bash script
   - Uses `%USERPROFILE%\.claude\.credentials.json` for credential storage
   - Creates `.cmd` wrapper files for shortcuts (enables running from cmd.exe)
   - Implements same alias resolution logic
   - Uses PowerShell native JSON handling (ConvertFrom-Json/ConvertTo-Json)

3. **install.sh - One-liner installer for macOS/Linux/WSL**
   - Downloads ccswitch.sh to `~/.local/bin/ccswitch`
   - Checks for jq dependency
   - Provides PATH setup instructions

4. **install.ps1 - One-liner installer for Windows**
   - Downloads ccswitch.ps1 to `%USERPROFILE%\.local\bin\`
   - Creates ccswitch.cmd wrapper for easier execution
   - Provides PATH setup instructions

5. **readme.md - Updated documentation**
   - Added quick install one-liner commands
   - Added Windows usage examples
   - Added alias commands documentation
   - Added shortcut usage guide
   - Added environment variables table
   - Updated requirements section for Windows

### Reasoning

- **Windows support**: Claude Code runs on Windows, users need native tooling without WSL
- **Alias feature**: Account numbers are not memorable; aliases like "claude-pro" improve UX
- **Shortcut commands**: Eliminates need to remember script path and arguments for frequent switches
- **One-liner install**: Reduces friction for new users, follows common pattern (homebrew, nvm, etc.)

### Files Created
- `ccswitch.ps1` - Windows PowerShell script
- `install.sh` - macOS/Linux/WSL installer
- `install.ps1` - Windows installer
- `knowledge.md` - Project knowledge base
- `timeline.md` - This file
- `knowledge_summary.md` - Quick reference summary

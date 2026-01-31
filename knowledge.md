# Knowledge Base - Claude Code Account Switcher

## Architecture Overview

### File Structure
- `ccswitch.sh` - Bash script for macOS/Linux/WSL
- `ccswitch.ps1` - PowerShell script for Windows
- `install.sh` - One-liner installer for macOS/Linux/WSL
- `install.ps1` - One-liner installer for Windows

### Data Storage Locations

| Platform | Config Path | Credentials Path | Backup Directory |
|----------|-------------|------------------|------------------|
| macOS | `~/.claude/.claude.json` or `~/.claude.json` | macOS Keychain | `~/.claude-switch-backup/` |
| Linux/WSL | `~/.claude/.claude.json` or `~/.claude.json` | `~/.claude/.credentials.json` | `~/.claude-switch-backup/` |
| Windows | `%USERPROFILE%\.claude\.claude.json` or `%USERPROFILE%\.claude.json` | `%USERPROFILE%\.claude\.credentials.json` | `%USERPROFILE%\.claude-switch-backup\` |

### Backup Structure
```
~/.claude-switch-backup/
├── sequence.json           # Account registry and metadata
├── configs/                # Per-account config backups
│   └── .claude-config-{num}-{email}.json
├── credentials/            # Per-account credential backups (Linux/WSL/Windows)
│   └── .claude-credentials-{num}-{email}.json
└── aliases/                # Shortcut command scripts
    └── {alias-name}        # Bash script (macOS/Linux) or .cmd (Windows)
```

### sequence.json Schema
```json
{
  "activeAccountNumber": 1,
  "lastUpdated": "2025-01-31T00:00:00Z",
  "sequence": [1, 2],
  "accounts": {
    "1": {
      "email": "user@example.com",
      "uuid": "account-uuid",
      "added": "2025-01-31T00:00:00Z",
      "alias": "claude-pro"
    }
  }
}
```

## Key Design Decisions

### 1. Alias Resolution Order
Identifier resolution follows: number → email → alias. This ensures backward compatibility with existing workflows using numbers/emails.

### 2. Shortcut Commands
- macOS/Linux: Creates executable bash scripts in `$ALIAS_DIR`
- Windows: Creates `.cmd` batch files that invoke PowerShell

### 3. Cross-Platform Parity
Both scripts implement identical commands and behavior. The only differences are:
- Credential storage mechanism (Keychain vs file)
- Shortcut file format (.sh vs .cmd)
- Path separators and environment variable syntax

### 4. Safe JSON Writes
All JSON writes use temp files with validation before atomic move to prevent corruption.

## Common Issues and Solutions

### Issue: Alias shortcut not found after creation
**Solution**: Add alias directory to PATH. The script outputs the exact command needed.

### Issue: PowerShell execution policy blocks script
**Solution**: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Issue: Account switch doesn't take effect
**Solution**: Claude Code must be restarted after switching. Use `--force` to skip process check if using VSCode extension.

## Version History Reference
See `timeline.md` for detailed change log.

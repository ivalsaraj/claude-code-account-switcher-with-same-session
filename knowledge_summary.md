Windows credentials at %USERPROFILE%\.claude\.credentials.json, config at %USERPROFILE%\.claude\.claude.json with fallback to %USERPROFILE%\.claude.json
Alias resolution order: number first, then email, then alias - maintains backward compatibility
Shortcuts on Windows use .cmd files that invoke PowerShell, on macOS/Linux use bash scripts
Always validate JSON before atomic write using temp file + move pattern
Claude Code must be restarted after account switch for changes to take effect
PowerShell execution policy may block scripts - use Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
Alias format: must start with letter, alphanumeric/dash/underscore only
Account removal should clean up associated alias shortcuts
One-liner installers download to ~/.local/bin by default, configurable via CCSWITCH_INSTALL_DIR

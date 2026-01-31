#!/usr/bin/env bash
# One-liner installer for Claude Code Account Switcher (macOS/Linux/WSL)
# Usage: curl -fsSL https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main/install.sh | bash

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/ivalsaraj/claude-code-account-switcher-with-same-session/main"
INSTALL_DIR="${CCSWITCH_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_NAME="ccswitch"

echo "Claude Code Account Switcher - Installer"
echo "========================================="
echo ""

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: 'jq' is required but not installed."
    echo ""
    case "$(uname -s)" in
        Darwin)
            echo "Install with: brew install jq"
            ;;
        Linux)
            echo "Install with: sudo apt install jq  (Debian/Ubuntu)"
            echo "          or: sudo yum install jq  (RHEL/CentOS)"
            echo "          or: sudo pacman -S jq    (Arch)"
            ;;
    esac
    exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download script
echo "Downloading ccswitch.sh..."
curl -fsSL "$REPO_URL/ccswitch.sh" -o "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo ""
echo "Installed to: $INSTALL_DIR/$SCRIPT_NAME"
echo ""

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Add to PATH by adding this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
    echo "Then restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
    echo ""
fi

echo "Usage:"
echo "  $SCRIPT_NAME --help"
echo "  $SCRIPT_NAME --add-account"
echo "  $SCRIPT_NAME --list"
echo "  $SCRIPT_NAME --switch"
echo ""
echo "Installation complete!"

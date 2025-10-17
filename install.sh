#!/usr/bin/env bash
set -euo pipefail

# Installer for Claude Code Model Switcher (CCM)
# - Writes a ccm() function into your shell rc so that `ccm kimi` works directly
# - Does NOT rely on modifying PATH or copying binaries
# - Idempotent: will replace previous CCM function block if exists

# GitHub repository info
GITHUB_REPO="foreveryh/claude-code-switch"
GITHUB_BRANCH="main"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Detect if running from local directory or piped from curl
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  # Running locally
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_MODE=true
else
  # Piped from curl or running without source file
  SCRIPT_DIR=""
  LOCAL_MODE=false
fi

# Install destination (stable per-user location)
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ccm"
DEST_SCRIPT_PATH="$INSTALL_DIR/ccm.sh"
BEGIN_MARK="# >>> ccm function begin >>>"
END_MARK="# <<< ccm function end <<<"

# Detect which rc file to modify (prefer zsh)
detect_rc_file() {
  local shell_name
  shell_name="${SHELL##*/}"
  case "$shell_name" in
    zsh)
      echo "$HOME/.zshrc"
      ;;
    bash)
      echo "$HOME/.bashrc"
      ;;
    *)
      # Fallback to zshrc
      echo "$HOME/.zshrc"
      ;;
  esac
}

remove_existing_block() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  if grep -qF "$BEGIN_MARK" "$rc"; then
    # Remove the existing block between markers (inclusive)
    local tmp
    tmp="$(mktemp)"
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      $0==b {inblock=1; next}
      $0==e {inblock=0; next}
      !inblock {print}
    ' "$rc" > "$tmp" && mv "$tmp" "$rc"
  fi
}

append_function_block() {
  local rc="$1"
  mkdir -p "$(dirname "$rc")"
  [[ -f "$rc" ]] || touch "$rc"
  cat >> "$rc" <<EOF
$BEGIN_MARK
# CCM: define a shell function that applies exports to current shell
ccm() {
  local script="$DEST_SCRIPT_PATH"
  # Fallback search if the installed script was moved or XDG paths changed
  if [[ ! -f "\$script" ]]; then
    local default1="\${XDG_DATA_HOME:-\$HOME/.local/share}/ccm/ccm.sh"
    local default2="\$HOME/.ccm/ccm.sh"
    if [[ -f "\$default1" ]]; then
      script="\$default1"
    elif [[ -f "\$default2" ]]; then
      script="\$default2"
    fi
  fi
  if [[ ! -f "\$script" ]]; then
    echo "ccm error: script not found at \$script" >&2
    return 1
  fi

  # All commands use eval to apply environment variables
  case "\$1" in
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg")
      # These commands don't need eval, execute directly
      "\$script" "\$@"
      ;;
    *)
      # All other commands (including pp) use eval to set environment variables
      eval "\$("\$script" "\$@")"
      ;;
  esac
}

# CCC: Claude Code Commander - switch model and launch Claude Code
ccc() {
  if [[ \$# -eq 0 ]]; then
    echo "Usage: ccc <model> [claude-options]"
    echo ""
    echo "Examples:"
    echo "  ccc deepseek                              # Launch with DeepSeek"
    echo "  ccc pp deepseek                           # Launch with PPINFRA DeepSeek"
    echo "  ccc glm --dangerously-skip-permissions    # Launch GLM with options"
    echo ""
    echo "Available models:"
    echo "  Official: deepseek, glm, kimi, qwen, claude, opus, longcat"
    echo "  PPINFRA:  pp deepseek, pp glm, pp kimi, pp qwen"
    return 1
  fi

  # Check for pp prefix
  local use_pp=false
  local model=""
  local claude_args=()
  
  if [[ "\$1" == "pp" ]]; then
    use_pp=true
    shift
    model="\$1"
    shift
  else
    model="\$1"
    shift
  fi
  
  # Collect additional Claude Code arguments
  claude_args=("\$@")
  
  # Call ccm to set environment variables
  if \$use_pp; then
    echo "🔄 Switching to PPINFRA \$model..."
    ccm pp "\$model" || return 1
  else
    echo "🔄 Switching to \$model..."
    ccm "\$model" || return 1
  fi

  echo ""
  echo "🚀 Launching Claude Code..."
  echo "   Model: \$ANTHROPIC_MODEL"
  echo "   Base URL: \${ANTHROPIC_BASE_URL:-Default (Anthropic)}"
  echo ""

  # Launch Claude Code
  if [[ \${#claude_args[@]} -eq 0 ]]; then
    exec claude
  else
    exec claude "\${claude_args[@]}"
  fi
}
$END_MARK
EOF
}

download_from_github() {
  local url="$1"
  local dest="$2"
  echo "Downloading from $url..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    echo "Error: neither curl nor wget found" >&2
    return 1
  fi
}

main() {
  mkdir -p "$INSTALL_DIR"

  if $LOCAL_MODE && [[ -f "$SCRIPT_DIR/ccm.sh" ]]; then
    # Local mode: copy from local directory
    echo "Installing from local directory..."
    cp -f "$SCRIPT_DIR/ccm.sh" "$DEST_SCRIPT_PATH"
    if [[ -d "$SCRIPT_DIR/lang" ]]; then
      rm -rf "$INSTALL_DIR/lang"
      cp -R "$SCRIPT_DIR/lang" "$INSTALL_DIR/lang"
    fi
  else
    # Remote mode: download from GitHub
    echo "Installing from GitHub..."
    download_from_github "${GITHUB_RAW}/ccm.sh" "$DEST_SCRIPT_PATH" || {
      echo "Error: failed to download ccm.sh" >&2
      exit 1
    }
    
    # Download lang files
    mkdir -p "$INSTALL_DIR/lang"
    download_from_github "${GITHUB_RAW}/lang/zh.json" "$INSTALL_DIR/lang/zh.json" || true
    download_from_github "${GITHUB_RAW}/lang/en.json" "$INSTALL_DIR/lang/en.json" || true
  fi

  chmod +x "$DEST_SCRIPT_PATH"

  local rc
  rc="$(detect_rc_file)"
  remove_existing_block "$rc"
  append_function_block "$rc"

  echo "✅ Installed ccm and ccc functions into: $rc"
  echo "   Script installed to: $DEST_SCRIPT_PATH"
  echo "   Reload your shell or run: source $rc"
  echo ""
  echo "   Then use:"
  echo "     ccm deepseek       # Switch model in current terminal"
  echo "     ccc deepseek       # Switch model and launch Claude Code"
  echo "     ccm pp glm         # Use PPINFRA fallback service"
  echo "     ccc pp glm         # PPINFRA + launch Claude Code"
}

main "$@"
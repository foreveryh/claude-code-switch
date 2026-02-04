#!/usr/bin/env bash
set -euo pipefail

# Installer for Claude Code Model Switcher (CCM)
# Default: user-level install (PATH-based)
# Optional: system-level, project-level, rc-function injection, legacy cleanup

# GitHub repository info
GITHUB_REPO="${GITHUB_REPO:-foreveryh/claude-code-switch}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Detect if running from local directory or piped from curl
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_MODE=true
else
  SCRIPT_DIR=""
  LOCAL_MODE=false
fi

BEGIN_MARK="# >>> ccm function begin >>>"
END_MARK="# <<< ccm function end <<<"

MODE="user"              # user | system | project
PREFIX=""               # explicit bin dir
ENABLE_RC=false          # add rc function block
CLEANUP_LEGACY=false     # remove old rc blocks + legacy dirs
ASSUME_YES=false         # non-interactive confirmations
PROJECT_DIR=""           # for project mode

log_info() {
  echo "==> $*"
}

log_warn() {
  echo "Warning: $*" >&2
}

log_error() {
  echo "Error: $*" >&2
}

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --user                User-level install (default)
  --system              System-level install (may require sudo)
  --project             Project-level install into .ccm/ (current dir)
  --prefix <dir>        Override install bin directory
  --rc                  Inject ccm/ccc functions into shell rc
  --cleanup-legacy      Remove legacy rc blocks and old install dirs
  -y, --yes             Assume yes for prompts
  -h, --help            Show this help

Examples:
  ./install.sh
  ./install.sh --user
  ./install.sh --system
  ./install.sh --project
  ./install.sh --prefix "$HOME/bin"
  ./install.sh --cleanup-legacy
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)
        MODE="user"
        ;;
      --system)
        MODE="system"
        ;;
      --project)
        MODE="project"
        PROJECT_DIR="${PROJECT_DIR:-$PWD}"
        ;;
      --prefix)
        shift || true
        PREFIX="${1:-}"
        ;;
      --rc)
        ENABLE_RC=true
        ;;
      --cleanup-legacy|--migrate)
        CLEANUP_LEGACY=true
        ;;
      -y|--yes)
        ASSUME_YES=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift || true
  done
}

in_path() {
  echo "$PATH" | tr ':' '\n' | grep -Fqx "$1"
}

needs_sudo() {
  local dir="$1"
  [[ -d "$dir" && ! -w "$dir" ]]
}

run_cmd() {
  local dir="$1"
  shift
  if needs_sudo "$dir"; then
    sudo "$@"
  else
    "$@"
  fi
}

find_user_bin_dir() {
  if [[ -n "${XDG_BIN_HOME:-}" ]]; then
    echo "$XDG_BIN_HOME"
    return 0
  fi
  if [[ -d "$HOME/.local/bin" || ! -d "$HOME/bin" ]]; then
    echo "$HOME/.local/bin"
    return 0
  fi
  echo "$HOME/bin"
}

find_system_bin_dir() {
  if command -v brew >/dev/null 2>&1; then
    local brew_bin
    brew_bin="$(brew --prefix)/bin"
    if [[ -d "$brew_bin" ]]; then
      echo "$brew_bin"
      return 0
    fi
  fi
  if [[ -d "/usr/local/bin" ]]; then
    echo "/usr/local/bin"
    return 0
  fi
  echo "/usr/local/bin"
}

select_bin_dir() {
  if [[ -n "$PREFIX" ]]; then
    echo "$PREFIX"
    return 0
  fi
  if [[ "$MODE" == "system" ]]; then
    find_system_bin_dir
  else
    find_user_bin_dir
  fi
}

select_data_dir() {
  if [[ "$MODE" == "system" ]]; then
    echo "/usr/local/share/ccm"
    return 0
  fi
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/ccm"
}

detect_rc_files() {
  local rc_files=()
  [[ -f "$HOME/.zshrc" ]] && rc_files+=("$HOME/.zshrc")
  [[ -f "$HOME/.zprofile" ]] && rc_files+=("$HOME/.zprofile")
  [[ -f "$HOME/.bashrc" ]] && rc_files+=("$HOME/.bashrc")
  [[ -f "$HOME/.bash_profile" ]] && rc_files+=("$HOME/.bash_profile")
  [[ -f "$HOME/.profile" ]] && rc_files+=("$HOME/.profile")
  echo "${rc_files[*]}"
}

remove_existing_block() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  if grep -qF "$BEGIN_MARK" "$rc"; then
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
  local script_path="$2"
  mkdir -p "$(dirname "$rc")"
  [[ -f "$rc" ]] || touch "$rc"
  cat >> "$rc" <<EOF
$BEGIN_MARK
# CCM: define a shell function that applies exports to current shell
# Ensure no alias/function clashes
unalias ccm 2>/dev/null || true
unset -f ccm 2>/dev/null || true
ccm() {
  local script="$script_path"
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
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg"|"save-account"|"switch-account"|"list-accounts"|"delete-account"|"current-account"|"debug-keychain")
      # These commands don't need eval, execute directly
      "\$script" "\$@"
      ;;
    *)
      # All other commands (including pp, model switching) use eval to set environment variables
      eval "\$("\$script" "\$@")"
      ;;
  esac
}

# CCC: Claude Code Commander - switch model and launch Claude Code
# Ensure no alias/function clashes
unalias ccc 2>/dev/null || true
unset -f ccc 2>/dev/null || true
ccc() {
  if [[ \$# -eq 0 ]]; then
    echo "Usage: ccc <model> [claude-options]"
    echo "       ccc <account> [claude-options]            # Switch account then launch"
    echo "       ccc <model>:<account> [claude-options]"
    echo ""
    echo "Examples:"
    echo "  ccc deepseek                              # Launch with DeepSeek"
    echo "  ccc pp deepseek                           # Launch with PPINFRA DeepSeek"
    echo "  ccc woohelps                              # Switch to 'woohelps' account and launch"
    echo "  ccc opus:work                             # Switch to 'work' account and launch Opus"
    echo "  ccc glm --dangerously-skip-permissions    # Launch GLM with options"
    echo ""
    echo "Available models:"
    echo "  Official: deepseek, glm, kimi, qwen, claude, opus, haiku, longcat"
    echo "  PPINFRA:  pp deepseek, pp glm, pp kimi, pp qwen"
    echo "  Account:  <account> | claude:<account> | opus:<account> | haiku:<account>"
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
  
  # Helper: known model keyword
  _is_known_model() {
    case "\$1" in
      deepseek|ds|glm|glm4|glm4.6|glm4.7|kimi|kimi2|qwen|longcat|lc|minimax|mm|claude|sonnet|s|opus|o|haiku|h|proxy)
        return 0 ;;
      *)
        return 1 ;;
    esac
  }

  # Configure environment via ccm
  if \$use_pp; then
    echo "🔄 Switching to PPINFRA \$model..."
    ccm pp "\$model" || return 1
  else
    if [[ "\$model" == *:* ]]; then
      # model:account form handled by ccm
      echo "🔄 Switching to \$model..."
      ccm "\$model" || return 1
    elif _is_known_model "\$model"; then
      echo "🔄 Switching to \$model..."
      ccm "\$model" || return 1
    else
      # Treat as account name
      local account="\$model"
      echo "🔄 Switching account to \$account..."
      ccm switch-account "\$account" || return 1
      # Set default model (Claude Sonnet)
      ccm claude || return 1
    fi
  fi

  echo ""
  echo "🚀 Launching Claude Code..."
  echo "   Model: \$ANTHROPIC_MODEL"
  echo "   Base URL: \${ANTHROPIC_BASE_URL:-Default (Anthropic)}"
  echo ""

  # Ensure `claude` CLI exists
  if ! type -p claude >/dev/null 2>&1; then
    echo "❌ 'claude' CLI not found. Install: npm install -g @anthropic-ai/claude-code" >&2
    return 127
  fi

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

legacy_detect() {
  local current_data_dir="${1:-}"
  local found=false
  local legacy_msgs=()
  local rc_files
  rc_files=( $(detect_rc_files) )
  local rc
  for rc in "${rc_files[@]:-}"; do
    if grep -qF "$BEGIN_MARK" "$rc"; then
      found=true
      legacy_msgs+=("- legacy rc block in $rc")
    fi
  done
  if [[ -d "$HOME/.ccm" ]]; then
    found=true
    legacy_msgs+=("- legacy dir $HOME/.ccm")
  fi
  local user_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/ccm"
  if [[ -d "$user_data_dir" && "$user_data_dir" != "$current_data_dir" ]]; then
    legacy_msgs+=("- legacy dir $user_data_dir")
    found=true
  fi

  if $found; then
    printf '%s\n' "${legacy_msgs[@]}"
    return 0
  fi
  return 1
}

cleanup_legacy() {
  log_info "Cleaning legacy installation artifacts..."
  local rc_files
  rc_files=( $(detect_rc_files) )
  local rc
  for rc in "${rc_files[@]:-}"; do
    remove_existing_block "$rc"
  done
  rm -rf "$HOME/.ccm" || true
  rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/ccm" || true
}

download_from_github() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    log_error "Neither curl nor wget found"
    return 1
  fi
}

install_assets() {
  local data_dir="$1"
  local dest_ccm_sh="$data_dir/ccm.sh"

  run_cmd "$data_dir" mkdir -p "$data_dir"

  if $LOCAL_MODE && [[ -f "$SCRIPT_DIR/ccm.sh" ]]; then
    log_info "Installing from local directory..."
    run_cmd "$data_dir" cp -f "$SCRIPT_DIR/ccm.sh" "$dest_ccm_sh"
    if [[ -d "$SCRIPT_DIR/lang" ]]; then
      run_cmd "$data_dir" rm -rf "$data_dir/lang"
      run_cmd "$data_dir" cp -R "$SCRIPT_DIR/lang" "$data_dir/lang"
    fi
  else
    log_info "Installing from GitHub..."
    download_from_github "${GITHUB_RAW}/ccm.sh" "$dest_ccm_sh" || {
      log_error "failed to download ccm.sh"
      exit 1
    }
    run_cmd "$data_dir" mkdir -p "$data_dir/lang"
    download_from_github "${GITHUB_RAW}/lang/zh.json" "$data_dir/lang/zh.json" || true
    download_from_github "${GITHUB_RAW}/lang/en.json" "$data_dir/lang/en.json" || true
  fi

  run_cmd "$data_dir" chmod +x "$dest_ccm_sh"
}

write_ccm_wrapper() {
  local bin_dir="$1"
  local mode="$2"
  local data_dir="$3"
  local target="$bin_dir/ccm"

  run_cmd "$bin_dir" mkdir -p "$bin_dir"

  if [[ "$mode" == "project" ]]; then
    cat > "$target" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CCM_SH="$SCRIPT_DIR/../ccm.sh"
if [[ ! -f "$CCM_SH" ]]; then
  echo "ccm error: missing $CCM_SH" >&2
  exit 1
fi
exec "$CCM_SH" "$@"
EOF
  else
    cat > "$target" <<EOF
#!/usr/bin/env bash
set -euo pipefail
CCM_SH="${data_dir}/ccm.sh"
if [[ ! -f "\$CCM_SH" ]]; then
  echo "ccm error: missing \$CCM_SH" >&2
  exit 1
fi
exec "\$CCM_SH" "\$@"
EOF
  fi

  run_cmd "$bin_dir" chmod +x "$target"
}

write_ccc_wrapper() {
  local bin_dir="$1"
  local mode="$2"
  local data_dir="$3"
  local target="$bin_dir/ccc"

  run_cmd "$bin_dir" mkdir -p "$bin_dir"

  if [[ "$mode" == "project" ]]; then
    cat > "$target" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CCM="$SCRIPT_DIR/../ccm.sh"

usage() {
    cat <<EOF2
Usage: ccc <model> [claude-options]
       ccc <account> [claude-options]        # Switch account then launch (default model)
       ccc <model>:<account> [claude-options]
       ccc pp <model> [claude-options]

Examples:
  ccc deepseek                     # Launch Claude Code with DeepSeek
  ccc pp glm                       # Launch with PPINFRA GLM
  ccc kimi --dangerously-skip-permissions  # Pass options to Claude Code
  ccc woohelps                     # Switch to 'woohelps' account and launch
  ccc opus:work                    # Switch to 'work' account and use Opus

Available models:
  Official: deepseek, glm, kimi, qwen, seed|doubao, claude, opus, haiku, longcat, minimax, proxy
  PPINFRA:  pp deepseek | pp glm | pp kimi | pp qwen
  Account:  <account> | claude:<account> | opus:<account> | haiku:<account>
EOF2
}

if [[ ! -f "$CCM" ]]; then
    echo "ccc error: cannot find ccm CLI at $CCM" >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

use_pp=false
model=""

if [[ "${1:-}" == "pp" ]]; then
    use_pp=true
    shift || true
fi

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

model="$1"
shift || true

claude_args=("$@")

is_known_model() {
    case "$1" in
        deepseek|ds|glm|glm4|glm4.6|glm4.7|kimi|kimi2|qwen|longcat|lc|minimax|mm|seed|doubao|claude|sonnet|s|opus|o|haiku|h|proxy)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

if ! $use_pp && [[ "$model" != *:* ]] && ! is_known_model "$model" && [[ ! "$model" =~ ^- ]]; then
    account="$model"
    if ! "$CCM" switch-account "$account"; then
        echo "❌ Failed to switch account: $account" >&2
        exit 1
    fi
    "$CCM" current-account || true
    eval "$("$CCM" claude)"
else
    if $use_pp; then
        eval "$("$CCM" pp "$model" true)"
    else
        eval "$("$CCM" "$model")"
    fi
fi

echo ""
echo "🚀 Launching Claude Code..."
echo "   Model: ${ANTHROPIC_MODEL:-'(unset)'}"
echo "   Base URL: ${ANTHROPIC_BASE_URL:-'Default (Anthropic)'}"

if ! command -v claude >/dev/null 2>&1; then
    echo "❌ 'claude' CLI not found. Install it first: npm install -g @anthropic-ai/claude-code" >&2
    exit 127
fi

if [[ ${#claude_args[@]} -eq 0 ]]; then
    exec claude
else
    exec claude "${claude_args[@]}"
fi
EOF
  else
    cat > "$target" <<EOF
#!/usr/bin/env bash
set -euo pipefail
CCM="${data_dir}/ccm.sh"

usage() {
    cat <<EOF2
Usage: ccc <model> [claude-options]
       ccc <account> [claude-options]        # Switch account then launch (default model)
       ccc <model>:<account> [claude-options]
       ccc pp <model> [claude-options]

Examples:
  ccc deepseek                     # Launch Claude Code with DeepSeek
  ccc pp glm                       # Launch with PPINFRA GLM
  ccc kimi --dangerously-skip-permissions  # Pass options to Claude Code
  ccc woohelps                     # Switch to 'woohelps' account and launch
  ccc opus:work                    # Switch to 'work' account and use Opus

Available models:
  Official: deepseek, glm, kimi, qwen, seed|doubao, claude, opus, haiku, longcat, minimax, proxy
  PPINFRA:  pp deepseek | pp glm | pp kimi | pp qwen
  Account:  <account> | claude:<account> | opus:<account> | haiku:<account>
EOF2
}

if [[ ! -f "$CCM" ]]; then
    echo "ccc error: cannot find ccm CLI at $CCM" >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

use_pp=false
model=""

if [[ "${1:-}" == "pp" ]]; then
    use_pp=true
    shift || true
fi

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

model="$1"
shift || true

claude_args=("$@")

is_known_model() {
    case "$1" in
        deepseek|ds|glm|glm4|glm4.6|glm4.7|kimi|kimi2|qwen|longcat|lc|minimax|mm|seed|doubao|claude|sonnet|s|opus|o|haiku|h|proxy)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

if ! $use_pp && [[ "$model" != *:* ]] && ! is_known_model "$model" && [[ ! "$model" =~ ^- ]]; then
    account="$model"
    if ! "$CCM" switch-account "$account"; then
        echo "❌ Failed to switch account: $account" >&2
        exit 1
    fi
    "$CCM" current-account || true
    eval "$("$CCM" claude)"
else
    if $use_pp; then
        eval "$("$CCM" pp "$model" true)"
    else
        eval "$("$CCM" "$model")"
    fi
fi

echo ""
echo "🚀 Launching Claude Code..."
echo "   Model: ${ANTHROPIC_MODEL:-'(unset)'}"
echo "   Base URL: ${ANTHROPIC_BASE_URL:-'Default (Anthropic)'}"

if ! command -v claude >/dev/null 2>&1; then
    echo "❌ 'claude' CLI not found. Install it first: npm install -g @anthropic-ai/claude-code" >&2
    exit 127
fi

if [[ ${#claude_args[@]} -eq 0 ]]; then
    exec claude
else
    exec claude "${claude_args[@]}"
fi
EOF
  fi

  run_cmd "$bin_dir" chmod +x "$target"
}

write_project_activate() {
  local project_dir="$1"
  local activate_path="$project_dir/.ccm/activate"
  cat > "$activate_path" <<'EOF'
# CCM project activation
# Usage: source .ccm/activate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PATH="$SCRIPT_DIR/bin:$PATH"
EOF
  chmod +x "$activate_path"
}

main() {
  parse_args "$@"

  if [[ "$MODE" == "project" ]]; then
    PROJECT_DIR="${PROJECT_DIR:-$PWD}"
  fi

  if [[ "$MODE" == "project" && -n "$PREFIX" ]]; then
    log_error "--prefix cannot be used with --project"
    exit 1
  fi

  local bin_dir
  local data_dir
  if [[ "$MODE" == "project" ]]; then
    bin_dir="$PROJECT_DIR/.ccm/bin"
    data_dir="$PROJECT_DIR/.ccm"
  else
    bin_dir="$(select_bin_dir)"
    data_dir="$(select_data_dir)"
  fi

  # Legacy detection and guidance
  local legacy_info=""
  if legacy_info=$(legacy_detect "$data_dir"); then
    echo ""
    log_warn "Legacy installation detected:"
    echo "$legacy_info"
    echo ""
    echo "This can override the new PATH-based install."
    echo "- To clean automatically, run: ./install.sh --cleanup-legacy"
    echo ""
    if ! $CLEANUP_LEGACY; then
      if [[ -t 0 && "$ASSUME_YES" == "false" ]]; then
        read -r -p "Clean legacy install now? [y/N] " reply
        case "$reply" in
          y|Y|yes|YES)
            CLEANUP_LEGACY=true
            ;;
          *)
            ;;
        esac
      fi
    fi
  fi

  if $CLEANUP_LEGACY; then
    cleanup_legacy
  fi

  # Install assets
  install_assets "$data_dir"

  # Install wrappers
  write_ccm_wrapper "$bin_dir" "$MODE" "$data_dir"
  write_ccc_wrapper "$bin_dir" "$MODE" "$data_dir"

  # Optional rc injection
  if $ENABLE_RC && [[ "$MODE" != "project" ]]; then
    local rc_files
    rc_files=( $(detect_rc_files) )
    local rc_target="${rc_files[0]:-$HOME/.zshrc}"
    remove_existing_block "$rc_target"
    append_function_block "$rc_target" "$data_dir/ccm.sh"
    log_info "Injected ccm/ccc functions into: $rc_target"
  fi

  if [[ "$MODE" == "project" ]]; then
    write_project_activate "$PROJECT_DIR"
  fi

  echo ""
  log_info "✅ Installation complete"
  echo "   Mode: $MODE"
  echo "   Bin:  $bin_dir"
  echo "   Data: $data_dir"

  if ! in_path "$bin_dir"; then
    echo ""
    log_warn "$bin_dir is not in your PATH"
    echo "Add this to your shell rc (~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"$bin_dir:\$PATH\""
  fi

  echo ""
  if [[ "$MODE" == "project" ]]; then
    echo "Next steps:"
    echo "  source .ccm/activate"
    echo "  ccm status"
  else
    echo "Next steps:"
    if $ENABLE_RC; then
      echo "  source ~/.zshrc (or ~/.bashrc)"
      echo "  ccm status"
    else
      echo "  eval \"\$(ccm deepseek)\"   # Apply env to current shell"
      echo "  ccc deepseek              # Switch + launch Claude Code"
    fi
  fi
}

main "$@"

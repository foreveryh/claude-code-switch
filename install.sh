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
ENABLE_RC=true           # add rc function block (default on for convenience)
CLEANUP_LEGACY=false     # remove old rc blocks + legacy dirs
ASSUME_YES=false         # non-interactive confirmations
PROJECT_DIR=""           # for project mode
INTERACTIVE=false        # interactive prompts

t() {
  local en="$1"
  local zh="$2"
  if [[ "${CCM_LANGUAGE:-${LANG:-}}" =~ ^zh ]]; then
    echo "$zh"
  else
    echo "$en"
  fi
}

log_info() {
  echo "==> $*"
}

log_warn() {
  echo "$(t "Warning" "警告"): $*" >&2
}

log_error() {
  echo "$(t "Error" "错误"): $*" >&2
}

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --user                User-level install (default)
  --system              System-level install (may require sudo)
  --project             Project-level install into .ccm/ (current dir)
  --prefix <dir>        Override install bin directory
  --rc                  Inject ccm/ccc functions into shell rc (default)
  --no-rc               Do not inject ccm/ccc functions into shell rc
  --cleanup-legacy      Remove legacy rc blocks and old install dirs
  --interactive         Force interactive prompts
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
      --no-rc)
        ENABLE_RC=false
        ;;
      --cleanup-legacy|--migrate)
        CLEANUP_LEGACY=true
        ;;
      --interactive)
        INTERACTIVE=true
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
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg"|"save-account"|"switch-account"|"list-accounts"|"delete-account"|"current-account"|"debug-keychain"|"project")
      # These commands don't need eval, execute directly
      "\$script" "\$@"
      ;;
    *)
      # All other commands (model switching) use eval to set environment variables
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
    echo "Usage: ccc <model> [region|variant] [claude-options]"
    echo "       ccc open <provider> [claude-options]"
    echo "       ccc <account> [claude-options]            # Switch account then launch"
    echo "       ccc <model>:<account> [claude-options]"
    echo ""
    echo "Examples:"
    echo "  ccc deepseek                              # Launch with DeepSeek"
    echo "  ccc open kimi                             # Launch with OpenRouter (kimi)"
    echo "  ccc woohelps                              # Switch to 'woohelps' account and launch"
    echo "  ccc claude:work                           # Switch to 'work' account and use Claude"
    echo "  ccc glm --dangerously-skip-permissions    # Launch GLM with options"
    echo ""
    echo "Available models:"
    echo "  Official: deepseek, glm, kimi, qwen, seed|doubao, claude, minimax"
    echo "  OpenRouter: open <provider>"
    echo "  Account:  <account> | claude:<account>"
    return 1
  fi

  local model=""
  local open_provider=""
  local region_arg=""
  local seed_variant=""

  if [[ "\$1" == "open" ]]; then
    shift || true
    if [[ \$# -lt 1 ]]; then
      echo "Usage: ccc open <provider> [claude-options]"
      return 1
    fi
    model="open"
    open_provider="\$1"
    shift || true
  else
    model="\$1"
    shift || true
  fi
  
  # Helper: known model keyword
  _is_known_model() {
    case "\$1" in
      deepseek|ds|glm|glm5|kimi|kimi2|qwen|minimax|mm|seed|doubao|claude|sonnet|s|open)
        return 0 ;;
      *)
        return 1 ;;
    esac
  }

  # Configure environment via ccm
  if [[ "\$model" != "open" ]] && [[ "\$model" != *:* ]] && ! _is_known_model "\$model" && [[ ! "\$model" =~ ^- ]]; then
    # Treat as account name
    local account="\$model"
    echo "🔄 Switching account to \$account..."
    ccm switch-account "\$account" || return 1
    ccm current-account || true
    ccm claude || return 1
  else
    if [[ "\$model" == "open" ]]; then
      echo "🔄 Switching to OpenRouter (\$open_provider)..."
      ccm open "\$open_provider" || return 1
    else
      case "\$model" in
        kimi|kimi2|qwen|glm|glm5|minimax|mm)
          if [[ "\${1:-}" =~ ^(global|china|cn)$ ]]; then
            region_arg="\$1"
            shift || true
          fi
          ;;
        seed|doubao)
          if [[ "\${1:-}" =~ ^(doubao|glm|glm5|deepseek|ds|kimi|kimi2)$ ]]; then
            seed_variant="\$1"
            shift || true
          fi
          ;;
      esac

      if [[ -n "\$seed_variant" ]]; then
        echo "🔄 Switching to \$model (\$seed_variant)..."
        ccm "\$model" "\$seed_variant" || return 1
      elif [[ -n "\$region_arg" ]]; then
        echo "🔄 Switching to \$model (\$region_arg)..."
        ccm "\$model" "\$region_arg" || return 1
      else
        echo "🔄 Switching to \$model..."
        ccm "\$model" || return 1
      fi
    fi
  fi

  # Collect additional Claude Code arguments
  local claude_args=("\$@")

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
    local content
    IFS= read -r -d '' content <<'EOF' || true
#!/usr/bin/env bash
set -euo pipefail
CCM_SH="__DATA_DIR__/ccm.sh"
if [[ ! -f "$CCM_SH" ]]; then
  echo "ccm error: missing $CCM_SH" >&2
  exit 1
fi
exec "$CCM_SH" "$@"
EOF
    content="${content//__DATA_DIR__/$data_dir}"
    printf '%s\n' "$content" > "$target"
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
Usage: ccc <model> [region|variant] [claude-options]
       ccc open <provider> [claude-options]
       ccc <account> [claude-options]        # Switch account then launch (default model)
       ccc <model>:<account> [claude-options]

Examples:
  ccc deepseek                     # Launch Claude Code with DeepSeek
  ccc open kimi                    # Launch with OpenRouter (kimi)
  ccc kimi --dangerously-skip-permissions  # Pass options to Claude Code
  ccc woohelps                     # Switch to 'woohelps' account and launch
  ccc claude:work                  # Switch to 'work' account and use Claude

Available models:
  Official: deepseek, glm, kimi, qwen, seed|doubao, claude, minimax
  OpenRouter: open <provider>
  Account:  <account> | claude:<account>
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

model=""
open_provider=""
region_arg=""
seed_variant=""
account=""

if [[ "${1:-}" == "open" ]]; then
    shift || true
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    model="open"
    open_provider="$1"
    shift || true
else
    model="$1"
    shift || true
fi

is_known_model() {
    case "$1" in
        deepseek|ds|glm|glm5|kimi|kimi2|qwen|minimax|mm|seed|doubao|claude|sonnet|s|open)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

if [[ "$model" != "open" ]] && [[ "$model" != *:* ]] && ! is_known_model "$model" && [[ ! "$model" =~ ^- ]]; then
    account="$model"
    if ! "$CCM" switch-account "$account"; then
        echo "❌ Failed to switch account: $account" >&2
        exit 1
    fi
    "$CCM" current-account || true
    eval "$("$CCM" claude)"
else
    if [[ "$model" == "open" ]]; then
        eval "$("$CCM" open "$open_provider")"
    else
        case "$model" in
            kimi|kimi2|qwen|glm|glm5|minimax|mm)
                if [[ "${1:-}" =~ ^(global|china|cn)$ ]]; then
                    region_arg="$1"
                    shift || true
                fi
                ;;
            seed|doubao)
                if [[ "${1:-}" =~ ^(doubao|glm|glm5|deepseek|ds|kimi|kimi2)$ ]]; then
                    seed_variant="$1"
                    shift || true
                fi
                ;;
        esac

        if [[ -n "$seed_variant" ]]; then
            eval "$("$CCM" "$model" "$seed_variant")"
        elif [[ -n "$region_arg" ]]; then
            eval "$("$CCM" "$model" "$region_arg")"
        else
            eval "$("$CCM" "$model")"
        fi
    fi
fi

claude_args=("$@")

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
    local content
    IFS= read -r -d '' content <<'EOF' || true
#!/usr/bin/env bash
set -euo pipefail
CCM="__DATA_DIR__/ccm.sh"

usage() {
    cat <<EOF2
Usage: ccc <model> [region|variant] [claude-options]
       ccc open <provider> [claude-options]
       ccc <account> [claude-options]        # Switch account then launch (default model)
       ccc <model>:<account> [claude-options]

Examples:
  ccc deepseek                     # Launch Claude Code with DeepSeek
  ccc open kimi                    # Launch with OpenRouter (kimi)
  ccc kimi --dangerously-skip-permissions  # Pass options to Claude Code
  ccc woohelps                     # Switch to 'woohelps' account and launch
  ccc claude:work                  # Switch to 'work' account and use Claude

Available models:
  Official: deepseek, glm, kimi, qwen, seed|doubao, claude, minimax
  OpenRouter: open <provider>
  Account:  <account> | claude:<account>
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

model=""
open_provider=""
region_arg=""
seed_variant=""
account=""

if [[ "${1:-}" == "open" ]]; then
    shift || true
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    model="open"
    open_provider="$1"
    shift || true
else
    model="$1"
    shift || true
fi

is_known_model() {
    case "$1" in
        deepseek|ds|glm|glm5|kimi|kimi2|qwen|minimax|mm|seed|doubao|claude|sonnet|s|open)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

if [[ "$model" != "open" ]] && [[ "$model" != *:* ]] && ! is_known_model "$model" && [[ ! "$model" =~ ^- ]]; then
    account="$model"
    if ! "$CCM" switch-account "$account"; then
        echo "❌ Failed to switch account: $account" >&2
        exit 1
    fi
    "$CCM" current-account || true
    eval "$("$CCM" claude)"
else
    if [[ "$model" == "open" ]]; then
        eval "$("$CCM" open "$open_provider")"
    else
        case "$model" in
            kimi|kimi2|qwen|glm|glm5|minimax|mm)
                if [[ "${1:-}" =~ ^(global|china|cn)$ ]]; then
                    region_arg="$1"
                    shift || true
                fi
                ;;
            seed|doubao)
                if [[ "${1:-}" =~ ^(doubao|glm|glm5|deepseek|ds|kimi|kimi2)$ ]]; then
                    seed_variant="$1"
                    shift || true
                fi
                ;;
        esac

        if [[ -n "$seed_variant" ]]; then
            eval "$("$CCM" "$model" "$seed_variant")"
        elif [[ -n "$region_arg" ]]; then
            eval "$("$CCM" "$model" "$region_arg")"
        else
            eval "$("$CCM" "$model")"
        fi
    fi
fi

claude_args=("$@")

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
    content="${content//__DATA_DIR__/$data_dir}"
    printf '%s\n' "$content" > "$target"
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
  local arg_count=$#
  parse_args "$@"

  echo ""
  log_info "$(t "CCM Installer" "CCM 安装器")"
  echo "$(t "Default: user-level PATH install + rc injection" "默认：用户级 PATH 安装 + 写入 rc")"
  echo "$(t "Options: --project (project-local), --system (system-wide), --no-rc (disable rc)" "可选项：--project（项目内）、--system（系统级）、--no-rc（不写入 rc）")"
  echo "$(t "Tip: use --cleanup-legacy if you previously installed the old rc-based version" "提示：如果以前使用过旧版 rc 安装，请用 --cleanup-legacy 清理")"
  echo "$(t "Interactive: auto-enabled when run without flags in a TTY" "交互模式：在 TTY 且不带参数运行时自动启用")"
  echo ""

  if [[ "$INTERACTIVE" == "false" && "$arg_count" -eq 0 && -t 0 && "$ASSUME_YES" == "false" ]]; then
    INTERACTIVE=true
  fi

  if $INTERACTIVE; then
    log_info "$(t "Interactive setup" "交互式安装")"
    echo "$(t "Select install mode:" "选择安装模式：")"
    echo "  1) $(t "User (recommended)" "用户级（推荐）")"
    echo "  2) $(t "System (may require sudo)" "系统级（可能需要 sudo）")"
    echo "  3) $(t "Project (current directory only)" "项目级（仅当前目录）")"
    read -r -p "$(t "Choose [1-3] (default 1): " "请选择 [1-3]（默认 1）：")" mode_choice
    case "$mode_choice" in
      2) MODE="system" ;;
      3) MODE="project" ;;
      *) MODE="user" ;;
    esac

    if [[ "$MODE" == "project" ]]; then
      read -r -p "$(t "Project directory (default: $PWD): " "项目目录（默认：$PWD）：")" proj_choice
      PROJECT_DIR="${proj_choice:-$PWD}"
    fi

    if [[ "$MODE" != "project" ]]; then
      read -r -p "$(t "Inject ccm/ccc functions into shell rc? [Y/n]: " "是否写入 shell rc（ccm/ccc 函数）？[Y/n]：")" rc_choice
      rc_choice="${rc_choice:-Y}"
      case "$rc_choice" in
        n|N|no|NO) ENABLE_RC=false ;;
        *) ENABLE_RC=true ;;
      esac
    fi
  fi

  if [[ "$MODE" == "project" ]]; then
    PROJECT_DIR="${PROJECT_DIR:-$PWD}"
    ENABLE_RC=false
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

  log_info "$(t "Install plan" "安装计划")"
  echo "  $(t "Mode" "模式"): $MODE"
  if [[ "$MODE" == "project" ]]; then
    echo "  $(t "Project" "项目"): $PROJECT_DIR"
  fi
  echo "  $(t "Bin" "可执行目录"):  $bin_dir"
  echo "  $(t "Data" "数据目录"): $data_dir"
  if $ENABLE_RC; then
    echo "  $(t "RC injection" "写入 rc"): $(t "enabled" "开启")"
  else
    echo "  $(t "RC injection" "写入 rc"): $(t "disabled" "关闭")"
  fi
  if $CLEANUP_LEGACY; then
    echo "  $(t "Legacy cleanup" "旧版清理"): $(t "enabled" "开启")"
  else
    echo "  $(t "Legacy cleanup" "旧版清理"): $(t "prompt if detected" "检测到则询问")"
  fi

  # Legacy detection and guidance
  local legacy_info=""
  if legacy_info=$(legacy_detect "$data_dir"); then
    echo ""
    log_warn "$(t "Legacy installation detected:" "检测到旧版安装：")"
    echo "$legacy_info"
    echo ""
    echo "$(t "This can override the new PATH-based install." "旧版可能会覆盖新的 PATH 安装。")"
    echo "$(t "- To clean automatically, run: ./install.sh --cleanup-legacy" "- 要自动清理，请运行：./install.sh --cleanup-legacy")"
    echo ""
    if ! $CLEANUP_LEGACY; then
      if [[ -t 0 && "$ASSUME_YES" == "false" ]]; then
        read -r -p "$(t "Clean legacy install now? [y/N] " "现在清理旧版安装？[y/N]：")" reply
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
    log_info "$(t "Injected ccm/ccc functions into:" "已写入 ccm/ccc 函数到：") $rc_target"
  fi

  if [[ "$MODE" == "project" ]]; then
    write_project_activate "$PROJECT_DIR"
  fi

  echo ""
  log_info "$(t "✅ Installation complete" "✅ 安装完成")"
  echo "   $(t "Mode" "模式"): $MODE"
  echo "   $(t "Bin" "可执行目录"):  $bin_dir"
  echo "   $(t "Data" "数据目录"): $data_dir"

  if ! in_path "$bin_dir"; then
    echo ""
    log_warn "$(t "$bin_dir is not in your PATH" "$bin_dir 不在你的 PATH 中")"
    echo "$(t "Add this to your shell rc (~/.zshrc or ~/.bashrc):" "把以下内容加入你的 shell rc（~/.zshrc 或 ~/.bashrc）：")"
    echo "  export PATH=\"$bin_dir:\$PATH\""
  fi

  echo ""
  if [[ "$MODE" == "project" ]]; then
    echo "$(t "Next steps:" "下一步：")"
    echo "  source .ccm/activate"
    echo "  ccm status"
  else
    echo "$(t "Next steps:" "下一步：")"
    if $ENABLE_RC; then
      echo "  source ~/.zshrc $(t "(or ~/.bashrc)" "（或 ~/.bashrc）")"
      echo "  ccm status"
    else
      echo "  eval \"\$(ccm deepseek)\"   # $(t "Apply env to current shell" "在当前 shell 生效")"
      echo "  ccc deepseek              # $(t "Switch + launch Claude Code" "切换并启动 Claude Code")"
    fi
  fi
}

main "$@"

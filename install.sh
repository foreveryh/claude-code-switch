#!/usr/bin/env bash
# CCM Installer - Python Version
# Supports user-level, system-level, and project-level installations

set -euo pipefail

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

MODE="user"
PREFIX=""
ENABLE_RC=true
CLEANUP_LEGACY=false
ASSUME_YES=false
PROJECT_DIR=""
INTERACTIVE=false
USE_PYTHON=true

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
  mkdir -p "$(dirname "$rc")"
  [[ -f "$rc" ]] || touch "$rc"
  cat >> "$rc" <<EOF
$BEGIN_MARK
# CCM: define a shell function that applies exports to current shell
# Ensure no alias/function clashes
unalias ccm 2>/dev/null || true
unset -f ccm 2>/dev/null || true
ccm() {
  # All commands use eval to apply environment variables
  case "\$1" in
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg"|"save-account"|"switch-account"|"list-accounts"|"delete-account"|"current-account"|"debug-keychain"|"project"|"user")
      # These commands don't need eval, execute directly
      python3 -m ccm "\$@"
      ;;
    *)
      # All other commands (model switching) use eval to set environment variables
      eval "\$(python3 -m ccm "\$@")"
      ;;
  esac
}

# CCC: Claude Code Commander - switch model and launch Claude Code
unalias ccc 2>/dev/null || true
unset -f ccc 2>/dev/null || true
ccc() {
  if [[ \$# -eq 0 ]]; then
    echo "Usage: ccc <model> [region|variant] [claude-options]"
    echo "       ccc open <provider> [claude-options]"
    echo ""
    echo "Examples:"
    echo "  ccc deepseek                              # Launch with DeepSeek"
    echo "  ccc open kimi                             # Launch with OpenRouter (kimi)"
    echo "  ccc glm --dangerously-skip-permissions    # Pass options to Claude Code"
    return 1
  fi
  # Switch environment and launch Claude Code
  python3 -m ccm.cli.launcher "\$@"
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

check_uv() {
  if command -v uv >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

check_python() {
  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

install_with_uv() {
  log_info "Installing with uv..."

  if $LOCAL_MODE && [[ -f "$SCRIPT_DIR/pyproject.toml" ]]; then
    cd "$SCRIPT_DIR"
    uv tool install . --force
  else
    log_error "Local installation requires pyproject.toml"
    return 1
  fi
}

install_with_pip() {
  log_info "Installing with pip..."

  if $LOCAL_MODE && [[ -f "$SCRIPT_DIR/pyproject.toml" ]]; then
    cd "$SCRIPT_DIR"
    pip3 install --user -e .
  else
    log_error "Local installation requires pyproject.toml"
    return 1
  fi
}

main() {
  local arg_count=$#
  parse_args "$@"

  echo ""
  log_info "$(t "CCM Installer (Python Version)" "CCM 安装器 (Python 版)")"
  echo "$(t "Installing CCM as a Python package" "将 CCM 作为 Python 包安装")"
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

  # Check prerequisites
  if ! check_python; then
    log_error "Python 3 is required but not found."
    exit 1
  fi

  # Install the package
  if check_uv; then
    install_with_uv || install_with_pip
  else
    install_with_pip
  fi

  # Optional rc injection
  if $ENABLE_RC && [[ "$MODE" != "project" ]]; then
    local rc_files
    rc_files=( $(detect_rc_files) )
    local rc_target="${rc_files[0]:-$HOME/.zshrc}"
    remove_existing_block "$rc_target"
    append_function_block "$rc_target"
    log_info "$(t "Injected ccm/ccc functions into:" "已写入 ccm/ccc 函数到：") $rc_target"
  fi

  echo ""
  log_info "$(t "✅ Installation complete" "✅ 安装完成")"
  echo ""

  echo "$(t "Next steps:" "下一步：")"
  if $ENABLE_RC; then
    echo "  source ~/.zshrc $(t "(or ~/.bashrc)" "（或 ~/.bashrc）")"
    echo "  ccm status"
  else
    echo "  eval \"\$(ccm deepseek)\"   # $(t "Apply env to current shell" "在当前 shell 生效")"
    echo "  ccc deepseek              # $(t "Switch + launch Claude Code" "切换并启动 Claude Code")"
  fi
}

main "$@"

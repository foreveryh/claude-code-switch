#!/usr/bin/env bash
################################################################################
# Claude Code Model Switcher - Quick Install Script
#
# One-command installation from GitHub:
#   curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
################################################################################

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

GITHUB_REPO="${GITHUB_REPO:-foreveryh/claude-code-switch}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"
TEMP_DIR=""

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}" >&2; }
log_step() { echo -e "${CYAN}==>${NC} $*"; }

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

check_requirements() {
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    log_error "curl or wget is required"
    exit 1
  fi
}

create_temp_dir() {
  TEMP_DIR=$(mktemp -d -t ccm-install.XXXXXX) || {
    log_error "Failed to create temporary directory"
    exit 1
  }
  chmod 700 "$TEMP_DIR"
}

download_file() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dest" "$url"
  else
    wget -qO "$dest" "$url"
  fi
}

main() {
  log_step "Preparing quick install..."
  check_requirements
  create_temp_dir

  log_step "Downloading installer..."
  download_file "$GITHUB_RAW_URL/install.sh" "$TEMP_DIR/install.sh" || {
    log_error "Failed to download install.sh"
    exit 1
  }
  chmod +x "$TEMP_DIR/install.sh"

  log_step "Running installer..."
  GITHUB_REPO="$GITHUB_REPO" GITHUB_BRANCH="$GITHUB_BRANCH" bash "$TEMP_DIR/install.sh" "$@"

  log_success "Quick install completed"
}

main "$@"

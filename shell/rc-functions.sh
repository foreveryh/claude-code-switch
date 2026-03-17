# CCM Shell Functions
# Add this to your .zshrc or .bashrc to enable ccm/ccc commands
#
# Installation:
#   source /path/to/rc-functions.sh
#
# Or add this line to your rc file:
#   [ -f /path/to/rc-functions.sh ] && source /path/to/rc-functions.sh

# >>> ccm function begin >>>
# CCM: Claude Code Model Switcher
# Ensure no alias/function clashes
unalias ccm 2>/dev/null || true
unset -f ccm 2>/dev/null || true

ccm() {
  # All commands use eval to apply environment variables
  case "$1" in
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg"|"save-account"|"switch-account"|"list-accounts"|"delete-account"|"current-account"|"debug-keychain"|"project"|"user")
      # These commands don't need eval, execute directly
      python3 -m ccm "$@"
      ;;
    *)
      # All other commands (model switching) use eval to set environment variables
      eval "$(python3 -m ccm "$@")"
      ;;
  esac
}

# CCC: Claude Code Commander - switch model and launch Claude Code
unalias ccc 2>/dev/null || true
unset -f ccc 2>/dev/null || true

ccc() {
  if [[ $# -eq 0 ]]; then
    cat <<'EOF'
Usage: ccc <model> [region|variant] [claude-options]
       ccc open <provider> [claude-options]

Examples:
  ccc deepseek                              # Launch with DeepSeek
  ccc kimi china                            # Launch with Kimi (China region)
  ccc open glm                              # Launch with OpenRouter (GLM)
  ccc claude --dangerously-skip-permissions # Pass options to Claude Code

Available models:
  deepseek, ds        DeepSeek
  kimi, kimi2         Kimi (Moonshot AI)
  glm, glm5           Zhipu GLM
  qwen                Alibaba Qwen
  minimax, mm         MiniMax
  seed, doubao        Doubao/Seed (ARK)
  stepfun             StepFun
  claude, sonnet, s   Claude (Official Anthropic)

OpenRouter:
  open <provider>     Use via OpenRouter
EOF
    return 1
  fi

  # Launch the Python module
  python3 -m ccm.cli.launcher "$@"
}
# <<< ccm function end <<<

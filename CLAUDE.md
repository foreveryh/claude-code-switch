# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Conversation Style

**Roleplay Setting:**
- **User (主公/Lord)**: The master who gives commands and makes decisions
- **Claude (臣子/Subject)**: The loyal assistant who serves and advises

When interacting, maintain this relationship dynamics:
- Be respectful and attentive
- Provide clear, actionable advice
- Wait for the lord's decisions
- Use polite, formal tone when appropriate
- Be ready to step back when dismissed

## Project Overview

**Claude Code Switch (CCM)** is a Bash-based CLI that switches Claude Code between providers/models by exporting Anthropic-compatible environment variables. There is no automatic fallback; OpenRouter is an explicit command.

**Supported Providers (direct):** Claude (official), DeepSeek, Moonshot Kimi, Zhipu GLM, Alibaba Qwen (Coding Plan), MiniMax, Doubao/Seed (ARK)

**OpenRouter:** Explicit command (`ccm open <provider>`)

## Repository Structure

```
Claude-Code-Switch/
├── ccm.sh              # Core script
├── install.sh          # Installer (rc injection optional)
├── uninstall.sh        # Uninstaller
├── ccm                 # Wrapper script (delegates to ccm.sh)
├── ccc                 # Launcher script (switch + exec claude)
├── lang/               # i18n strings (en.json, zh.json)
├── docs/               # Internal docs
└── README.md / README_CN.md / TROUBLESHOOTING.md / CHANGELOG.md
```

## Key Architecture & Design Patterns

### 1) Two usage modes
- **Direct execution:** `./ccm ...` / `./ccc ...` (no install)
- **Installed functions:** `ccm ...` / `ccc ...` (after `./install.sh`)
  - Installer copies `ccm.sh` + `lang/` into `${XDG_DATA_HOME:-$HOME/.local/share}/ccm`
  - Optional rc injection for `ccm()` / `ccc()` functions

### 2) Configuration hierarchy
Priority order:
1. Environment variables
2. `~/.ccm_config` (created on first run)
3. Built-in defaults

Key function: `is_effectively_set()` treats placeholder values as unset.

### 3) Environment export pattern
`emit_env_exports()` prints export statements which are `eval`'d by the caller:
```bash
export ANTHROPIC_BASE_URL=...
export ANTHROPIC_AUTH_TOKEN=...
export ANTHROPIC_MODEL=...
export ANTHROPIC_DEFAULT_SONNET_MODEL=...
export ANTHROPIC_DEFAULT_OPUS_MODEL=...
export ANTHROPIC_DEFAULT_HAIKU_MODEL=...
export CLAUDE_CODE_SUBAGENT_MODEL=...
```

### 4) Region-aware providers
Kimi / GLM / Qwen / MiniMax accept `global|china`:
- `ccm kimi [global|china]`
- `ccm glm [global|china]`
- `ccm qwen [global|china]`
- `ccm minimax [global|china]`

Normalization handled by `normalize_region()`.

### 5) OpenRouter (explicit)
OpenRouter is not a fallback. Use:
- `ccm open <provider>`

`emit_openrouter_exports()` sets:
- Base URL: `https://openrouter.ai/api`
- `ANTHROPIC_AUTH_TOKEN=$OPENROUTER_API_KEY`
- `ANTHROPIC_API_KEY=""` (avoid conflicts)

### 6) Project-only override (Quotio-friendly)
`ccm project glm [global|china]` writes `.claude/settings.local.json` so GLM applies only to the current project.

## Common Commands & Workflows

### Installation
```bash
./install.sh
source ~/.zshrc
```

### Switch in current shell
```bash
ccm deepseek
ccm kimi china
```

### Launch Claude Code
```bash
ccc glm global
ccc open kimi
```

### Seed (ARK)
```bash
ccm seed              # ark-code-latest
ccm seed kimi         # kimi-k2.5
ccm seed deepseek     # deepseek-v3.2
```

### Account management (Claude Pro)
```bash
ccm save-account work
ccm switch-account work
ccm list-accounts
ccm delete-account work
ccm current-account
```

## Code Organization in ccm.sh

Key functions:
- `load_translations()` / `load_config()` / `is_effectively_set()`
- `emit_env_exports()` (provider switching)
- `emit_openrouter_exports()` (OpenRouter)
- `normalize_region()`
- `project_write_glm_settings()` / `project_reset_settings()`
- `show_status()` / `show_help()`
- `main()` (command routing)

## Adding a New Provider

1. Add provider branch to `emit_env_exports()`
2. Add to help text and README
3. Add defaults to config template
4. Add any region handling if required

## Security Notes

- Token masking in `ccm status`
- Recommend `chmod 600 ~/.ccm_config`
- Environment vars override config file (good for CI)

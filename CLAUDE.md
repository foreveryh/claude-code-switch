# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Claude Code Model Switcher (CCM)** is a utility for developers to quickly switch between multiple AI service providers and models in Claude Code IDE. It's a pure Bash implementation (~970 lines) that provides intelligent fallback mechanisms between official APIs and PPINFRA backup service.

**Supported Providers:** Anthropic Claude, DeepSeek, Moonshot KIMI, Zhipu GLM, Alibaba Qwen, MeiTuan LongCat

## Repository Structure

```
Claude-Code-Switch/
├── ccm.sh              # Core script (~970 lines) - Main implementation
├── install.sh          # Installer - Sets up shell functions
├── uninstall.sh        # Uninstaller - Removes shell functions
├── ccm                 # Wrapper script - Delegates to ccm.sh
├── ccc                 # Launcher script - One-command launcher for Claude Code
├── test_install.sh     # Installation test script
├── lang/               # Multi-language support (en.json, zh.json)
├── docs/               # Internal documentation
└── README.md / README_CN.md / TROUBLESHOOTING.md / CHANGELOG.md
```

## Key Architecture & Design Patterns

### 1. **Command Structure: Two Deployment Models**

- **Direct execution:** `./ccc deepseek` / `./ccm deepseek` (no installation)
- **Installed functions:** `ccc deepseek` / `ccm deepseek` (after `./install.sh`)
  - Installer copies `ccm.sh` and `lang/` to `${XDG_DATA_HOME:-$HOME/.local/share}/ccm`
  - Injects shell functions into `~/.zshrc` or `~/.bashrc`
  - Idempotent: safe to run multiple times

### 2. **Smart Configuration Hierarchy**

Priority order for configuration values:
1. Environment variables (e.g., `DEEPSEEK_API_KEY`)
2. `~/.ccm_config` file (created on first run)
3. Built-in defaults (e.g., experience keys, zero-config support)

Key function: `is_effectively_set()` checks if value is valid (not placeholder like "sk-your-...").

### 3. **Fallback Mechanism**

Each model follows this pattern:
- Check for official API key in env var → use official API
- If missing, fall back to PPINFRA service (if available)
- Special handling: DeepSeek has experience key for zero-config PPINFRA access

### 4. **Environment Setup Pattern**

`emit_env_exports()` function outputs export statements that are `eval`'d to set variables:
```bash
export ANTHROPIC_BASE_URL=...
export ANTHROPIC_AUTH_TOKEN=...
export ANTHROPIC_MODEL=...
export ANTHROPIC_SMALL_FAST_MODEL=...
export API_TIMEOUT_MS=600000  # Longer timeout for fallbacks
```

## Common Commands & Workflows

### Installation & Setup

```bash
# Install (one-time setup)
chmod +x install.sh ccm.sh
./install.sh
source ~/.zshrc

# Uninstall
./uninstall.sh
```

### Model Switching Workflows

```bash
# Method 1: One-command launcher
ccc deepseek              # Launch Claude Code with DeepSeek immediately

# Method 2: Switch in current shell
ccm deepseek              # Output export statements
eval "$(ccm deepseek)"    # Apply to current shell

# Method 3: Direct execution (no install)
./ccc deepseek
./ccm deepseek
```

### Model Shortcuts

```bash
ccm deepseek / ccm ds    # DeepSeek
ccm kimi / ccm kimi2     # KIMI2
ccm glm / ccm glm4       # GLM
ccm qwen                 # Qwen
ccm longcat / ccm lc     # LongCat
ccm claude / ccm sonnet  # Claude Sonnet
ccm opus / ccm o         # Claude Opus
ccm haiku / ccm h        # Claude Haiku
```

### Management Commands

```bash
ccm status / ccm st      # Show current config (tokens masked)
ccm help / ccm -h        # Show help
ccm config / ccm cfg     # Edit configuration in editor
ccm env <model>          # Output env exports only (no launcher)
ccm pp <model>           # Switch to PPINFRA version of model
```

### Testing & Verification

```bash
# Test installation
./test_install.sh

# Verify setup
ccm status               # Check current configuration
echo $ANTHROPIC_BASE_URL # Verify env var set correctly
cat ~/.ccm_config        # View config file
```

## Development Workflow

### Code Organization in ccm.sh

Key functions and their line ranges (approximately):
- `load_translations()` - Load i18n from JSON
- `load_config()` - Load env vars + config file
- `is_effectively_set()` - Validate config values
- `mask_token()` - Mask secrets for status output
- `switch_to_*()` - Model-specific functions (deepseek, kimi, glm, qwen, longcat, claude, opus, haiku)
- `switch_to_ppinfra()` - PPINFRA service routing
- `show_status()` - Display masked configuration
- `show_help()` - Display help information
- `edit_config()` - Open config in editor (cursor/code/vim/nano)
- `emit_env_exports()` - Generate export statements
- `main()` - Entry point with argument parsing

### Adding a New Model

Steps to add a new model (e.g., "newmodel"):
1. Add to `switch_to_newmodel()` function in `ccm.sh`
2. Add translations to `lang/en.json` and `lang/zh.json`
3. Handle in `main()` function's case statement
4. Add config template entries to config file generation
5. Document in README.md with example usage
6. Update CHANGELOG.md

### Configuration File Template

Location: `~/.ccm_config`
- Created automatically on first run
- Contains API key placeholders and model overrides
- Environment variables override config file values
- Recommended permissions: `chmod 600 ~/.ccm_config`

## Supported Models & API Endpoints

| Model | Official API | PPINFRA Alt | Base URL |
|-------|-------------|-------------|----------|
| Claude Sonnet 4.5 | claude-sonnet-4-5-20250929 | N/A | Anthropic default |
| Claude Opus 4.1 | claude-opus-4-1-20250805 | N/A | Anthropic default |
| Claude Haiku 4.5 | claude-haiku-4-5 | N/A | Anthropic default |
| DeepSeek | deepseek-chat | deepseek/deepseek-v3.2-exp | https://api.deepseek.com/anthropic |
| KIMI2 | kimi-k2-turbo-preview | kimi-k2-turbo-preview | https://api.moonshot.cn/anthropic |
| GLM | glm-4.7 | zai-org/glm-4.7 | https://open.bigmodel.cn/api/anthropic |
| Qwen | qwen3-max | qwen3-next-80b-a3b-thinking | https://dashscope.aliyuncs.com/... |
| LongCat | LongCat-Flash-Thinking | N/A | https://api.longcat.chat/anthropic |

## Current Development

**Current Branch:** `feat/haiku-4-5`
**Latest:** Added Claude Haiku 4.5 support (v2.1.0, Oct 17)
- Model: `claude-haiku-4-5`
- Shortcuts: `ccm haiku` or `ccm h`
- Config overrides: `HAIKU_MODEL`, `HAIKU_SMALL_FAST_MODEL`

## Important Implementation Details

### Multi-Language Support

- Language files: `lang/en.json` (66 translation keys) and `lang/zh.json`
- Loaded dynamically based on system locale via `load_translations()`
- Falls back to English if translation missing
- Language override: Set `CCM_LANGUAGE=en` or `CCM_LANGUAGE=zh`

### Zero-Config Support

- Built-in DeepSeek 3.1 experience key for PPINFRA service
- Allows immediate testing without API key configuration
- Located in `ccm.sh` - allows `ccm pp deepseek` to work out-of-box

### Security Notes

- Token masking: Status output shows only first 4 + last 4 characters
- Full tokens never printed in plaintext
- Config file should be readable only by user: `chmod 600 ~/.ccm_config`
- Environment variables take precedence over config file (better for CI/CD)

### Special Integration: Qwen/DashScope

- Uses Alibaba Cloud endpoint: `https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy`
- No custom routing needed - directly uses DashScope API

## Debugging Tips

```bash
# Check version and script location
type ccm                  # Show function/script path
head -10 ccm.sh          # Check version comment

# Trace execution
bash -x ./ccm deepseek   # Run with debug output

# Verify environment
ccm status               # Show masked config
cat ~/.ccm_config        # View config file
env | grep ANTHROPIC     # Check all ANTHROPIC_* vars

# Test without launching Claude Code
ccm env deepseek         # Output exports only, don't launch
eval "$(ccm env deepseek)" && env | grep ANTHROPIC
```

## Documentation References

- **User Guide:** README.md (16.5KB) / README_CN.md
- **Troubleshooting:** TROUBLESHOOTING.md (7.3KB)
- **PPINFRA Guide:** PPINFRA_USAGE.md (4.7KB)
- **Version History:** CHANGELOG.md

# Claude Code Switch (ccm)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/foreveryh/claude-code-switch.svg)](https://github.com/foreveryh/claude-code-switch/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/foreveryh/claude-code-switch.svg)](https://github.com/foreveryh/claude-code-switch/issues)

Switch Claude Code between AI providers with one command.

[中文文档](README_CN.md)

## Quick Start

```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash

# 2. Reload shell
source ~/.zshrc  # or ~/.bashrc

# 3. Configure your API keys
ccm config

# 4. Switch and use
ccm glm              # switch to GLM
ccc glm global       # switch + launch Claude Code

# Advanced: User-level settings (highest priority, overrides everything)
ccm user glm global      # Set GLM as default for all projects
ccm user reset           # Restore environment variable control

# Advanced: Project-only override
ccm project glm china    # GLM for this project only

# Advanced: Multiple Claude Pro accounts
ccm save-account work    # save current account
ccm switch-account work  # switch to saved account
```

---

## Installation

### Quick Install (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
source ~/.zshrc  # or ~/.bashrc
```

### Local Install
```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
./install.sh
source ~/.zshrc
```

### Install Modes

| Mode | Command | Use Case |
|------|---------|----------|
| **User** (default) | `./install.sh` | Personal use, available everywhere |
| **System** | `./install.sh --system` | Shared machine, all users |
| **Project** | `./install.sh --project` | Project-specific, isolated setup |

### Install Options
```bash
./install.sh --no-rc           # Skip shell rc injection
./install.sh --cleanup-legacy  # Remove old installation
./install.sh --help            # Show all options
```

### Uninstall
```bash
./uninstall.sh
```

---

## First-Time Setup

### 1. Configure API Keys
```bash
ccm config
```

This opens `~/.ccm_config` in your editor. Add your API keys:

```bash
# Required for each provider you want to use
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=...
GLM_API_KEY=...
QWEN_API_KEY=...
MINIMAX_API_KEY=...
ARK_API_KEY=...           # For Doubao/Seed
OPENROUTER_API_KEY=...    # For OpenRouter
CLAUDE_API_KEY=...        # Optional, for Claude API (vs subscription)
```

### 2. Verify Setup
```bash
ccm status    # Check current configuration
```

---

## Basic Usage

### Switch Provider (in current shell)
```bash
ccm glm global        # GLM global (default)
ccm glm china         # GLM China
ccm deepseek          # DeepSeek
ccm kimi global       # Kimi global
ccm kimi china        # Kimi China
ccm qwen global       # Qwen global
ccm minimax           # MiniMax
ccm seed              # Doubao/Seed
ccm claude            # Claude official
```

### Switch + Launch Claude Code
```bash
ccc glm global        # Switch to GLM global, then launch
ccc glm china         # Switch to GLM China, then launch
ccc open glm          # Via OpenRouter
```

### Check Status
```bash
ccm status             # Show current model and API key status
ccm current-account    # Show current Claude Pro account
```

### Get Help
```bash
ccm help               # Show all commands
ccc                    # Show ccc usage (no args)
```

---

## Providers Reference

### Direct Providers (API Key Required)

| Provider | Command | Region | Base URL |
|----------|---------|--------|----------|
| GLM | `ccm glm [global\|china]` | global (default) | `api.z.ai/api/anthropic` |
| | | china | `open.bigmodel.cn/api/anthropic` |
| DeepSeek | `ccm deepseek` | - | `api.deepseek.com/anthropic` |
| Kimi | `ccm kimi [global\|china]` | global (default) | `api.moonshot.ai/anthropic` |
| | | china | `api.moonshot.cn/anthropic` |
| Qwen | `ccm qwen [global\|china]` | global (default) | `coding-intl.dashscope.aliyuncs.com/apps/anthropic` |
| | | china | `coding.dashscope.aliyuncs.com/apps/anthropic` |
| MiniMax | `ccm minimax [global\|china]` | global (default) | `api.minimax.io/anthropic` |
| | | china | `api.minimaxi.com/anthropic` |
| Seed/Doubao | `ccm seed [variant]` | - | `ark.cn-beijing.volces.com/api/coding` |
| Claude | `ccm claude` | - | `api.anthropic.com` |

> **GLM Coding Plan**: Get a subscription at [bigmodel.cn/glm-coding](https://www.bigmodel.cn/glm-coding?ic=5XMIOZPPXB)

### Seed Variants
```bash
ccm seed              # ark-code-latest (default)
ccm seed doubao       # doubao-seed-code
ccm seed glm          # glm-5
ccm seed deepseek     # deepseek-v3.2
ccm seed kimi         # kimi-k2.5
```

### OpenRouter
```bash
ccm open              # Show help
ccm open glm          # GLM via OpenRouter
ccm open claude       # Claude via OpenRouter
ccm open deepseek     # DeepSeek via OpenRouter
```

---

## Advanced Features

### Claude Pro Account Management
Switch between multiple Claude Pro subscriptions:

```bash
# Save current logged-in account
ccm save-account work

# Switch to saved account
ccm switch-account work

# List all saved accounts
ccm list-accounts

# Show current account
ccm current-account

# Delete saved account
ccm delete-account work
```

### User-Level Settings (Highest Priority)
Write settings directly to `~/.claude/settings.json`. This overrides everything including environment variables and is useful when you have other tools (like Quotio) that also modify this file.

```bash
# Set provider at user level
ccm user glm global      # GLM global for all projects
ccm user glm china       # GLM China for all projects
ccm user deepseek        # DeepSeek for all projects
ccm user claude          # Claude official for all projects

# Reset to environment variable control
ccm user reset           # Remove ccm settings, use env vars instead
```

**When to use:**
- You have Quotio or another proxy that sets `~/.claude/settings.json`
- You want a persistent default that survives shell restarts
- Environment variables are being overridden by something else

### Project-Only Override
Override settings for a specific project (keeps global settings intact):

```bash
# In your project directory
ccm project glm global    # Use GLM for this project only
ccm project glm china     # Use GLM China for this project
ccm project reset         # Remove project override
```

This creates/removes `.claude/settings.local.json` in the current project.

### Launch with Account
```bash
ccc work                  # Switch to 'work' account, then launch
ccc claude:personal       # Switch to 'personal' account + use Claude
```

---

## Configuration

### Priority Order (highest to lowest)
1. `~/.claude/settings.json` (env section) - User-level settings
2. `.claude/settings.local.json` - Project-level settings
3. Environment variables
4. `~/.ccm_config` file

### Config File Location
```
~/.ccm_config
```

### Full Config Example
```bash
# Language (en or zh)
CCM_LANGUAGE=en

# API Keys (required for each provider)
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=...
GLM_API_KEY=...
QWEN_API_KEY=...
MINIMAX_API_KEY=...
ARK_API_KEY=...
OPENROUTER_API_KEY=...
CLAUDE_API_KEY=...

# Model ID Overrides (optional)
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
GLM_MODEL=glm-5
MINIMAX_MODEL=MiniMax-M2.5
SEED_MODEL=ark-code-latest
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-6
HAIKU_MODEL=claude-haiku-4-5-20251001
```

---

## Without RC Injection

If you installed with `--no-rc` or want to use from cloned repo:

```bash
# Switch model (apply env vars to current shell)
eval "$(ccm glm global)"
eval "$(./ccm.sh glm china)"

# Or use the wrapper scripts directly
./ccm glm global         # Just prints exports
./ccc glm china          # Switch + launch
```

---

## Notes

- **7 env vars exported per provider**: `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`
- **Claude official**: Uses your Claude Code subscription by default, or `CLAUDE_API_KEY` if set
- **OpenRouter**: Requires explicit `ccm open <provider>` command
- **Project override**: Only affects the current project via `.claude/settings.local.json`

---

## Contributing

Contributions are welcome! Here's how you can help:

### Report Issues
Found a bug or have a feature request? [Open an issue](https://github.com/foreveryh/claude-code-switch/issues).

### Submit Code
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

### Development
```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
./ccm.sh help    # Test locally without installing
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Acknowledgments

This tool is inspired by the need to easily switch between AI providers while using Claude Code. Thanks to all contributors and the open-source community.

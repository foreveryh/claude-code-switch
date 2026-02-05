# Claude Code Switch (ccm)

A simple CLI to switch Claude Code between providers and models with predictable, explicit configuration.

[中文文档](README_CN.md)

## Quick Start

```bash
# 1) Install
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash

# 2) Reload shell
source ~/.zshrc  # or ~/.bashrc

# 3) Configure keys
ccm config

# 4) Switch provider
ccm kimi
ccm qwen china

# 5) Launch Claude Code with one command
ccc glm global
```

## Install

### Quick install (recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
```

### Local install
```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
./install.sh
```

By default the installer injects `ccm()` / `ccc()` into your shell rc file so you can run `ccm <provider>` directly.

If you **do not** want rc injection:
```bash
./install.sh --no-rc
```

### Uninstall
```bash
./uninstall.sh
```

## Usage

### Switch in current shell
If you installed with rc injection, just run:
```bash
ccm deepseek
ccm kimi china
```

If you are running from the repo without rc injection:
```bash
eval "$(./ccm deepseek)"
```

### Launch Claude Code
```bash
ccc kimi           # switch model then launch Claude Code
ccc qwen global
ccc open kimi      # OpenRouter
```

### Providers (direct)
All providers below require their own API key, except **Claude (official)** which can use your Claude Code subscription (or API key if configured).

- **DeepSeek**
  - Command: `ccm deepseek`
  - Base URL: `https://api.deepseek.com/anthropic`
  - Models: `deepseek-chat` (default)
  - Default models for Claude Code: `deepseek/deepseek-v3.2`

- **Kimi** (default: global)
  - Command: `ccm kimi [global|china]`
  - Global Base URL: `https://api.moonshot.ai/anthropic`
  - China Base URL: `https://api.moonshot.cn/anthropic`
  - Global model: `kimi-for-coding`
  - China model: `kimi-k2.5`

- **Qwen (Coding Plan)** (default: global)
  - Command: `ccm qwen [global|china]`
  - Global Base URL: `https://coding-intl.dashscope.aliyuncs.com/apps/anthropic`
  - China Base URL: `https://coding.dashscope.aliyuncs.com/apps/anthropic`
  - Main model: `qwen3-max-2026-01-23`
  - Small model: `qwen3-coder-plus`
  - Default models: OPUS/SONNET = main, HAIKU = small

- **GLM** (default: global)
  - Command: `ccm glm [global|china]`
  - Global Base URL: `https://api.z.ai/api/anthropic`
  - China Base URL: `https://open.bigmodel.cn/api/anthropic`
  - Model: `glm-4.7`

- **MiniMax** (default: global)
  - Command: `ccm minimax [global|china]`
  - Global Base URL: `https://api.minimax.io/anthropic`
  - China Base URL: `https://api.minimaxi.com/anthropic`
  - Model: `MiniMax-M2.1`
  - Uses `API_TIMEOUT_MS=3000000` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`

- **Doubao / Seed (ARK)**
  - Command: `ccm seed [doubao|glm|deepseek|kimi]`
  - Base URL: `https://ark.cn-beijing.volces.com/api/coding`
  - Default model: `ark-code-latest`
  - Variants:
    - `ccm seed doubao` → `doubao-seed-code`
    - `ccm seed glm` → `glm-4.7`
    - `ccm seed deepseek` → `deepseek-v3.2`
    - `ccm seed kimi` → `kimi-k2.5`

- **Claude (official)**
  - Command: `ccm claude`
  - No base URL (uses Anthropic default)
  - Uses your Claude Code subscription unless you set `CLAUDE_API_KEY`

### OpenRouter (explicit command, no fallback)
OpenRouter is **not** a fallback. Use it only when you call `ccm open ...`.

```bash
ccm open                # prints supported providers and usage
ccm open kimi
```

Supported providers:
- `claude` (default)
- `deepseek`
- `kimi`
- `glm`
- `qwen`
- `minimax`

OpenRouter defaults:
- Base URL: `https://openrouter.ai/api`
- Uses `OPENROUTER_API_KEY`
- Sets `ANTHROPIC_API_KEY=""` to avoid conflicts

### Project override (Quotio-friendly)
```bash
ccm project glm [global|china]
ccm project reset
```
This writes/removes `.claude/settings.local.json` in the current project so you can keep global settings (e.g. Quotio) while forcing GLM only in one project.

### Status & config
```bash
ccm status
ccm config
```

### Claude Pro account management
```bash
ccm save-account work
ccm switch-account work
ccm list-accounts
ccm delete-account work
ccm current-account
```

## Configuration

Configuration priority:
1) Environment variables
2) `~/.ccm_config`

Edit config:
```bash
ccm config
```

Example `~/.ccm_config`:
```bash
# API keys
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=...
GLM_API_KEY=...
QWEN_API_KEY=...
MINIMAX_API_KEY=...
ARK_API_KEY=...
OPENROUTER_API_KEY=...

# Optional overrides
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-for-coding
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
QWEN_SMALL_FAST_MODEL=qwen3-coder-plus
GLM_MODEL=glm-4.7
MINIMAX_MODEL=MiniMax-M2.1
SEED_MODEL=ark-code-latest
CLAUDE_MODEL=claude-sonnet-4-5-20250929
# These set default model names used by Claude Code (ANTHROPIC_DEFAULT_*):
OPUS_MODEL=claude-opus-4-5-20251101
HAIKU_MODEL=claude-haiku-4-5-20251001
```

## Notes

- If you do not use rc injection, run `eval "$(./ccm <provider>)"` to apply env vars (or `eval "$(ccm <provider>)"` if `ccm` is on PATH).
- `ccm open` prints supported providers and correct usage.
- `ccm project glm` only affects the current project via `.claude/settings.local.json`.

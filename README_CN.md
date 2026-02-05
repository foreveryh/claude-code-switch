# Claude Code Switch (ccm)

一个简单、清晰的 Claude Code 模型/提供商切换工具，所有配置显式可控。

[English](README.md)

## 快速开始

```bash
# 1) 安装
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash

# 2) 重新加载 shell
source ~/.zshrc  # 或 ~/.bashrc

# 3) 配置密钥
ccm config

# 4) 切换模型
ccm kimi
ccm qwen china

# 5) 一键启动 Claude Code
ccc glm global
```

## 安装

### 快速安装（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
```

### 本地安装
```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
./install.sh
```

默认会注入 `ccm()` / `ccc()` 到你的 shell rc 文件，这样可以直接运行 `ccm <provider>`。

如果**不想注入 rc**：
```bash
./install.sh --no-rc
```

### 卸载
```bash
./uninstall.sh
```

## 使用方式

### 在当前 shell 中切换
如果已注入 rc：
```bash
ccm deepseek
ccm kimi china
```

如果直接运行仓库脚本：
```bash
eval "$(./ccm deepseek)"
```

### 一键启动 Claude Code
```bash
ccc kimi           # 切换模型后启动
ccc qwen global
ccc open kimi      # OpenRouter
```

### Provider（直连）
以下 provider 均需要你自己的 API Key，**Claude 官方**可直接使用 Claude Code 订阅（或配置 `CLAUDE_API_KEY`）。

- **DeepSeek**
  - 命令：`ccm deepseek`
  - Base URL：`https://api.deepseek.com/anthropic`
  - 模型：`deepseek-chat`（默认）
  - Claude Code 默认三模型：`deepseek/deepseek-v3.2`

- **Kimi**（默认 global）
  - 命令：`ccm kimi [global|china]`
  - Global Base URL：`https://api.moonshot.ai/anthropic`
  - China Base URL：`https://api.moonshot.cn/anthropic`
  - Global 模型：`kimi-for-coding`
  - China 模型：`kimi-k2.5`

- **Qwen（Coding Plan）**（默认 global）
  - 命令：`ccm qwen [global|china]`
  - Global Base URL：`https://coding-intl.dashscope.aliyuncs.com/apps/anthropic`
  - China Base URL：`https://coding.dashscope.aliyuncs.com/apps/anthropic`
  - 主模型：`qwen3-max-2026-01-23`
  - 小模型：`qwen3-coder-plus`
  - 默认三模型：OPUS/SONNET = 主模型，HAIKU = 小模型

- **GLM**（默认 global）
  - 命令：`ccm glm [global|china]`
  - Global Base URL：`https://api.z.ai/api/anthropic`
  - China Base URL：`https://open.bigmodel.cn/api/anthropic`
  - 模型：`glm-4.7`

- **MiniMax**（默认 global）
  - 命令：`ccm minimax [global|china]`
  - Global Base URL：`https://api.minimax.io/anthropic`
  - China Base URL：`https://api.minimaxi.com/anthropic`
  - 模型：`MiniMax-M2.1`
  - 默认设置 `API_TIMEOUT_MS=3000000` 与 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`

- **豆包 / Seed（ARK）**
  - 命令：`ccm seed [doubao|glm|deepseek|kimi]`
  - Base URL：`https://ark.cn-beijing.volces.com/api/coding`
  - 默认模型：`ark-code-latest`
  - 子模型：
    - `ccm seed doubao` → `doubao-seed-code`
    - `ccm seed glm` → `glm-4.7`
    - `ccm seed deepseek` → `deepseek-v3.2`
    - `ccm seed kimi` → `kimi-k2.5`

- **Claude 官方**
  - 命令：`ccm claude`
  - 不设置 Base URL（默认官方）
  - 默认使用 Claude Code 订阅（或配置 `CLAUDE_API_KEY`）

### OpenRouter（显式命令，不做兜底）
OpenRouter 不是兜底方案，只会在你调用 `ccm open ...` 时生效。

```bash
ccm open                # 输出支持的 provider 与用法
ccm open kimi
```

支持的 provider：
- `claude`（默认）
- `deepseek`
- `kimi`
- `glm`
- `qwen`
- `minimax`

OpenRouter 默认行为：
- Base URL：`https://openrouter.ai/api`
- 使用 `OPENROUTER_API_KEY`
- 会设置 `ANTHROPIC_API_KEY=""` 避免冲突

### 项目级覆盖（Quotio 友好）
```bash
ccm project glm [global|china]
ccm project reset
```
会在当前项目写入/移除 `.claude/settings.local.json`，只影响该项目。

### 状态 & 配置
```bash
ccm status
ccm config
```

### Claude Pro 多账号管理
```bash
ccm save-account work
ccm switch-account work
ccm list-accounts
ccm delete-account work
ccm current-account
```

## 配置

优先级：
1) 环境变量
2) `~/.ccm_config`

编辑配置：
```bash
ccm config
```

示例 `~/.ccm_config`：
```bash
# API keys
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=...
GLM_API_KEY=...
QWEN_API_KEY=...
MINIMAX_API_KEY=...
ARK_API_KEY=...
OPENROUTER_API_KEY=...

# 可选覆盖
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-for-coding
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
QWEN_SMALL_FAST_MODEL=qwen3-coder-plus
GLM_MODEL=glm-4.7
MINIMAX_MODEL=MiniMax-M2.1
SEED_MODEL=ark-code-latest
CLAUDE_MODEL=claude-sonnet-4-5-20250929
# 这些用于设置 Claude Code 默认模型（ANTHROPIC_DEFAULT_*）：
OPUS_MODEL=claude-opus-4-5-20251101
HAIKU_MODEL=claude-haiku-4-5-20251001
```

## 备注

- 若不使用 rc 注入，请使用 `eval "$(./ccm <provider>)"` 应用环境变量（或 `eval "$(ccm <provider>)"`，前提是 `ccm` 在 PATH 中）。
- `ccm open` 会提示支持的 provider 与正确用法。
- `ccm project glm` 只影响当前项目（`.claude/settings.local.json`）。

# CCM Python 版本 - 使用指南

CCM (Claude Code 模型切换器) 已迁移到 Python，以提供更好的可维护性、测试覆盖率和跨平台支持。

## 安装

### 方式 1: 使用 uv（推荐）

```bash
# 从源码安装
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
uv tool install .

# 或直接从 GitHub 安装
uv tool install git+https://github.com/foreveryh/claude-code-switch.git
```

### 方式 2: 使用 pip

```bash
pip install -e .
```

### 方式 3: Shell 函数注入（Eval 模式）

要获得完整的 eval 体验，可以 source shell 函数：

```bash
# 添加到你的 .zshrc 或 .bashrc
source /path/to/claude-code-switch/shell/rc-functions.sh
```

或运行安装器：

```bash
./install.sh
source ~/.zshrc  # 或 ~/.bashrc
```

## 基本用法

### 切换 Provider（Eval 模式）

使用 CCM 的主要方式是 eval 模式：

```bash
# 切换到 DeepSeek
eval "$(ccm deepseek)"

# 切换到 Kimi（中国区）
eval "$(ccm kimi china)"

# 切换到 GLM（全球区）
eval "$(ccm glm global)"

# 切换到 Claude（官方 Anthropic）
eval "$(ccm claude)"
```

### 启动 Claude Code（ccc 命令）

`ccc` 命令会切换 provider 并启动 Claude Code：

```bash
# 使用 DeepSeek 启动
ccc deepseek

# 使用 Kimi 中国区启动
ccc kimi china

# 使用 GLM 全球区启动并传递选项
ccc glm global --dangerously-skip-permissions

# 使用 OpenRouter 启动
ccc open kimi
```

## 可用的 Provider

### 直接 Provider

| Provider | 别名 | 区域支持 | 默认模型 |
|----------|------|----------|----------|
| `deepseek` | `ds` | 无 | deepseek-chat |
| `kimi` | `kimi2` | global, china | kimi-k2.5 |
| `glm` | `glm5` | global, china | glm-5 |
| `qwen` | - | global, china | qwen3-max-2026-01-23 |
| `minimax` | `mm` | global, china | MiniMax-M2.5 |
| `seed` | `doubao` | 变体模式 | ark-code-latest |
| `stepfun` | - | 无 | step-3.5-flash |
| `claude` | `sonnet`, `s` | 无 | claude-sonnet-4-5-20250929 |

### Seed 变体

`seed` provider 支持不同的模型变体：

```bash
ccm seed              # 默认: ark-code-latest
ccm seed doubao       # doubao-seed-code
ccm seed glm          # glm-5
ccm seed deepseek     # deepseek-v3.2
ccm seed kimi         # kimi-k2.5
```

### OpenRouter 模式

通过 OpenRouter 访问任意 provider：

```bash
ccm open glm
ccm open kimi
ccm open deepseek
ccm open claude
```

## CLI 命令

### 模型切换

```bash
ccm deepseek                    # 切换到 DeepSeek
ccm kimi china                  # 切换到 Kimi 中国区
ccm glm global                  # 切换到 GLM 全球区
ccm seed kimi                   # 切换到 Seed（Kimi 变体）
ccm open deepseek               # 通过 OpenRouter 切换
ccm claude                      # 切换到 Claude（需要 Pro 订阅）
```

### 状态和配置

```bash
ccm status                      # 显示当前配置
ccm config                      # 编辑配置文件 (~/.ccm_config)
ccm help                        # 显示帮助
```

### 账号管理（Claude Pro）

管理多个 Claude Pro 账号：

```bash
ccm save-account work           # 保存当前账号为 "work"
ccm switch-account work         # 切换到 "work" 账号
ccm list-accounts               # 列出所有已保存的账号
ccm delete-account work         # 删除 "work" 账号
ccm current-account             # 显示当前账号信息
```

### 设置管理

为 Claude Code 写入持久化设置：

```bash
# 项目级（仅覆盖当前项目的用户设置）
ccm project glm global          # 为此项目使用 GLM
ccm project show                # 显示项目设置
ccm project reset               # 移除项目设置

# 用户级（最高优先级）
ccm user kimi china             # 全局使用 Kimi 中国区
ccm user show                   # 显示用户设置
ccm user reset                  # 移除用户设置
```

## 配置

### 配置文件 (~/.ccm_config)

创建或编辑 `~/.ccm_config` 添加你的 API 密钥：

```bash
# 语言 (en 或 zh)
CCM_LANGUAGE=zh

# API 密钥
DEEPSEEK_API_KEY=sk-your-deepseek-key
KIMI_API_KEY=your-kimi-key
GLM_API_KEY=your-glm-key
QWEN_API_KEY=your-qwen-key
MINIMAX_API_KEY=your-minimax-key
ARK_API_KEY=your-ark-key
STEPFUN_API_KEY=your-stepfun-key
CLAUDE_API_KEY=your-claude-key
OPENROUTER_API_KEY=your-openrouter-key

# 模型覆盖（可选）
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
GLM_MODEL=glm-5
```

### 优先级顺序

设置按以下顺序应用（优先级从高到低）：

1. **用户设置**: `~/.claude/settings.json`（通过 `ccm user`）
2. **项目设置**: `.claude/settings.local.json`（通过 `ccm project`）
3. **环境变量**: `export DEEPSEEK_API_KEY=...`
4. **配置文件**: `~/.ccm_config`
5. **内置默认值**

## 环境变量

切换后会设置以下环境变量：

| 变量 | 描述 |
|------|------|
| `ANTHROPIC_BASE_URL` | API 端点 URL |
| `ANTHROPIC_AUTH_TOKEN` | 认证令牌 |
| `ANTHROPIC_MODEL` | 使用的模型 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet 模型 |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus 模型 |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku 模型 |
| `CLAUDE_CODE_SUBAGENT_MODEL` | 子代理模型 |

## 开发

### 设置开发环境

```bash
# 克隆并进入目录
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch

# 安装开发依赖
uv sync --dev

# 运行测试
uv run pytest tests/ -v

# 运行覆盖率测试
uv run pytest tests/ --cov=src/ccm

# 类型检查
uv run mypy src/ccm

# 代码检查
uv run ruff check .
uv run ruff format .
```

### 开发模式下运行 CLI

```bash
# 运行 ccm
uv run python -m ccm status

# 运行 ccc
uv run python -m ccm.cli.launcher deepseek
```

## 从 Bash 版本迁移

Python 版本与 Bash 版本向后兼容：

| Bash 命令 | Python 等价 | 备注 |
|-----------|-------------|------|
| `ccm deepseek` | `ccm deepseek` | 相同 |
| `ccc glm global` | `ccc glm global` | 相同 |
| `ccm project glm` | `ccm project glm global` | 区域现在可选 |
| `ccm user glm` | `ccm user glm global` | 区域现在可选 |

### 主要区别

1. **安装**: 使用 `uv tool install .` 而不是 `./install.sh`
2. **配置文件**: 相同格式，相同位置
3. **账号存储**: 现在使用正确的 keychain 集成
4. **翻译**: 保留在 `lang/` 目录中

## 故障排除

### "Please configure X_API_KEY"

在配置文件或环境变量中设置 API 密钥：

```bash
# 方式 1: 环境变量
export DEEPSEEK_API_KEY=sk-your-key

# 方式 2: 配置文件
echo "DEEPSEEK_API_KEY=sk-your-key" >> ~/.ccm_config

# 方式 3: 编辑配置
ccm config
```

### Shell 函数不工作

如果 `ccm` 或 `ccc` 命令不能作为 shell 函数工作：

```bash
# 重新 source 函数
source /path/to/shell/rc-functions.sh

# 或重新安装并注入 RC
./install.sh --rc
source ~/.zshrc
```

### Claude Code 无法启动

确保已安装 Claude Code CLI：

```bash
npm install -g @anthropic-ai/claude-code
```

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                         CLI 层                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  ccm (main)  │  │ ccc (launcher)│  │   Typer/Rich    │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        核心层                              │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐    │
│  │  Config    │  │  Providers │  │  Shell Exports     │    │
│  └────────────┘  └────────────┘  └────────────────────┘    │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐    │
│  │  Keychain  │  │  Accounts  │  │  Translations      │    │
│  └────────────┘  └────────────┘  └────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                       设置层                               │
│  ┌────────────────────┐  ┌────────────────────────────┐    │
│  │ Project Settings   │  │    User Settings           │    │
│  │ .claude/settings   │  │    ~/.claude/settings.json │    │
│  └────────────────────┘  └────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

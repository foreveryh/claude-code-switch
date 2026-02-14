# Claude Code Switch (ccm)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/foreveryh/claude-code-switch.svg)](https://github.com/foreveryh/claude-code-switch/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/foreveryh/claude-code-switch.svg)](https://github.com/foreveryh/claude-code-switch/issues)

一条命令切换 Claude Code 的 AI 提供商。

[English](README.md)

## 快速开始

```bash
# 1. 安装
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash

# 2. 重新加载 shell
source ~/.zshrc  # 或 ~/.bashrc

# 3. 配置 API 密钥
ccm config

# 4. 切换并使用
ccm glm              # 切换到 GLM
ccc glm global       # 切换 + 启动 Claude Code

# 进阶：用户级设置（最高优先级，覆盖一切）
ccm user glm global      # 设置 GLM 为全局默认
ccm user reset           # 恢复环境变量控制

# 进阶：项目级覆盖
ccm project glm china    # 仅此项目使用 GLM

# 进阶：多个 Claude Pro 账号
ccm save-account work    # 保存当前账号
ccm switch-account work  # 切换到已保存账号
```

---

## 安装

### 快速安装（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
source ~/.zshrc  # 或 ~/.bashrc
```

### 本地安装
```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
./install.sh
source ~/.zshrc
```

### 安装模式

| 模式 | 命令 | 适用场景 |
|------|------|----------|
| **用户级**（默认） | `./install.sh` | 个人使用，全局可用 |
| **系统级** | `./install.sh --system` | 共享机器，所有用户 |
| **项目级** | `./install.sh --project` | 项目专属，独立配置 |

### 安装选项
```bash
./install.sh --no-rc           # 不注入 shell rc
./install.sh --cleanup-legacy  # 清理旧版安装
./install.sh --help            # 显示所有选项
```

### 卸载
```bash
./uninstall.sh
```

---

## 首次配置

### 1. 配置 API 密钥
```bash
ccm config
```

这会用编辑器打开 `~/.ccm_config`，添加你的 API 密钥：

```bash
# 每个提供商需要对应的 API Key
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=...
GLM_API_KEY=...
QWEN_API_KEY=...
MINIMAX_API_KEY=...
ARK_API_KEY=...           # 豆包/Seed
OPENROUTER_API_KEY=...    # OpenRouter
CLAUDE_API_KEY=...        # 可选，用于 Claude API（非订阅）
```

### 2. 验证配置
```bash
ccm status    # 查看当前配置状态
```

---

## 基本用法

### 切换提供商（当前 shell）
```bash
ccm glm global        # GLM 海外（默认）
ccm glm china         # GLM 国内
ccm deepseek          # DeepSeek
ccm kimi global       # Kimi 海外
ccm kimi china        # Kimi 国内
ccm qwen global       # Qwen 海外
ccm minimax           # MiniMax
ccm seed              # 豆包/Seed
ccm claude            # Claude 官方
```

### 切换 + 启动 Claude Code
```bash
ccc glm global        # 切换到 GLM 海外，然后启动
ccc glm china         # 切换到 GLM 国内，然后启动
ccc open glm          # 通过 OpenRouter
```

### 查看状态
```bash
ccm status             # 显示当前模型和 API Key 状态
ccm current-account    # 显示当前 Claude Pro 账号
```

### 更新配置
当新版本的模型 ID 发生变化时，更新你的配置：
```bash
ccm update-config      # 更新过时的模型 ID 到最新默认值
```

### 获取帮助
```bash
ccm help               # 显示所有命令
ccc                    # 显示 ccc 用法（无参数）
```

---

## 提供商参考

### 直连提供商（需要 API Key）

| 提供商 | 命令 | 区域 | Base URL |
|--------|------|------|----------|
| GLM | `ccm glm [global\|china]` | global（默认） | `api.z.ai/api/anthropic` |
| | | china | `open.bigmodel.cn/api/anthropic` |
| DeepSeek | `ccm deepseek` | - | `api.deepseek.com/anthropic` |
| Kimi | `ccm kimi [global\|china]` | global（默认） | `api.moonshot.ai/anthropic` |
| | | china | `api.moonshot.cn/anthropic` |
| Qwen | `ccm qwen [global\|china]` | global（默认） | `coding-intl.dashscope.aliyuncs.com/apps/anthropic` |
| | | china | `coding.dashscope.aliyuncs.com/apps/anthropic` |
| MiniMax | `ccm minimax [global\|china]` | global（默认） | `api.minimax.io/anthropic` |
| | | china | `api.minimaxi.com/anthropic` |
| 豆包/Seed | `ccm seed [variant]` | - | `ark.cn-beijing.volces.com/api/coding` |
| Claude | `ccm claude` | - | `api.anthropic.com` |

> **GLM Coding 套餐**：[bigmodel.cn/glm-coding](https://www.bigmodel.cn/glm-coding?ic=5XMIOZPPXB)
>
> **豆包 Coding Plan**：[volcengine.com](https://volcengine.com/L/rLv5d5OWXgg/)（邀请码：`ZP5PZMEY`）

### Seed 变体
```bash
ccm seed              # ark-code-latest（默认）
ccm seed doubao       # doubao-seed-code
ccm seed glm          # glm-5
ccm seed deepseek     # deepseek-v3.2
ccm seed kimi         # kimi-k2.5
```

### OpenRouter
```bash
ccm open              # 显示帮助
ccm open glm          # 通过 OpenRouter 使用 GLM
ccm open claude       # 通过 OpenRouter 使用 Claude
ccm open deepseek     # 通过 OpenRouter 使用 DeepSeek
```

---

## 进阶功能

### Claude Pro 多账号管理
在多个 Claude Pro 订阅之间切换：

```bash
# 保存当前登录的账号
ccm save-account work

# 切换到已保存的账号
ccm switch-account work

# 列出所有已保存的账号
ccm list-accounts

# 显示当前账号
ccm current-account

# 删除已保存的账号
ccm delete-account work
```

### 用户级设置（最高优先级）
直接写入 `~/.claude/settings.json`。这会覆盖一切，包括环境变量。当你有其他工具（如 Quotio）也在修改这个文件时特别有用。

```bash
# 设置用户级 provider
ccm user glm global      # 所有项目使用 GLM 海外
ccm user glm china       # 所有项目使用 GLM 国内
ccm user deepseek        # 所有项目使用 DeepSeek
ccm user claude          # 所有项目使用 Claude 官方

# 重置为环境变量控制
ccm user reset           # 移除 ccm 设置，使用环境变量
```

**适用场景：**
- 你有 Quotio 或其他代理设置了 `~/.claude/settings.json`
- 你想要一个持久化的默认设置，不受 shell 重启影响
- 环境变量被其他东西覆盖了

### 项目级覆盖
为特定项目覆盖设置（保持全局设置不变）：

```bash
# 在项目目录中
ccm project glm global    # 仅此项目使用 GLM 海外
ccm project glm china     # 仅此项目使用 GLM 国内
ccm project reset         # 移除项目覆盖
```

这会在当前项目创建/删除 `.claude/settings.local.json`。

### 指定账号启动
```bash
ccc work                  # 切换到 'work' 账号，然后启动
ccc claude:personal       # 切换到 'personal' 账号 + 使用 Claude
```

---

## 配置

### 优先级（从高到低）
1. `~/.claude/settings.json`（env 部分）- 用户级设置
2. `.claude/settings.local.json` - 项目级设置
3. `~/.ccm_config` 文件 - **每次运行 ccm 都会重新加载**
4. 环境变量（仅当配置值为占位符时使用）

### 配置文件位置
```
~/.ccm_config
```

### 完整配置示例
```bash
# 语言（en 或 zh）
CCM_LANGUAGE=zh

# API Keys（每个提供商需要对应的密钥）
DEEPSEEK_API_KEY=sk-...
KIMI_API_KEY=...
GLM_API_KEY=...
QWEN_API_KEY=...
MINIMAX_API_KEY=...
ARK_API_KEY=...
OPENROUTER_API_KEY=...
CLAUDE_API_KEY=...

# 模型 ID 覆盖（可选）
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

## 不使用 RC 注入

如果使用 `--no-rc` 安装或直接从仓库运行：

```bash
# 切换模型（将环境变量应用到当前 shell）
eval "$(ccm glm global)"
eval "$(./ccm.sh glm china)"

# 或直接使用包装脚本
./ccm glm global         # 仅输出 export 语句
./ccc glm china          # 切换 + 启动
```

---

## 备注

- **每个提供商导出 7 个环境变量**：`ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_MODEL`、`ANTHROPIC_DEFAULT_OPUS_MODEL`、`ANTHROPIC_DEFAULT_SONNET_MODEL`、`ANTHROPIC_DEFAULT_HAIKU_MODEL`、`CLAUDE_CODE_SUBAGENT_MODEL`
- **Claude 官方**：默认使用 Claude Code 订阅，或使用 `CLAUDE_API_KEY`（如果设置了）
- **OpenRouter**：需要显式使用 `ccm open <provider>` 命令
- **项目覆盖**：仅影响当前项目（`.claude/settings.local.json`）

---

## 贡献

欢迎贡献！你可以通过以下方式参与：

### 报告问题
发现 bug 或有功能建议？[提交 Issue](https://github.com/foreveryh/claude-code-switch/issues)。

### 提交代码
1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/your-feature`)
3. 提交你的修改
4. 推送到分支
5. 创建 Pull Request

### 开发
```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
./ccm.sh help    # 本地测试，无需安装
```

---

## 更新日志

### v2.4.0 (2025-02)
- **`ccm user` 命令** - 直接写入 `~/.claude/settings.json`（最高优先级）
- **`ccm update-config` 命令** - 自动更新过时的模型 ID
- **配置文件立即生效** - 编辑 `~/.ccm_config` 后立即生效
- **增强 `ccm status`** - 检测并警告用户级设置覆盖
- 模型更新：Kimi → `kimi-k2.5`、MiniMax → `MiniMax-M2.5`、GLM → `glm-5`
- 添加 Coding Plan 链接：GLM、豆包

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE)。

---

## 致谢

本工具的诞生源于在使用 Claude Code 时方便切换 AI 提供商的需求。感谢所有贡献者和开源社区。

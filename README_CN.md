# Claude Code Model Switcher (CCM) 🔧

> 一个强大的Claude Code模型切换工具，支持多家AI服务商的快速切换，包含智能备用机制

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](https://github.com/foreveryh/claude-code-switch)

[中文文档](README_CN.md) | [English](README.md)

## 🎯 快速开始（零配置）

想立即体验，**无需任何 API key**？3步开始：

```bash
# 1. 安装
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash

# 2. 重载shell
source ~/.zshrc  # 或 source ~/.bashrc for bash

# 3. 立即尝试（无需密钥！）
ccm glm          # 切换到 GLM-4.6
ccc deepseek     # 启动 Claude Code with DeepSeek
```

✨ **就这么简单！** 你现在已经拥有了：
- ✅ 内置体验密钥（通过 PPINFRA）
- ✅ 零配置要求
- ✅ 多模型支持
- ✅ 后续可添加自己的 API key 以获得无限使用

## 🌟 特性

- 🤖 **多模型支持**：Claude、Deepseek、KIMI、GLM、Qwen等主流AI模型
- 🔄 **智能备用机制**：官方API优先，自动切换到PPINFRA备用服务
- ⚡ **快速切换**：一键切换不同AI模型，提升开发效率
- 🚀 **一键启动**：`ccc`命令一步切换模型并启动Claude Code
- 🎨 **彩色界面**：直观的命令行界面，清晰显示切换状态
- 🛡️ **安全配置**：独立配置文件管理API密钥
- 📊 **状态监控**：实时显示当前模型配置和密钥状态

## 📦 支持的模型

| 模型 | 官方支持 | 备用支持(PPINFRA) | 特色 |
|------|---------|------------------|------|
| 🌙 **KIMI for Coding** | ✅ kimi-for-coding | ✅ kimi-k2-turbo-preview | Kimi官方编程专用版本 |
| 🌕 **KIMI CN** | ✅ kimi-k2-thinking | ✅ kimi-k2-thinking | Kimi国内版本 |
| 🤖 **Deepseek** | ✅ deepseek-chat | ✅ deepseek/deepseek-v3.2-exp | 高性价比推理 |
| 🌰 **豆包 Seed-Code** | ✅ doubao-seed-code-preview-latest | ❌ 仅官方 | 火山引擎，代码优化 |
| 🐱 **LongCat** | ✅ LongCat-Flash-Chat | ❌ 仅官方 | 快速对话 |
| 🎯 **MiniMax M2** | ✅ MiniMax-M2 | ✅ minimax/minimax-m2 | 代码和推理 |
| 🌊 **StreamLake (KAT)** | ✅ KAT-Coder | ❌ 仅官方 | StreamLake AI |
| 🐪 **Qwen** | ✅ qwen3-max（阿里云） | ✅ qwen3-next-80b-a3b-thinking | 阿里云官方 |
| 🇨🇳 **GLM4.6** | ✅ glm-4.6 | ✅ zai-org/glm-4.6 | 智谱清言 |
| 🧠 **Claude Sonnet 4.5** | ✅ claude-sonnet-4-5-20250929 | ❌ 仅官方 | 平衡性能 |
| 🚀 **Claude Opus 4.5** | ✅ claude-opus-4-5-20251101 | ❌ 仅官方 | 最强推理 |
| 🔷 **Claude Haiku 4.5** | ✅ claude-haiku-4-5 | ❌ 仅官方 | 快速高效 |

> 🎁 **GLM-4.6 官方注册**
>
> 使用智谱AI官方Claude Code集成：
> - **注册链接**：https://www.bigmodel.cn/claude-code?ic=5XMIOZPPXB
> - **邀请码**：`5XMIOZPPXB`
>
> GLM-4.6 支持官方 Claude Code 集成，零配置体验，无需 API key 即可开始使用！

> 💰 **PPINFRA 备用服务注册**
>
> 注册PPINFRA服务可获得 **15元代金券**：
> - **注册链接**：https://ppio.com/user/register?invited_by=ZQRQZZ
> - **邀请码**：`ZQRQZZ`
>
> PPINFRA为Deepseek、KIMI、Qwen和GLM模型提供可靠的备用服务，当官方API不可用时自动切换。

## 🛠️ 安装

### 方式1：快速安装（推荐）⚡

从GitHub一键安装，无需克隆：

```bash
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
source ~/.zshrc  # 重载shell
```

**特性：**
- ✅ 无需克隆
- ✅ 自动从GitHub下载
- ✅ 网络失败重试机制
- ✅ 文件完整性验证
- ✅ 进度反馈和错误处理

### 方式2：本地安装（用于开发）

克隆仓库并本地安装：

```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
chmod +x install.sh ccm.sh
./install.sh
source ~/.zshrc  # 重载shell
```

**不安装使用**（从克隆的目录运行）：
```bash
./ccc deepseek                   # 启动DeepSeek（仅当前进程）
eval "$(./ccm env deepseek)"    # 仅在当前shell设置环境变量
```

### 安装了什么？

安装过程：
- 复制 `ccm.sh` 到 `~/.local/share/ccm/ccm.sh`
- 复制语言文件到 `~/.local/share/ccm/lang/`
- 在你的rc文件中注入 `ccm()` 和 `ccc()` shell函数（~/.zshrc 或 ~/.bashrc）
- 首次使用时创建 `~/.ccm_config`（如果不存在）

**不会：**
- 修改系统文件
- 改变你的PATH
- 需要sudo/root权限
- 影响其他shell配置

## ⚙️ 配置

### 🔑 配置优先级

CCM使用分层配置系统：

1. **环境变量**（最高优先级）
   ```bash
   export DEEPSEEK_API_KEY=sk-your-key
   export KIMI_API_KEY=your-key
   export GLM_API_KEY=your-key
   export QWEN_API_KEY=your-key
   ```

2. **配置文件** `~/.ccm_config`（备用）
   ```bash
   ccm config              # 在编辑器中打开配置
   # 或手动编辑: vim ~/.ccm_config
   ```

### 配置文件示例

```bash
# CCM 配置文件
# 注意：环境变量优先级高于此文件

# 官方API密钥
DEEPSEEK_API_KEY=sk-your-deepseek-api-key
KIMI_API_KEY=your-kimi-api-key  # Moonshot AI
LONGCAT_API_KEY=your-longcat-api-key
MINIMAX_API_KEY=your-minimax-api-key
GLM_API_KEY=your-glm-api-key
QWEN_API_KEY=your-qwen-api-key  # 阿里云 DashScope

# 可选：覆盖模型ID（省略时使用默认值）
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-for-coding  # 用于 KIMI for Coding
KIMI_CN_MODEL=kimi-k2-thinking  # 用于 KIMI CN（国内版本）
LONGCAT_MODEL=LongCat-Flash-Thinking
MINIMAX_MODEL=MiniMax-M2
QWEN_MODEL=qwen3-max
GLM_MODEL=glm-4.6
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-5-20251101

# 备用服务（仅当官方密钥缺失时启用）
PPINFRA_API_KEY=your-ppinfra-api-key
```

**安全提示：** 建议 `chmod 600 ~/.ccm_config` 以保护您的API密钥。

## 🔐 Claude Pro 账号管理（v2.2.0 新功能）

CCM 现在支持管理多个 Claude Pro 订阅账号！在账号之间切换以突破使用限制，无需升级到 Claude Max。

### 为什么使用多账号？

- **突破使用限制**：每个 Claude Pro 账号有独立的使用限制（每天5小时、每周限制）
- **节省成本**：多个 Pro 账号比一个 Max 账号更便宜
- **无缝切换**：无需登出/登入 - CCM 自动处理认证
- **安全存储**：账号凭证安全存储在 macOS Keychain 中，带有本地备份

### 账号管理命令

```bash
# 保存当前登录的账号
ccm save-account 主号              # 保存为"主号"
ccm save-account 备用号            # 保存为"备用号"

# 在账号之间切换
ccm switch-account 主号            # 切换到主号
ccm switch-account 备用号          # 切换到备用号

# 查看所有已保存的账号
ccm list-accounts
# 输出:
# 📋 已保存的 Claude Pro 账号:
#   - 主号 (Pro, expires: 2025-12-31, ✅ 当前)
#   - 备用号 (Pro, expires: 2025-12-31)

# 查看当前账号
ccm current-account

# 删除已保存的账号
ccm delete-account 旧账号
```

### 快速账号切换与模型选择

```bash
# 一条命令切换账号并选择模型
ccm opus:主号                      # 切换到主号，使用 Opus
ccm haiku:备用号                   # 切换到备用号，使用 Haiku
ccc opus:主号                      # 切换账号并启动 Claude Code
ccc 备用号                         # 仅切换账号并启动（默认模型）
```

### 账号设置指南

**步骤 1**：保存第一个账号
```bash
# 在浏览器中使用账号1登录 Claude Code
# 启动 Claude Code 验证可以正常工作
ccm save-account 账号1
```

**步骤 2**：保存其他账号
```bash
# 退出 Claude Code
# 在浏览器中登出 claude.ai
# 使用账号2登录
# 再次启动 Claude Code
ccm save-account 账号2
```

**步骤 3**：随时切换账号
```bash
ccm switch-account 账号1          # 无需浏览器登录！
# 重启 Claude Code 使更改生效
```

**重要说明**：
- Token 会自动刷新 - 在过期前无需重新登录
- 切换账号后，需要重启 Claude Code 使更改生效
- 账号凭证主要存储在 macOS Keychain 中（最安全）
- 本地备份存储在 `~/.ccm_accounts` 中，使用 base64 编码和 chmod 600 权限
- 凭证在系统重启后依然有效
- Keychain 服务名默认使用 `Claude Code-credentials`。如系统中服务名不同，可通过环境变量 `CCM_KEYCHAIN_SERVICE` 指定

**安全注意事项**：
- 始终使用 `chmod 600 ~/.ccm_accounts` 保护本地备份
- 系统依赖 macOS Keychain 进行安全凭证存储
- 本地备份使用 base64 编码（非加密）以确保兼容性

### Keychain 调试

```bash
ccm debug-keychain                # 查看当前 Keychain 凭证并尝试匹配保存账号
# 若显示未找到凭证，但浏览器/IDE 已登录，可指定服务名覆盖：
CCM_KEYCHAIN_SERVICE="Claude Code" ccm debug-keychain
```

### 账号管理故障排除

**问题**："Keychain 中没有凭证"
- 解决方案：确保您已在浏览器或 IDE 中登录 Claude Code
- 尝试使用不同的 Keychain 服务名，设置 `CCM_KEYCHAIN_SERVICE` 环境变量

**问题**："账号切换不生效"
- 解决方案：切换账号后重启 Claude Code
- 使用 `ccm list-accounts` 检查账号是否存在

**问题**："访问账号文件权限被拒绝"
- 解决方案：运行 `chmod 600 ~/.ccm_accounts` 修复权限

**问题**："账号文件 JSON 格式错误"
- 解决方案：删除 `~/.ccm_accounts` 文件，重新保存账号

## 📖 使用方法

### 两种使用方式

**方式1：`ccm` - 环境管理**
```bash
ccm deepseek      # 切换到 DeepSeek
ccm glm           # 切换到 GLM4.6
ccm pp kimi       # 切换到 PPINFRA KIMI
claude            # 然后手动启动 Claude Code
```

**方式2：`ccc` - 一键启动（推荐）**
```bash
ccc deepseek                            # 切换并启动
ccc pp glm                              # 切换到PPINFRA并启动
ccc kimi --dangerously-skip-permissions # 传递选项给Claude Code
```

### 基本命令

```bash
# 切换到不同模型
ccm kimi          # 切换到KIMI for Coding（官方编程版本）
ccm kimi-cn       # 切换到KIMI CN（国内版本）
ccm deepseek      # 切换到Deepseek
ccm minimax       # 切换到MiniMax M2
ccm qwen          # 切换到Qwen
ccm kat           # 切换到StreamLake (KAT)
ccm glm           # 切换到GLM4.6
ccm longcat       # 切换到LongCat
ccm claude        # 切换到Claude Sonnet 4.5
ccm opus          # 切换到Claude Opus 4.5
ccm haiku         # 切换到Claude Haiku 4.5

# 切换到PPINFRA服务
ccm pp            # 交互式PPINFRA模型选择
ccm pp deepseek   # 直接切换到PPINFRA DeepSeek
ccm pp glm        # 直接切换到PPINFRA GLM
ccm pp kimi       # 直接切换到PPINFRA KIMI
ccm pp minimax    # 直接切换到PPINFRA MiniMax M2
ccm pp qwen       # 直接切换到PPINFRA Qwen

# 启动Claude Code
ccc deepseek      # 切换到DeepSeek并启动
ccc pp glm        # 切换到PPINFRA GLM并启动
ccc opus          # 切换到Claude Opus并启动
ccc kat           # 切换到StreamLake (KAT)并启动

# 工具命令
ccm status        # 查看当前状态（脱敏）
ccm config        # 编辑配置
ccm help          # 显示帮助
ccc               # 显示ccc使用帮助
```

### 命令简写

```bash
# ccm 简写
ccm ds           # deepseek的简写
ccm mm           # minimax的简写
ccm s            # claude sonnet的简写  
ccm o            # opus的简写 (Claude Opus 4.5)
ccm h            # haiku的简写
ccm st           # status的简写

# ccc 简写
ccc ds           # 使用DeepSeek启动
ccc pp ds        # 使用PPINFRA DeepSeek启动
ccc kat          # 使用StreamLake (KAT)启动
```

### 使用示例

**示例1：零配置（内置密钥）**
```bash
ccc deepseek
🔄 切换到 deepseek...
✅ 已配置环境: DeepSeek

🚀 启动 Claude Code...
   Model: deepseek-chat
   Base URL: https://api.ppinfra.com/anthropic
```

**示例2：使用自己的API密钥**
```bash
export KIMI_API_KEY=your-moonshot-key
ccm kimi
ccm status
📊 当前模型配置:
   BASE_URL: https://api.moonshot.cn/anthropic
   AUTH_TOKEN: [已设置]
   MODEL: kimi-k2-turbo-preview
   SMALL_MODEL: kimi-k2-turbo-preview

claude  # 手动启动
```

**示例3：一键启动**
```bash
ccc pp glm --dangerously-skip-permissions
🔄 切换到 PPINFRA glm...
✅ 已配置环境: GLM (PPINFRA)

🚀 启动 Claude Code...
   Model: zai-org/glm-4.6
   Base URL: https://api.ppinfra.com/anthropic
```

## 🔧 高级特性

### 智能备用机制

CCM实现智能备用：
- **官方API优先**：配置官方密钥时使用官方服务
- **自动备用**：官方密钥缺失时自动切换到PPINFRA备用服务
- **透明切换**：对用户无感，命令保持一致

### 服务集成

**阿里云DashScope**（Qwen模型）：
- Base URL: `https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy`
- 默认模型: `qwen3-max`（主要），`qwen3-next-80b-a3b-instruct`（快速）
- API Key格式: 阿里云控制台的标准`sk-`前缀

**PPINFRA备用服务**：
- Base URL: `https://api.ppinfra.com/anthropic`
- 支持的模型:
  - `kimi-k2-turbo-preview` (KIMI备用)
  - `deepseek/deepseek-v3.2-exp` (Deepseek备用)
  - `MiniMax-M2` (MiniMax官方)
  - `minimax/minimax-m2` (MiniMax PPINFRA备用)
  - `qwen3-next-80b-a3b-thinking` (Qwen备用)
  - `zai-org/glm-4.6` (GLM备用)

### 安全和隐私

- 状态输出脱敏处理（仅显示前/后4个字符）
- CCM仅设置 `ANTHROPIC_AUTH_TOKEN`（不设置`ANTHROPIC_API_KEY`）
- 配置文件优先级：环境变量 > ~/.ccm_config
- 推荐文件权限：`chmod 600 ~/.ccm_config`

## 🗑️ 卸载

```bash
# 如果通过quick-install.sh或install.sh安装
./uninstall.sh

# 或手动：
# 1. 从 ~/.zshrc 或 ~/.bashrc 中删除 ccm/ccc 函数块
# 2. 删除安装目录
rm -rf ~/.local/share/ccm
rm ~/.ccm_config  # 可选：删除配置文件
```

## 🐛 故障排除

### 常见问题

**问：收到"XXX_API_KEY not detected"错误**
```bash
答：检查API密钥是否正确配置：
   ccm config      # 打开配置文件检查
   ccm status      # 查看当前配置
```

**问：切换后Claude Code不工作**
```bash
答：验证环境变量：
   ccm status                   # 检查当前状态
   echo $ANTHROPIC_BASE_URL     # 检查环境变量
   env | grep ANTHROPIC         # 列出所有ANTHROPIC变量
```

**问：想使用官方服务而不是备用服务**
```bash
答：配置官方API密钥，CCM会自动优先使用：
   export DEEPSEEK_API_KEY=sk-your-official-key
   ccm deepseek
```

**问：API_KEY vs AUTH_TOKEN 冲突**
```bash
答：CCM仅设置ANTHROPIC_AUTH_TOKEN，取消任何冲突变量：
   unset ANTHROPIC_API_KEY
```

## 🤝 贡献

欢迎Issues和Pull Requests！

### 开发设置
```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
```

### 提交指南
- 使用清晰的提交信息
- 添加适当的测试
- 更新文档

## 📄 许可证

本项目采用 [MIT License](LICENSE) 许可。

## 🙏 致谢

- [Claude](https://claude.ai) - AI助手
- [Deepseek](https://deepseek.com) - 高效推理模型
- [KIMI](https://kimi.moonshot.cn) - 长文本处理
- [MiniMax](https://www.minimaxi.com) - MiniMax M2 模型
- [Zhipu AI](https://zhipuai.cn) - GLM大模型
- [Qwen](https://qwen.alibaba.com) - 阿里通义千问

---

⭐ 如果这个项目对你有帮助，请给个Star！

📧 有问题或建议？欢迎提交 [Issue](https://github.com/foreveryh/claude-code-switch/issues)

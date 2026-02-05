# Claude Code 故障排除 (Troubleshooting)

本指南帮助您解决使用 CCM 切换模型时遇到的常见问题。

---

## 问题 1：404 错误

### 症状
```
> 你是？
  ⎿  API Error: 404 404 page not found
```

### 原因分析

1. **认证冲突**：Claude Code 同时检测到两个认证方式：
   - `ANTHROPIC_AUTH_TOKEN`（环境变量设置的）
   - `/login` 管理的 API key（Claude Code 内置的）

2. **错误的 API 端点**：Base URL 配置不正确或包含重复的路径

### 解决方案

#### 方法 1：清除 Claude Code 的登录状态（推荐）

1. **在 Claude Code 中执行 logout**：
   ```
   /logout
   ```
   或在终端中：
   ```bash
   claude /logout
   ```

2. **使用 ccc 命令重新启动**：
   ```bash
   # 重新加载 shell 配置
   source ~/.zshrc
   
   # 使用 ccc 启动（会自动设置环境变量）
   ccc deepseek
   ```

3. **验证**：启动后不应该再看到认证冲突警告。

#### 方法 2：检查环境变量

在启动 Claude Code 之前验证配置：

```bash
# 切换模型
ccm deepseek

# 检查配置
ccm status

# 应该看到正确的 BASE_URL 和 AUTH_TOKEN
```

#### 方法 3：检查 claude-code-router 配置

如果使用了 `claude-code-router`，可能会干扰配置：

```bash
# 查看配置
cat ~/.claude-code-router/config.json

# 临时禁用（如果需要）
mv ~/.claude-code-router ~/.claude-code-router.disabled

# 重新启动
ccc deepseek

# 测试完成后恢复
mv ~/.claude-code-router.disabled ~/.claude-code-router
```

---

## 问题 2：代码更新后命令失效或报错

### 症状

运行 `ccm` 命令时出现以下错误之一：

```bash
# 错误示例 1：新增的命令不存在
ccm h
(eval):1: bad pattern: ^[[0
zsh: parse error near `:1:'

# 错误示例 2：新功能无法使用
ccm open kimi
ccm: unknown option: open

# 错误示例 3：旧版本行为
ccm status  # 显示的是旧配置，没有新添加的模型
```

### 原因分析

**重要**：`ccm` shell 函数使用的是**已安装的脚本**（位于 `~/.local/share/ccm/ccm.sh`），而不是您工作目录中修改的开发版本。

当您：
1. ✏️ 修改了 `ccm.sh` 文件
2. ❌ 但忘记重新安装
3. 🔍 运行 `ccm` 命令

结果：您仍在使用**旧版本**的代码，新功能完全不会生效。

### 解决方案

#### ✅ 标准开发流程（每次修改代码后必做）

```bash
# 1. 修改代码后，重新安装
./install.sh

# 2. 重新加载 shell 配置
source ~/.zshrc  # 或 source ~/.bashrc

# 3. 验证更新
ccm status      # 检查版本是否更新
ccm help        # 确认新命令出现在帮助中
```

#### 🔍 验证是否需要重新安装

```bash
# 检查已安装版本的位置
type ccm
# 输出：ccm is a shell function from /Users/xxx/.zshrc

# 查看已安装脚本的修改时间
ls -lh ~/.local/share/ccm/ccm.sh

# 对比工作目录版本
ls -lh ccm.sh

# 如果时间不匹配，说明需要重新安装
```

#### 🎯 开发者工作流程速查

```bash
# 开发循环
1. vim ccm.sh              # 编辑代码
2. ./install.sh            # 安装更新
3. source ~/.zshrc         # 重载配置  
4. ccm <test-command>      # 测试功能
5. 如有问题，回到步骤 1
```

### 特别提醒

⚠️ **常见错误模式**：
- ❌ 修改代码 → 直接运行 `ccm` → 疑惑为什么没生效
- ✅ 修改代码 → `./install.sh` → `source ~/.zshrc` → 运行 `ccm`

💡 **记忆技巧**：把 `./install.sh && source ~/.zshrc` 作为一个固定操作，每次改代码后都执行。

---

## 问题 3：环境变量未生效

### 症状

Claude Code 启动后仍然使用旧的 API 端点。

### 原因

Claude Code 继承的是**启动时**的环境变量，不是当前 shell 的环境变量。

### 解决方案

**使用 `ccc` 命令（推荐）**：

```bash
# 一步到位：切换模型并启动 Claude Code
ccc deepseek
```

**或者两步走**：

```bash
# 1. 先切换环境
ccm deepseek

# 2. 再启动 Claude Code
claude
```

⚠️ **注意**：不要先启动 Claude Code，然后再切换环境变量，这样不会生效。

---

## 常见警告及解决方法

### ⚠️ Auth conflict 警告

```
⚠ Auth conflict: Both a token (ANTHROPIC_AUTH_TOKEN) and an API key (/login managed key) are set.
```

**解决**：
```bash
# 在 Claude Code 中执行
/logout

# 或在终端执行
claude /logout

# 然后重新启动
ccc deepseek
```

### ❌ Model not found 错误

**可能原因**：
- 模型名称拼写错误
- API Key 无效

**解决**：
```bash
# 查看支持的模型
ccm help

# 验证配置
ccm status

# 确保 API Key 正确
ccm config
```

---

## Debug 检查清单

在报告问题前，请逐一检查：

- [ ] 已安装最新版本：`./install.sh`
- [ ] 已重新加载 shell：`source ~/.zshrc`
- [ ] 已执行 `claude /logout` 清除认证冲突
- [ ] 配置文件正确：`ccm config` 检查 API keys
- [ ] 环境变量正确：`ccm status` 验证配置
- [ ] 使用 `ccc` 命令启动（不是手动 `ccm` + `claude`）
- [ ] 没有 `claude-code-router` 干扰

---

## 成功启动的标志

### 使用 ccc 启动时

正确的启动流程应该显示：

```bash
$ ccc deepseek
🔄 Switching to deepseek...
✅ Environment configured for: DeepSeek

🚀 Launching Claude Code...
   Model: deepseek-chat
   Base URL: https://api.deepseek.com/anthropic

╭─────────────────────────────────────────────────────╮
│ ✻ Welcome to Claude Code!                           │
│                                                     │
│   Overrides (via env):                              │
│   • API Base URL:                                   │
│   https://api.deepseek.com/anthropic                │
╰─────────────────────────────────────────────────────╯
```

**关键点**：
- ✅ 没有认证冲突警告
- ✅ Base URL 显示正确
- ✅ 可以直接开始对话

---

## 快速测试命令

```bash
# 测试官方 API
ccc deepseek
# 输入: 你好
# 应该得到正常回复
```

---

## 需要帮助？

如果以上方法都无法解决，请提供以下信息：

1. **系统信息**：
   ```bash
   uname -a
   echo $SHELL
   ```

2. **CCM 版本**：
   ```bash
   head -5 ccm.sh  # 查看版本注释
   ```

3. **配置状态**：
   ```bash
   ccm status
   ```

4. **启动命令和完整输出**：
   ```bash
   ccc deepseek 2>&1 | tee debug.log
   ```

5. **错误消息**：完整的错误信息截图或文本

将以上信息提交到项目 Issues 页面。

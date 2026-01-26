# PPINFRA 使用指南

PPINFRA 是一个第三方 AI 模型聚合服务，提供 DeepSeek、GLM、KIMI、Qwen 等模型的备用访问。

---

## 快速开始

### 方法 1：使用 ccc 一键启动（推荐）

最简单的方式是使用 `ccc pp` 命令，一步完成模型切换和 Claude Code 启动：

```bash
# 使用 PPINFRA DeepSeek
ccc pp deepseek

# 使用 PPINFRA GLM 4.6
ccc pp glm

# 使用 PPINFRA KIMI 2
ccc pp kimi

# 使用 PPINFRA Qwen
ccc pp qwen

# 带 Claude Code 选项
ccc pp deepseek --dangerously-skip-permissions
```

### 方法 2：两步法

如果您想先验证配置再启动：

```bash
# 1. 切换到 PPINFRA 模型
ccm pp deepseek

# 2. 验证配置
ccm status

# 3. 启动 Claude Code（会继承环境变量）
claude
```

---

## 配置 PPINFRA API Key

### 获取 API Key

1. 注册 PPINFRA 账号：https://ppio.com/user/register?invited_by=ZQRQZZ
2. 使用邀请码 `ZQRQZZ` 获得 ¥15 优惠券
3. 在控制台获取 API Key

### 配置 API Key

```bash
# 打开配置文件
ccm config

# 添加以下行
PPINFRA_API_KEY=your-ppinfra-api-key-here
```

或直接编辑：
```bash
vim ~/.ccm_config
```

---

## 验证配置

### 检查环境变量

```bash
# 切换到 PPINFRA 模型
ccm pp deepseek

# 查看当前配置
ccm status
```

应该显示：
```
📊 Current model configuration:
   BASE_URL: https://api.ppinfra.com/anthropic
   AUTH_TOKEN: [Set]
   MODEL: deepseek/deepseek-v3.2-exp
   SMALL_MODEL: deepseek/deepseek-v3.2-exp
```

### 测试连接

启动 Claude Code 并发送测试消息：
```bash
ccc pp deepseek
# 输入: 你好
# 应该得到正常回复
```

---

## 支持的 PPINFRA 模型

| 命令 | 模型名称 | 说明 |
|------|---------|-----|
| `ccc pp deepseek` | deepseek/deepseek-v3.2-exp | DeepSeek V3.2 实验版 |
| `ccc pp glm` | zai-org/glm-4.7 | 智谱清言 GLM 4.7 |
| `ccc pp kimi` | kimi-k2-turbo-preview | 月之暗面 KIMI 2 |
| `ccc pp qwen` | qwen3-next-80b-a3b-thinking | 阿里云通义千问 |

**快捷方式**：
```bash
ccc pp ds    # DeepSeek 简写
```

---

## 工作原理

### ccm pp 命令（环境管理）

1. `ccm pp <model>` 调用 `ccm.sh`
2. `ccm.sh` 输出 export 语句
3. Shell 通过 `eval` 执行这些语句
4. 环境变量在当前 shell 中生效

```bash
ccm pp deepseek  # 只设置环境变量
```

### ccc pp 命令（一键启动）

1. `ccc pp <model>` 调用 `ccm pp <model>` 设置环境变量
2. 显示切换状态和配置信息
3. 使用 `exec claude` 启动 Claude Code
4. Claude Code 继承所有环境变量

```bash
ccc pp deepseek  # 设置环境 + 启动 Claude Code
```

---

## 常见问题

### Q: 为什么 Claude Code 显示的 URL 不是 PPINFRA？

**A:** Claude Code 继承的是启动时的环境变量。解决方法：

```bash
# 方法 1：使用 ccc（推荐）
ccc pp deepseek

# 方法 2：两步法
ccm pp deepseek  # 先设置环境
claude           # 再启动
```

### Q: 如何切换回官方 API？

**A:** 使用不带 `pp` 的命令：

```bash
# 官方 API
ccc deepseek  # 或: ccm deepseek
ccc glm
ccc claude

# PPINFRA
ccc pp deepseek  # 或: ccm pp deepseek
ccc pp glm
```

### Q: PPINFRA API Key 在哪里配置？

**A:** 使用配置命令：

```bash
ccm config  # 打开配置文件

# 添加这一行
PPINFRA_API_KEY=your-ppinfra-api-key
```

### Q: 如何验证 PPINFRA 配置是否正确？

**A:** 使用 status 命令：

```bash
ccm pp deepseek
ccm status

# 应该显示：
# BASE_URL: https://api.ppinfra.com/anthropic
# MODEL: deepseek/deepseek-v3.2-exp
```

---

## 使用场景

### 场景 1：快速测试不同模型

```bash
# 快速切换测试
ccc pp deepseek  # 测试 DeepSeek
# Ctrl+C 退出

ccc pp glm       # 测试 GLM
# Ctrl+C 退出

ccc pp kimi      # 测试 KIMI
```

### 场景 2：官方 API 和 PPINFRA 混用

```bash
# 使用官方 Claude API（需要订阅）
ccc claude

# 成本敏感任务切换到 PPINFRA
ccc pp deepseek
```

### 场景 3：批量处理任务

```bash
# 设置环境后批量运行
ccm pp deepseek

# 多次启动 Claude Code 处理不同任务
claude task1.txt
claude task2.txt
claude task3.txt
```

---

## 价格优势

PPINFRA 相比官方 API 的优势：

- **DeepSeek**: PPINFRA 提供更优惠的价格
- **GLM**: 通过 PPINFRA 访问，无需单独申请
- **KIMI**: 长文本处理更经济
- **Qwen**: 稳定的国内访问

---

## 故障排除

如果遇到问题，请参考：
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 完整的故障排除指南

常见问题：
```bash
# 404 错误
claude /logout  # 清除认证冲突
ccc pp deepseek # 重新启动

# 环境变量未生效
ccm status      # 检查配置
source ~/.zshrc # 重新加载 shell
```

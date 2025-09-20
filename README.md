# Claude Code Model Switcher (CCM) 🔧

> A powerful Claude Code model switching tool with support for multiple AI service providers and intelligent fallback mechanisms

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](https://github.com/yourusername/claude-code-switch)

[中文文档](README_CN.md) | [English](README.md)

## 🚀 Quick Start (60 seconds)

- Install (no zshrc changes)
```bash
chmod +x install.sh ccm.sh && ./install.sh
```

- Configure (env > config)
```bash
# Option A: create/edit config file
ccm            # first run creates ~/.ccm_config
ccm config     # open it in your editor

# Option B: set environment variables (highest priority)
export DEEPSEEK_API_KEY=sk-...
```

- Use (activate in current shell)
```bash
eval "$(ccm env deepseek)"
ccm status
```

- Uninstall
```bash
./uninstall.sh
```

Notes: does not modify ~/.zshrc; secrets are masked in status; recommend chmod 600 ~/.ccm_config

## 🌟 Features

- 🤖 **Multi-model Support**: Claude, Deepseek, KIMI, GLM, Qwen and other mainstream AI models
- 🔄 **Smart Fallback Mechanism**: Official API priority with automatic fallback to PPINFRA backup service
- ⚡ **Quick Switching**: One-click switching between different AI models to boost productivity
- 🎨 **Colorful Interface**: Intuitive command-line interface with clear switching status display
- 🛡️ **Secure Configuration**: Independent configuration file for API key management, multi-editor support
- 📊 **Status Monitoring**: Real-time display of current model configuration and key status

## 📦 Supported Models

| Model | Official Support | Fallback Support(PPINFRA) | Features |
|-------|------------------|---------------------------|----------|
| 🌙 **KIMI2** | ✅ moonshot-v1-128k | ✅ moonshotai/kimi-k2-0905 | Long text processing |
| 🤖 **Deepseek** | ✅ deepseek-chat | ✅ deepseek/deepseek-v3.1 | Cost-effective reasoning |
| 🐪 **Qwen** | ⚠️ Requires endpoint config | ✅ qwen3-next-80b-a3b-thinking | Thinking model |
| 🇨🇳 **GLM4.5** | ✅ glm-4-plus | ❌ Official only | Zhipu AI |
| 🧠 **Claude Sonnet 4** | ✅ claude-sonnet-4-20250514 | ❌ Official only | Balanced performance |
| 🚀 **Claude Opus 4.1** | ✅ claude-opus-4-1-20250805 | ❌ Official only | Strongest reasoning |

## 🚀 Quick Start

### 1. Download Script

```bash
# Clone the project
git clone https://github.com/yourusername/claude-code-switch.git
cd claude-code-switch

# Or download script directly
wget https://raw.githubusercontent.com/yourusername/claude-code-switch/main/ccm.sh
chmod +x ccm.sh
```

### 2. First Run

```bash
./ccm.sh
```

First run will automatically create configuration file `~/.ccm_config`. Please edit this file to add your API keys.

### 3. Configure API Keys

**🔑 Priority: Environment Variables > Configuration File**

CCM follows a smart configuration hierarchy:
1. **Environment variables** (highest priority) - `export DEEPSEEK_API_KEY=your-key`
2. **Configuration file** `~/.ccm_config` (fallback when env vars not set)

```bash
# Option 1: Set environment variables (recommended for security)
export DEEPSEEK_API_KEY=sk-your-deepseek-api-key
export KIMI_API_KEY=your-kimi-api-key
export PPINFRA_API_KEY=your-ppinfra-api-key

# Option 2: Edit configuration file
./ccm.sh config
# Or manually: vim ~/.ccm_config
```

Configuration file example:
```bash
# CCM Configuration File
# Note: Environment variables take priority over this file

# Official API keys
DEEPSEEK_API_KEY=sk-your-deepseek-api-key
KIMI_API_KEY=your-kimi-api-key
GLM_API_KEY=your-glm-api-key
QWEN_API_KEY=your-qwen-api-key
QWEN_ANTHROPIC_BASE_URL=https://your-qwen-anthropic-gateway

# Fallback service (only enabled when official keys are missing)
PPINFRA_API_KEY=your-ppinfra-api-key
```

## 📖 Usage

### Basic Commands

```bash
# Switch to different models
ccm kimi          # Switch to KIMI2
ccm deepseek      # Switch to Deepseek  
ccm qwen          # Switch to Qwen
ccm glm           # Switch to GLM4.5
ccm claude        # Switch to Claude Sonnet 4
ccm opus          # Switch to Claude Opus 4.1

# View current status (masked)
ccm status

# Edit configuration
ccm config

# Show help
ccm help
```

### Activate in current shell (recommended)

Use env subcommand to safely export environment variables without printing secrets in plain text:
```bash
# Apply model env exports to current shell
eval "$(ccm env deepseek)"
# Verify
ccm status
```

### Command Shortcuts

```bash
./ccm.sh ds           # Short for deepseek
./ccm.sh s            # Short for claude sonnet  
./ccm.sh o            # Short for opus
./ccm.sh st           # Short for status
```

### Usage Examples

```bash
# Switch to KIMI for long text processing
$ ./ccm.sh kimi
🔄 Switching to KIMI2 model...
✅ Switched to KIMI2 (Official)
   BASE_URL: https://api.moonshot.cn/v1/anthropic
   MODEL: moonshot-v1-128k

# Switch to Deepseek for code generation (auto fallback if no official key)
$ ./ccm.sh deepseek  
🔄 Switching to Deepseek model...
✅ Switched to Deepseek (PPINFRA Fallback)
   BASE_URL: https://api.ppinfra.com/openai/v1/anthropic
   MODEL: deepseek/deepseek-v3.1

# Check current configuration status
$ ./ccm.sh status
📊 Current model configuration:
   BASE_URL: https://api.ppinfra.com/openai/v1/anthropic
   AUTH_TOKEN: [Set]
   MODEL: deepseek/deepseek-v3.1
   SMALL_MODEL: deepseek/deepseek-v3.1

🔧 Environment variable status:
   GLM_API_KEY: [Not set]
   KIMI_API_KEY: [Set]
   DEEPSEEK_API_KEY: [Not set]
   QWEN_API_KEY: [Not set]
   PPINFRA_API_KEY: [Set]
```

## 🛠️ Install (no zshrc changes)

CCM supports safe one-step installation without modifying your shell configuration files.

### One-step install
```bash
# From the project directory
chmod +x install.sh ccm.sh
./install.sh
```

- Installs to /usr/local/bin or /opt/homebrew/bin when writable
- Falls back to ~/.local/bin if system paths are not writable
- Does NOT modify ~/.zshrc or other shell profiles

### Uninstall
```bash
./uninstall.sh
```

If installed to a protected directory, you may need sudo:
```bash
sudo install -m 0755 ./ccm.sh /usr/local/bin/ccm
# To uninstall
sudo rm -f /usr/local/bin/ccm
```

## 🔧 Advanced Configuration

### 🔑 Configuration Priority System

CCM uses a smart hierarchical configuration system:

1. **Environment Variables** (Highest Priority)
   - Set in your shell session: `export DEEPSEEK_API_KEY=your-key`
   - Recommended for temporary testing or CI/CD environments
   - Always takes precedence over configuration files

2. **Configuration File** `~/.ccm_config` (Fallback)
   - Persistent storage for API keys
   - Only used when corresponding environment variable is not set
   - Ideal for daily development use

**Example scenario:**
```bash
# Environment variable exists
export DEEPSEEK_API_KEY=env-key-123

# Config file contains
echo "DEEPSEEK_API_KEY=config-key-456" >> ~/.ccm_config

# CCM will use: env-key-123 (environment variable wins)
./ccm.sh status  # Shows DEEPSEEK_API_KEY: env-key-123
```

### Smart Fallback Mechanism

CCM implements intelligent fallback mechanism:
- **Official API Priority**: Uses official service if official keys are configured
- **Auto Fallback**: Automatically switches to PPINFRA backup service when official keys are not configured
- **Transparent Switching**: Seamless to users, commands remain consistent

### Security and Privacy
- Status output masks secrets (shows only first/last 4 chars)
- env subcommand prints only export statements and references to variables; it does not echo secrets
- Configuration file precedence: Environment Variables > ~/.ccm_config
- Recommended file permission: `chmod 600 ~/.ccm_config`

### PPINFRA Fallback Service

PPINFRA is a third-party AI model aggregation service providing:
- Base URL: `https://api.ppinfra.com/openai/v1/anthropic`
- Supported models:
  - `moonshotai/kimi-k2-0905` (KIMI fallback)
  - `deepseek/deepseek-v3.1` (Deepseek fallback)
  - `qwen3-next-80b-a3b-thinking` (Qwen fallback)

### Configuration File Details

`~/.ccm_config` file contains all API key configurations:

```bash
# Required: Official keys from various providers (at least one)
DEEPSEEK_API_KEY=sk-your-deepseek-key
KIMI_API_KEY=your-kimi-key  
GLM_API_KEY=your-glm-key
QWEN_API_KEY=your-qwen-key

# Optional: Qwen official Anthropic-compatible endpoint
QWEN_ANTHROPIC_BASE_URL=https://your-qwen-gateway

# Optional but recommended: Fallback service key
PPINFRA_API_KEY=your-ppinfra-key

# Claude (if using API instead of Pro subscription)
CLAUDE_API_KEY=your-claude-key
```

## 🐛 Troubleshooting

### Common Issues

**Q: Getting "XXX_API_KEY not detected" error**
```bash
A: Check if the corresponding API key is correctly configured in ~/.ccm_config
   ./ccm.sh config  # Open config file to check
```

**Q: Claude Code doesn't work after switching**
```bash
A: Confirm environment variables are set correctly:
   ./ccm.sh status  # Check current configuration status
   echo $ANTHROPIC_BASE_URL  # Check environment variable
```

**Q: Want to force using official service instead of fallback**
```bash
A: Configure the corresponding official API key, script will automatically prioritize official service
```

### Debug Mode

```bash
# Show detailed status information
./ccm.sh status

# Check configuration file
cat ~/.ccm_config

# Verify environment variables
env | grep ANTHROPIC
```

## 🤝 Contributing

Issues and Pull Requests are welcome!

### Development Setup
```bash
git clone https://github.com/yourusername/claude-code-switch.git
cd claude-code-switch
```

### Commit Guidelines
- Use clear commit messages
- Add appropriate tests
- Update documentation

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- [Claude](https://claude.ai) - AI Assistant
- [Deepseek](https://deepseek.com) - Efficient reasoning model
- [KIMI](https://kimi.moonshot.cn) - Long text processing
- [Zhipu AI](https://zhipuai.cn) - GLM large model
- [Qwen](https://qwen.alibaba.com) - Alibaba Tongyi Qianwen

---

⭐ If this project helps you, please give it a Star!

📧 Questions or suggestions? Feel free to submit an [Issue](https://github.com/yourusername/claude-code-switch/issues)
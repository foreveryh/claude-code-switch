# CCM Python Version - Usage Guide

CCM (Claude Code Model Switcher) has been migrated to Python for better maintainability, testing, and cross-platform support.

## Installation

### Method 1: Using uv (Recommended)

```bash
# Install from source
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
uv tool install .

# Or directly from GitHub
uv tool install git+https://github.com/foreveryh/claude-code-switch.git
```

### Method 2: Using pip

```bash
pip install -e .
```

### Method 3: Shell Function Injection (Eval Mode)

For the full eval experience, source the shell functions:

```bash
# Add to your .zshrc or .bashrc
source /path/to/claude-code-switch/shell/rc-functions.sh
```

Or run the installer:

```bash
./install.sh
source ~/.zshrc  # or ~/.bashrc
```

## Basic Usage

### Switch Provider (Eval Mode)

The primary way to use CCM is with the eval pattern:

```bash
# Switch to DeepSeek
eval "$(ccm deepseek)"

# Switch to Kimi (China region)
eval "$(ccm kimi china)"

# Switch to GLM (Global region)
eval "$(ccm glm global)"

# Switch to Claude (Official Anthropic)
eval "$(ccm claude)"
```

### Launch Claude Code (ccc command)

The `ccc` command switches the provider and launches Claude Code:

```bash
# Launch with DeepSeek
ccc deepseek

# Launch with Kimi China
ccc kimi china

# Launch with GLM Global and pass options
ccc glm global --dangerously-skip-permissions

# Launch with OpenRouter
ccc open kimi
```

## Available Providers

### Direct Providers

| Provider | Aliases | Region Support | Default Model |
|----------|---------|----------------|---------------|
| `deepseek` | `ds` | No | deepseek-chat |
| `kimi` | `kimi2` | global, china | kimi-k2.5 |
| `glm` | `glm5` | global, china | glm-5 |
| `qwen` | - | global, china | qwen3-max-2026-01-23 |
| `minimax` | `mm` | global, china | MiniMax-M2.5 |
| `seed` | `doubao` | Variants | ark-code-latest |
| `stepfun` | - | No | step-3.5-flash |
| `claude` | `sonnet`, `s` | No | claude-sonnet-4-5-20250929 |

### Seed Variants

The `seed` provider supports different model variants:

```bash
ccm seed              # Default: ark-code-latest
ccm seed doubao       # doubao-seed-code
ccm seed glm          # glm-5
ccm seed deepseek     # deepseek-v3.2
ccm seed kimi         # kimi-k2.5
```

### OpenRouter Mode

Access any provider via OpenRouter:

```bash
ccm open glm
ccm open kimi
ccm open deepseek
ccm open claude
```

## CLI Commands

### Model Switching

```bash
ccm deepseek                    # Switch to DeepSeek
ccm kimi china                  # Switch to Kimi China
ccm glm global                  # Switch to GLM Global
ccm seed kimi                   # Switch to Seed with Kimi variant
ccm open deepseek               # Switch via OpenRouter
ccm claude                      # Switch to Claude (Pro subscription)
```

### Status & Configuration

```bash
ccm status                      # Show current configuration
ccm config                      # Edit configuration file (~/.ccm_config)
ccm help                        # Show help
```

### Account Management (Claude Pro)

Manage multiple Claude Pro accounts:

```bash
ccm save-account work           # Save current account as "work"
ccm switch-account work         # Switch to "work" account
ccm list-accounts               # List all saved accounts
ccm delete-account work         # Delete "work" account
ccm current-account             # Show current account info
```

### Settings Management

Write persistent settings for Claude Code:

```bash
# Project-level (overrides user settings for this project)
ccm project glm global          # Use GLM for this project
ccm project show                # Show project settings
ccm project reset               # Remove project settings

# User-level (highest priority)
ccm user kimi china             # Use Kimi China globally
ccm user show                   # Show user settings
ccm user reset                  # Remove user settings
```

## Configuration

### Configuration File (~/.ccm_config)

Create or edit `~/.ccm_config` with your API keys:

```bash
# Language (en or zh)
CCM_LANGUAGE=en

# API Keys
DEEPSEEK_API_KEY=sk-your-deepseek-key
KIMI_API_KEY=your-kimi-key
GLM_API_KEY=your-glm-key
QWEN_API_KEY=your-qwen-key
MINIMAX_API_KEY=your-minimax-key
ARK_API_KEY=your-ark-key
STEPFUN_API_KEY=your-stepfun-key
CLAUDE_API_KEY=your-claude-key
OPENROUTER_API_KEY=your-openrouter-key

# Model overrides (optional)
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
GLM_MODEL=glm-5
```

### Priority Order

Settings are applied in this order (highest priority first):

1. **User settings**: `~/.claude/settings.json` (via `ccm user`)
2. **Project settings**: `.claude/settings.local.json` (via `ccm project`)
3. **Environment variables**: `export DEEPSEEK_API_KEY=...`
4. **Config file**: `~/.ccm_config`
5. **Built-in defaults**

## Environment Variables

After switching, these environment variables are set:

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_BASE_URL` | API endpoint URL |
| `ANTHROPIC_AUTH_TOKEN` | Authentication token |
| `ANTHROPIC_MODEL` | Model to use |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet model |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus model |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku model |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Subagent model |

## Development

### Setup Development Environment

```bash
# Clone and enter directory
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch

# Install with dev dependencies
uv sync --dev

# Run tests
uv run pytest tests/ -v

# Run with coverage
uv run pytest tests/ --cov=src/ccm

# Type check
uv run mypy src/ccm

# Lint
uv run ruff check .
uv run ruff format .
```

### Run CLI in Development

```bash
# Run ccm
uv run python -m ccm status

# Run ccc
uv run python -m ccm.cli.launcher deepseek
```

## Migration from Bash Version

The Python version is backward compatible with the Bash version:

| Bash Command | Python Equivalent | Notes |
|--------------|-------------------|-------|
| `ccm deepseek` | `ccm deepseek` | Same |
| `ccc glm global` | `ccc glm global` | Same |
| `ccm project glm` | `ccm project glm global` | Region now optional |
| `ccm user glm` | `ccm user glm global` | Region now optional |

### Key Differences

1. **Installation**: Use `uv tool install .` instead of `./install.sh`
2. **Config file**: Same format, same location
3. **Account storage**: Now uses proper keychain integration
4. **Translations**: Preserved in `lang/` directory

## Troubleshooting

### "Please configure X_API_KEY"

Set the API key in your config file or environment:

```bash
# Option 1: Environment variable
export DEEPSEEK_API_KEY=sk-your-key

# Option 2: Config file
echo "DEEPSEEK_API_KEY=sk-your-key" >> ~/.ccm_config

# Option 3: Edit config
ccm config
```

### Shell Functions Not Working

If `ccm` or `ccc` commands don't work as shell functions:

```bash
# Re-source the functions
source /path/to/shell/rc-functions.sh

# Or reinstall with RC injection
./install.sh --rc
source ~/.zshrc
```

### Claude Code Not Launching

Ensure Claude Code CLI is installed:

```bash
npm install -g @anthropic-ai/claude-code
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         CLI Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  ccm (main)  │  │ ccc (launcher)│  │   Typer/Rich    │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        Core Layer                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐    │
│  │  Config    │  │  Providers │  │  Shell Exports     │    │
│  └────────────┘  └────────────┘  └────────────────────┘    │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐    │
│  │  Keychain  │  │  Accounts  │  │  Translations      │    │
│  └────────────┘  └────────────┘  └────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                       Settings Layer                        │
│  ┌────────────────────┐  ┌────────────────────────────┐    │
│  │ Project Settings   │  │    User Settings           │    │
│  │ .claude/settings   │  │    ~/.claude/settings.json │    │
│  └────────────────────┘  └────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## License

MIT License - See [LICENSE](LICENSE) for details.

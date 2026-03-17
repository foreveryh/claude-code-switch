# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Claude Code Switch (CCM)** is a Python CLI that switches Claude Code between providers/models by exporting Anthropic-compatible environment variables. There is no automatic fallback; OpenRouter is an explicit command.

**Supported Providers (direct):** Claude (official), DeepSeek, Moonshot Kimi, Zhipu GLM, Alibaba Qwen (Coding Plan), MiniMax, Doubao/Seed (ARK)

**OpenRouter:** Explicit command (`ccm open <provider>`)

## Repository Structure

```
Claude-Code-Switch/
├── src/ccm/
│   ├── cli/              # CLI entry points (main.py, launcher.py)
│   ├── core/             # Core logic (config, exports, providers)
│   ├── settings/         # Project/user settings management
│   ├── shell/            # Shell integration (rc injection, wrappers)
│   └── providers/        # Provider configurations
├── tests/                # Unit and integration tests
├── docs/                 # Internal docs
└── README.md / README_CN.md / TROUBLESHOOTING.md / CHANGELOG.md
```

## Key Architecture & Design Patterns

### 1) Configuration hierarchy
Priority order:
1. Environment variables
2. `~/.ccm_config` (created on first run)
3. Built-in defaults

Key function: `is_effectively_set()` treats placeholder values as unset.

### 2) Environment export pattern
`ShellExportGenerator.generate_for_provider()` returns export statements which are `eval`'d by the caller:
```bash
export ANTHROPIC_BASE_URL=...
export ANTHROPIC_AUTH_TOKEN=...
export ANTHROPIC_MODEL=...
export ANTHROPIC_DEFAULT_SONNET_MODEL=...
export ANTHROPIC_DEFAULT_OPUS_MODEL=...
export ANTHROPIC_DEFAULT_HAIKU_MODEL=...
export CLAUDE_CODE_SUBAGENT_MODEL=...
```

### 3) Region-aware providers
Kimi / GLM / Qwen / MiniMax accept `global|china`:
- `ccm kimi [global|china]`
- `ccm glm [global|china]`
- `ccm qwen [global|china]`
- `ccm minimax [global|china]`

Normalization handled by `normalize_region()`.

### 4) OpenRouter (explicit)
OpenRouter is not a fallback. Use:
- `ccm open <provider>`

OpenRouter exports set:
- Base URL: `https://openrouter.ai/api`
- `ANTHROPIC_AUTH_TOKEN=$OPENROUTER_API_KEY`
- `ANTHROPIC_API_KEY=""` (avoid conflicts)

### 5) Project-only override
`ccm project glm [global|china]` writes `.claude/settings.local.json` so the provider applies only to the current project.

## Common Commands & Workflows

### Install (Python version)
```bash
# Using uv (recommended)
uv tool install git+https://github.com/foreveryh/claude-code-switch.git

# Or from source
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
uv tool install .
```

### Switch in current shell
```bash
eval "$(ccm deepseek)"
eval "$(ccm kimi china)"
```

### Launch Claude Code
```bash
ccc glm global
ccc open kimi
```

### Seed (ARK)
```bash
ccm seed              # ark-code-latest
ccm seed kimi         # kimi-k2.5
ccm seed deepseek     # deepseek-v3.2
```

## Code Organization

Key modules:
- `src/ccm/cli/main.py` - Typer CLI commands
- `src/ccm/cli/launcher.py` - `ccc` launcher logic
- `src/ccm/core/config.py` - Configuration loading
- `src/ccm/core/exports.py` - Shell export generation
- `src/ccm/core/providers.py` - Provider definitions
- `src/ccm/settings/project.py` - Project-level settings
- `src/ccm/settings/user.py` - User-level settings

## Adding a New Provider

1. Add provider config to `PROVIDERS` dict in `src/ccm/core/providers.py`
2. Add to help text in `src/ccm/cli/main.py`
3. Add to README.md and README_CN.md

## Development Workflow

### Development Commands

```bash
# Run tests
uv run pytest tests/ -v

# Run CLI directly
uv run ccm --help
uv run ccm status

# Type checking
uv run mypy src/

# Linting
uv run ruff check src/
```

## Coding Style

- Python 3.12+ with type hints
- Use Pydantic for data validation
- Typer for CLI, Rich for output
- Functions use `snake_case` naming
- Mask secrets on output using `mask_token()` pattern

## Testing

```bash
# Run all tests
uv run pytest tests/ -v

# Run specific test file
uv run pytest tests/unit/test_exports.py -v

# Run with coverage
uv run pytest tests/ --cov=src/ccm
```

## Security Notes

- Token masking in `ccm status`
- Recommend `chmod 600 ~/.ccm_config`
- Environment vars override config file (good for CI)

"""Configuration loading for CCM.

Handles loading configuration from:
1. Environment variables (highest priority)
2. ~/.ccm_config file
3. Built-in defaults
"""

import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class Config:
    """Configuration container."""

    # API Keys
    deepseek_api_key: str | None = None
    kimi_api_key: str | None = None
    glm_api_key: str | None = None
    qwen_api_key: str | None = None
    minimax_api_key: str | None = None
    ark_api_key: str | None = None
    stepfun_api_key: str | None = None
    claude_api_key: str | None = None
    openrouter_api_key: str | None = None

    # Model overrides
    deepseek_model: str | None = None
    kimi_model: str | None = None
    kimi_cn_model: str | None = None
    qwen_model: str | None = None
    glm_model: str | None = None
    claude_model: str | None = None
    opus_model: str | None = None
    haiku_model: str | None = None
    minimax_model: str | None = None
    seed_model: str | None = None
    stepfun_model: str | None = None

    # Language preference
    ccm_language: str = "en"

    # Raw config for dynamic access
    _raw: dict[str, str] = field(default_factory=dict, repr=False)

    def get(self, key: str, default: str | None = None) -> str | None:
        """Get a config value by key."""
        return getattr(self, key.lower(), default) or self._raw.get(key, default)

    def is_set(self, key: str) -> bool:
        """Check if a config value is effectively set (not a placeholder)."""
        value = self.get(key)
        return is_effectively_set(value)


# Placeholder patterns to detect unset values
PLACEHOLDER_PATTERNS = [
    re.compile(r"your-.*-api-key", re.IGNORECASE),
    re.compile(r"your_.*_api_key", re.IGNORECASE),
    re.compile(r"sk-your-.*", re.IGNORECASE),
]


def is_effectively_set(value: str | None) -> bool:
    """Check if a value is effectively set (not empty or a placeholder)."""
    if not value:
        return False

    value_lower = value.lower().strip()
    if not value_lower:
        return False

    # Check for placeholder patterns
    for pattern in PLACEHOLDER_PATTERNS:
        if pattern.search(value_lower):
            return False

    # Check for common placeholder text
    if "your" in value_lower and "api" in value_lower and "key" in value_lower:
        return False

    return True


def parse_config_file(content: str) -> dict[str, str]:
    """Parse config file content into a dictionary."""
    config: dict[str, str] = {}

    for line in content.splitlines():
        # Remove carriage return
        line = line.rstrip("\r")
        # Skip comments and empty lines
        line_stripped = line.strip()
        if not line_stripped or line_stripped.startswith("#"):
            continue

        # Remove inline comments
        if "#" in line:
            line = line[: line.index("#")]
            line_stripped = line.strip()

        if not line_stripped:
            continue

        # Parse KEY=VALUE or export KEY=VALUE
        match = re.match(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$", line_stripped)
        if match:
            key = match.group(1)
            value = match.group(2).strip()
            # Remove surrounding quotes if present
            if (value.startswith('"') and value.endswith('"')) or (
                value.startswith("'") and value.endswith("'")
            ):
                value = value[1:-1]
            config[key] = value

    return config


def load_config() -> Config:
    """Load configuration from environment and config file.

    Priority: Environment variables > Config file > Defaults
    """
    config_path = Path.home() / ".ccm_config"
    file_config: dict[str, str] = {}

    # Load from config file if it exists
    if config_path.exists():
        try:
            content = config_path.read_text(encoding="utf-8")
            file_config = parse_config_file(content)
        except OSError:
            pass

    def get_value(env_key: str) -> str | None:
        """Get value from environment or config file."""
        # Environment variable takes priority
        env_value = os.environ.get(env_key)
        if is_effectively_set(env_value):
            return env_value

        # Then check config file
        file_value = file_config.get(env_key)
        if is_effectively_set(file_value):
            return file_value

        return None

    return Config(
        deepseek_api_key=get_value("DEEPSEEK_API_KEY"),
        kimi_api_key=get_value("KIMI_API_KEY"),
        glm_api_key=get_value("GLM_API_KEY"),
        qwen_api_key=get_value("QWEN_API_KEY"),
        minimax_api_key=get_value("MINIMAX_API_KEY"),
        ark_api_key=get_value("ARK_API_KEY"),
        stepfun_api_key=get_value("STEPFUN_API_KEY"),
        claude_api_key=get_value("CLAUDE_API_KEY"),
        openrouter_api_key=get_value("OPENROUTER_API_KEY"),
        deepseek_model=get_value("DEEPSEEK_MODEL"),
        kimi_model=get_value("KIMI_MODEL"),
        kimi_cn_model=get_value("KIMI_CN_MODEL"),
        qwen_model=get_value("QWEN_MODEL"),
        glm_model=get_value("GLM_MODEL"),
        claude_model=get_value("CLAUDE_MODEL"),
        opus_model=get_value("OPUS_MODEL"),
        haiku_model=get_value("HAIKU_MODEL"),
        minimax_model=get_value("MINIMAX_MODEL"),
        seed_model=get_value("SEED_MODEL"),
        stepfun_model=get_value("STEPFUN_MODEL"),
        ccm_language=get_value("CCM_LANGUAGE") or "en",
        _raw=file_config,
    )


def create_default_config() -> str:
    """Generate default config file content."""
    return """# CCM 配置文件
# 请替换为你的实际API密钥
# 注意：环境变量中的API密钥优先级高于此文件

# 语言设置 (en: English, zh: 中文)
CCM_LANGUAGE=en

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI (月之暗面)
KIMI_API_KEY=your-kimi-api-key

# MiniMax
MINIMAX_API_KEY=your-minimax-api-key

# 豆包 Seed-Code (字节跳动)
ARK_API_KEY=your-ark-api-key

# StepFun
STEPFUN_API_KEY=your-stepfun-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# OpenRouter
OPENROUTER_API_KEY=your-openrouter-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
KIMI_CN_MODEL=kimi-k2.5
QWEN_MODEL=qwen3-max-2026-01-23
GLM_MODEL=glm-5
CLAUDE_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-6
HAIKU_MODEL=claude-haiku-4-5-20251001
MINIMAX_MODEL=MiniMax-M2.5
SEED_MODEL=ark-code-latest
STEPFUN_MODEL=step-3.5-flash
"""

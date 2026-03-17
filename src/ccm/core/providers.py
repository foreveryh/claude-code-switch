"""Provider definitions for CCM.

This module contains all provider configurations in a data-driven design.
Each provider has base URL, API key environment variable, default model,
and optional region-specific configurations.
"""

from dataclasses import dataclass, field
from typing import Any


@dataclass
class RegionConfig:
    """Configuration for a specific region."""

    base_url: str
    model_default: str
    model_env: str | None = None


@dataclass
class ProviderConfig:
    """Configuration for a provider."""

    name: str
    aliases: list[str] = field(default_factory=list)
    base_url: str | None = None
    auth_token_var: str | None = None
    model_default: str | None = None
    model_env: str | None = None
    # For region-aware providers
    regions: dict[str, RegionConfig] = field(default_factory=dict)
    # For providers with variants (like seed)
    variants: dict[str, str] = field(default_factory=dict)
    # Additional environment variables to set
    extra_env: dict[str, str] = field(default_factory=dict)
    # Description for help text
    description: str = ""

    def get_base_url(self, region: str | None = None) -> str:
        """Get base URL for the provider, optionally for a specific region."""
        if region and region in self.regions:
            return self.regions[region].base_url
        if self.base_url:
            return self.base_url
        raise ValueError(f"No base URL configured for provider {self.name}")

    def get_model_env(self, region: str | None = None) -> str | None:
        """Get model environment variable name."""
        if region and region in self.regions:
            return self.regions[region].model_env
        return self.model_env

    def get_model_default(self, region: str | None = None) -> str:
        """Get default model for the provider."""
        if region and region in self.regions:
            return self.regions[region].model_default
        if self.model_default:
            return self.model_default
        raise ValueError(f"No default model configured for provider {self.name}")


# All provider configurations
PROVIDERS: dict[str, ProviderConfig] = {
    "deepseek": ProviderConfig(
        name="deepseek",
        aliases=["ds"],
        base_url="https://api.deepseek.com/anthropic",
        auth_token_var="DEEPSEEK_API_KEY",
        model_default="deepseek-chat",
        model_env="DEEPSEEK_MODEL",
        description="DeepSeek AI",
    ),
    "kimi": ProviderConfig(
        name="kimi",
        aliases=["kimi2", "kimi-cn"],
        auth_token_var="KIMI_API_KEY",
        regions={
            "global": RegionConfig(
                base_url="https://api.moonshot.ai/anthropic",
                model_default="kimi-k2.5",
                model_env="KIMI_MODEL",
            ),
            "china": RegionConfig(
                base_url="https://api.kimi.com/coding",
                model_default="kimi-k2.5",
                model_env="KIMI_CN_MODEL",
            ),
        },
        description="Kimi (Moonshot AI)",
    ),
    "qwen": ProviderConfig(
        name="qwen",
        aliases=[],
        auth_token_var="QWEN_API_KEY",
        model_default="qwen3-max-2026-01-23",
        model_env="QWEN_MODEL",
        regions={
            "global": RegionConfig(
                base_url="https://coding-intl.dashscope.aliyuncs.com/apps/anthropic",
                model_default="qwen3-max-2026-01-23",
                model_env="QWEN_MODEL",
            ),
            "china": RegionConfig(
                base_url="https://coding.dashscope.aliyuncs.com/apps/anthropic",
                model_default="qwen3-max-2026-01-23",
                model_env="QWEN_MODEL",
            ),
        },
        description="Alibaba Qwen (DashScope)",
    ),
    "glm": ProviderConfig(
        name="glm",
        aliases=["glm5"],
        auth_token_var="GLM_API_KEY",
        model_default="glm-5",
        model_env="GLM_MODEL",
        regions={
            "global": RegionConfig(
                base_url="https://api.z.ai/api/anthropic",
                model_default="glm-5",
                model_env="GLM_MODEL",
            ),
            "china": RegionConfig(
                base_url="https://open.bigmodel.cn/api/anthropic",
                model_default="glm-5",
                model_env="GLM_MODEL",
            ),
        },
        description="Zhipu GLM",
    ),
    "minimax": ProviderConfig(
        name="minimax",
        aliases=["mm"],
        auth_token_var="MINIMAX_API_KEY",
        model_default="MiniMax-M2.5",
        model_env="MINIMAX_MODEL",
        regions={
            "global": RegionConfig(
                base_url="https://api.minimax.io/anthropic",
                model_default="MiniMax-M2.5",
                model_env="MINIMAX_MODEL",
            ),
            "china": RegionConfig(
                base_url="https://api.minimaxi.com/anthropic",
                model_default="MiniMax-M2.5",
                model_env="MINIMAX_MODEL",
            ),
        },
        description="MiniMax",
    ),
    "seed": ProviderConfig(
        name="seed",
        aliases=["doubao"],
        base_url="https://ark.cn-beijing.volces.com/api/coding",
        auth_token_var="ARK_API_KEY",
        model_default="ark-code-latest",
        model_env="SEED_MODEL",
        variants={
            "default": "ark-code-latest",
            "doubao": "doubao-seed-code",
            "seed": "doubao-seed-code",
            "glm": "glm-5",
            "glm5": "glm-5",
            "deepseek": "deepseek-v3.2",
            "ds": "deepseek-v3.2",
            "kimi": "kimi-k2.5",
            "kimi2": "kimi-k2.5",
            "kimi-k2.5": "kimi-k2.5",
        },
        description="Doubao/Seed (ByteDance ARK)",
    ),
    "stepfun": ProviderConfig(
        name="stepfun",
        aliases=[],
        base_url="https://api.stepfun.ai/v1/anthropic",
        auth_token_var="STEPFUN_API_KEY",
        model_default="step-3.5-flash",
        model_env="STEPFUN_MODEL",
        description="StepFun",
    ),
    "claude": ProviderConfig(
        name="claude",
        aliases=["sonnet", "s"],
        base_url="https://api.anthropic.com/",
        auth_token_var="CLAUDE_API_KEY",  # Optional, uses Pro subscription if not set
        model_default="claude-sonnet-4-5-20250929",
        model_env="CLAUDE_MODEL",
        extra_env={
            "OPUS_MODEL": "claude-opus-4-6",
            "HAIKU_MODEL": "claude-haiku-4-5-20251001",
        },
        description="Claude (Official Anthropic)",
    ),
}

# OpenRouter provider mapping
OPENROUTER_PROVIDERS: dict[str, dict[str, Any]] = {
    "glm": {
        "model": "zhipu/glm-4-plus",
        "name": "GLM (via OpenRouter)",
    },
    "kimi": {
        "model": "moonshot/kimi-k2.5",
        "name": "Kimi (via OpenRouter)",
    },
    "deepseek": {
        "model": "deepseek/deepseek-chat",
        "name": "DeepSeek (via OpenRouter)",
    },
    "minimax": {
        "model": "minimax/minimax-m1",
        "name": "MiniMax (via OpenRouter)",
    },
    "qwen": {
        "model": "qwen/qwen-2.5-72b-instruct",
        "name": "Qwen (via OpenRouter)",
    },
    "stepfun": {
        "model": "stepfun/step-3-flash",
        "name": "StepFun (via OpenRouter)",
    },
    "claude": {
        "model": "anthropic/claude-sonnet-4",
        "name": "Claude (via OpenRouter)",
    },
}


def get_provider(name: str) -> tuple[ProviderConfig, str] | None:
    """Get provider by name or alias.

    Returns tuple of (ProviderConfig, canonical_name) or None if not found.
    """
    # Direct lookup
    if name in PROVIDERS:
        return PROVIDERS[name], name

    # Alias lookup
    for canonical, config in PROVIDERS.items():
        if name in config.aliases:
            return config, canonical

    return None


def normalize_region(region: str | None) -> str:
    """Normalize region input to 'global' or 'china'."""
    if region is None:
        return "global"

    region_lower = region.lower()
    if region_lower in ("", "global", "g", "intl", "international", "overseas"):
        return "global"
    if region_lower in ("china", "cn", "zh", "domestic"):
        return "china"

    raise ValueError(f"Unknown region: {region}")


def get_openrouter_provider(name: str) -> dict[str, Any] | None:
    """Get OpenRouter provider configuration by name."""
    return OPENROUTER_PROVIDERS.get(name.lower())

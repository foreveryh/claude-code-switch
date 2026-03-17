"""Pytest configuration and fixtures."""

import os
from pathlib import Path
from typing import Generator

import pytest


@pytest.fixture
def clean_env(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    """Clean environment variables for testing."""
    env_vars_to_clean = [
        "DEEPSEEK_API_KEY",
        "KIMI_API_KEY",
        "GLM_API_KEY",
        "QWEN_API_KEY",
        "MINIMAX_API_KEY",
        "ARK_API_KEY",
        "STEPFUN_API_KEY",
        "CLAUDE_API_KEY",
        "OPENROUTER_API_KEY",
        "CCM_LANGUAGE",
        "ANTHROPIC_BASE_URL",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_AUTH_TOKEN",
    ]

    for var in env_vars_to_clean:
        monkeypatch.delenv(var, raising=False)

    yield


@pytest.fixture
def temp_config_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Create a temporary config file for testing."""
    config_content = """# Test config
DEEPSEEK_API_KEY=sk-test-deepseek-key
KIMI_API_KEY=test-kimi-key
GLM_API_KEY=test-glm-key
DEEPSEEK_MODEL=deepseek-chat
"""

    config_file = tmp_path / ".ccm_config"
    config_file.write_text(config_content)

    # Monkeypatch the config path
    import ccm.core.config

    original_path = Path.home() / ".ccm_config"
    monkeypatch.setattr(ccm.core.config.Path, "home", lambda: tmp_path)

    yield config_file


@pytest.fixture
def sample_config_content() -> str:
    """Sample config file content."""
    return """# CCM Configuration
CCM_LANGUAGE=en

DEEPSEEK_API_KEY=sk-test123456
KIMI_API_KEY=test-kimi-key
GLM_API_KEY=test-glm-key
DEEPSEEK_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2.5
"""

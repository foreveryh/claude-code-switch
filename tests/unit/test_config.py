"""Tests for configuration loading."""

import os
from pathlib import Path

import pytest

from ccm.core.config import (
    Config,
    create_default_config,
    is_effectively_set,
    load_config,
    parse_config_file,
)


class TestIsEffectivelySet:
    """Tests for is_effectively_set function."""

    def test_none_value(self) -> None:
        """None should not be effectively set."""
        assert is_effectively_set(None) is False

    def test_empty_string(self) -> None:
        """Empty string should not be effectively set."""
        assert is_effectively_set("") is False
        assert is_effectively_set("   ") is False

    def test_valid_value(self) -> None:
        """Valid values should be effectively set."""
        assert is_effectively_set("sk-123456") is True
        assert is_effectively_set("my-api-key") is True

    def test_placeholder_patterns(self) -> None:
        """Placeholder patterns should not be effectively set."""
        assert is_effectively_set("sk-your-deepseek-api-key") is False
        assert is_effectively_set("your-api-key") is False
        assert is_effectively_set("YOUR_API_KEY") is False
        assert is_effectively_set("your-glm-api-key") is False


class TestParseConfigFile:
    """Tests for parse_config_file function."""

    def test_basic_parsing(self) -> None:
        """Test basic config parsing."""
        content = """
DEEPSEEK_API_KEY=sk-test123
KIMI_API_KEY=test-key
"""
        result = parse_config_file(content)
        assert result["DEEPSEEK_API_KEY"] == "sk-test123"
        assert result["KIMI_API_KEY"] == "test-key"

    def test_export_prefix(self) -> None:
        """Test parsing lines with export prefix."""
        content = """
export DEEPSEEK_API_KEY=sk-test123
export KIMI_API_KEY="test-key"
"""
        result = parse_config_file(content)
        assert result["DEEPSEEK_API_KEY"] == "sk-test123"
        assert result["KIMI_API_KEY"] == "test-key"

    def test_comments(self) -> None:
        """Test that comments are ignored."""
        content = """
# This is a comment
DEEPSEEK_API_KEY=sk-test123
# Another comment
"""
        result = parse_config_file(content)
        assert result["DEEPSEEK_API_KEY"] == "sk-test123"
        assert len(result) == 1

    def test_inline_comments(self) -> None:
        """Test that inline comments are removed."""
        content = """
DEEPSEEK_API_KEY=sk-test123  # this is the key
"""
        result = parse_config_file(content)
        assert result["DEEPSEEK_API_KEY"] == "sk-test123"

    def test_quoted_values(self) -> None:
        """Test parsing quoted values."""
        content = """
KEY1='value with spaces'
KEY2="double quoted"
"""
        result = parse_config_file(content)
        assert result["KEY1"] == "value with spaces"
        assert result["KEY2"] == "double quoted"

    def test_empty_lines(self) -> None:
        """Test that empty lines are ignored."""
        content = """

DEEPSEEK_API_KEY=sk-test123


KIMI_API_KEY=test-key
"""
        result = parse_config_file(content)
        assert len(result) == 2


class TestCreateDefaultConfig:
    """Tests for create_default_config function."""

    def test_creates_valid_config(self) -> None:
        """Test that default config is created."""
        content = create_default_config()
        assert "DEEPSEEK_API_KEY" in content
        assert "KIMI_API_KEY" in content
        assert "GLM_API_KEY" in content
        assert "CCM_LANGUAGE" in content


class TestConfig:
    """Tests for Config class."""

    def test_default_values(self) -> None:
        """Test default config values."""
        config = Config()
        assert config.deepseek_api_key is None
        assert config.kimi_api_key is None
        assert config.ccm_language == "en"

    def test_get_method(self) -> None:
        """Test Config.get method."""
        config = Config(deepseek_api_key="sk-test")
        assert config.get("deepseek_api_key") == "sk-test"
        assert config.get("nonexistent", "default") == "default"

    def test_is_set_method(self) -> None:
        """Test Config.is_set method."""
        config = Config(deepseek_api_key="sk-test")
        assert config.is_set("deepseek_api_key") is True
        assert config.is_set("kimi_api_key") is False

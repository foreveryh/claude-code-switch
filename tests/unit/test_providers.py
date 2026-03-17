"""Tests for provider definitions."""

import pytest

from ccm.core.providers import (
    OPENROUTER_PROVIDERS,
    ProviderConfig,
    RegionConfig,
    get_openrouter_provider,
    get_provider,
    normalize_region,
)


class TestProviderConfig:
    """Tests for ProviderConfig class."""

    def test_simple_provider(self) -> None:
        """Test simple provider without regions."""
        config = ProviderConfig(
            name="test",
            base_url="https://api.test.com",
            auth_token_var="TEST_API_KEY",
            model_default="test-model",
        )
        assert config.get_base_url() == "https://api.test.com"
        assert config.get_model_default() == "test-model"

    def test_region_aware_provider(self) -> None:
        """Test provider with regions."""
        config = ProviderConfig(
            name="test",
            regions={
                "global": RegionConfig(
                    base_url="https://global.api.test.com",
                    model_default="global-model",
                ),
                "china": RegionConfig(
                    base_url="https://china.api.test.com",
                    model_default="china-model",
                ),
            },
        )
        assert config.get_base_url("global") == "https://global.api.test.com"
        assert config.get_base_url("china") == "https://china.api.test.com"
        assert config.get_model_default("global") == "global-model"

    def test_get_base_url_raises_without_config(self) -> None:
        """Test that get_base_url raises when no config available."""
        config = ProviderConfig(name="test")
        with pytest.raises(ValueError):
            config.get_base_url()


class TestGetProvider:
    """Tests for get_provider function."""

    def test_get_by_name(self) -> None:
        """Test getting provider by name."""
        result = get_provider("deepseek")
        assert result is not None
        config, name = result
        assert name == "deepseek"
        assert config.name == "deepseek"

    def test_get_by_alias(self) -> None:
        """Test getting provider by alias."""
        result = get_provider("ds")
        assert result is not None
        config, name = result
        assert name == "deepseek"

    def test_get_unknown_provider(self) -> None:
        """Test getting unknown provider returns None."""
        assert get_provider("unknown_provider") is None

    def test_all_providers_accessible(self) -> None:
        """Test that all providers are accessible."""
        providers = ["deepseek", "kimi", "qwen", "glm", "minimax", "seed", "stepfun", "claude"]
        for provider in providers:
            result = get_provider(provider)
            assert result is not None, f"Provider {provider} not found"


class TestNormalizeRegion:
    """Tests for normalize_region function."""

    def test_global_region(self) -> None:
        """Test global region normalization."""
        assert normalize_region(None) == "global"
        assert normalize_region("") == "global"
        assert normalize_region("global") == "global"
        assert normalize_region("g") == "global"
        assert normalize_region("intl") == "global"
        assert normalize_region("INTERNATIONAL") == "global"
        assert normalize_region("overseas") == "global"

    def test_china_region(self) -> None:
        """Test china region normalization."""
        assert normalize_region("china") == "china"
        assert normalize_region("cn") == "china"
        assert normalize_region("zh") == "china"
        assert normalize_region("domestic") == "china"
        assert normalize_region("CHINA") == "china"

    def test_unknown_region(self) -> None:
        """Test unknown region raises error."""
        with pytest.raises(ValueError):
            normalize_region("unknown")


class TestOpenRouterProviders:
    """Tests for OpenRouter providers."""

    def test_openrouter_providers_exist(self) -> None:
        """Test that OpenRouter providers are defined."""
        expected = ["glm", "kimi", "deepseek", "minimax", "qwen", "stepfun", "claude"]
        for provider in expected:
            assert provider in OPENROUTER_PROVIDERS

    def test_get_openrouter_provider(self) -> None:
        """Test getting OpenRouter provider config."""
        result = get_openrouter_provider("kimi")
        assert result is not None
        assert "model" in result
        assert "name" in result

    def test_get_unknown_openrouter_provider(self) -> None:
        """Test getting unknown OpenRouter provider returns None."""
        assert get_openrouter_provider("unknown") is None

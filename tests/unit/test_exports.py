"""Tests for shell export generation."""

import os
from unittest.mock import patch

import pytest

from ccm.core.config import Config
from ccm.core.exports import ExportConfig, ShellExportGenerator


class TestShellExportGenerator:
    """Tests for ShellExportGenerator class."""

    def setup_method(self) -> None:
        """Set up test fixtures."""
        self.config = Config(
            deepseek_api_key="sk-test-deepseek",
            kimi_api_key="test-kimi-key",
            glm_api_key="test-glm-key",
            openrouter_api_key="test-or-key",
        )
        self.generator = ShellExportGenerator(self.config)

    def test_unset_all(self) -> None:
        """Test unset all statement generation."""
        result = self.generator._unset_all()
        assert "unset" in result
        assert "ANTHROPIC_BASE_URL" in result
        assert "ANTHROPIC_MODEL" in result

    def test_export_simple_value(self) -> None:
        """Test simple export generation."""
        result = self.generator._export("TEST_VAR", "test_value")
        assert "export TEST_VAR=" in result
        assert "test_value" in result

    def test_export_value_with_quotes(self) -> None:
        """Test export with value containing quotes."""
        result = self.generator._export("TEST_VAR", "value'with'quotes")
        assert "export TEST_VAR=" in result
        # Single quotes should be escaped

    def test_export_var_reference(self) -> None:
        """Test export with variable reference."""
        result = self.generator._export_var("ANTHROPIC_AUTH_TOKEN", "DEEPSEEK_API_KEY")
        assert 'export ANTHROPIC_AUTH_TOKEN="${DEEPSEEK_API_KEY}"' in result

    def test_generate_exports_complete(self) -> None:
        """Test complete export generation."""
        export_config = ExportConfig(
            base_url="https://api.test.com",
            auth_token_var="TEST_API_KEY",
            model="test-model",
            sonnet_model="sonnet-model",
            opus_model="opus-model",
            haiku_model="haiku-model",
        )

        result = self.generator.generate_exports(export_config)

        assert "unset" in result
        assert "export ANTHROPIC_BASE_URL=" in result
        assert "https://api.test.com" in result
        assert "export ANTHROPIC_MODEL=" in result
        assert "test-model" in result
        assert "ANTHROPIC_DEFAULT_SONNET_MODEL" in result
        assert "ANTHROPIC_DEFAULT_OPUS_MODEL" in result
        assert "ANTHROPIC_DEFAULT_HAIKU_MODEL" in result
        assert "CLAUDE_CODE_SUBAGENT_MODEL" in result

    def test_generate_for_deepseek(self) -> None:
        """Test generation for DeepSeek provider."""
        exports, success = self.generator.generate_for_provider("deepseek")

        assert success is True
        assert "export ANTHROPIC_BASE_URL=" in exports
        assert "api.deepseek.com" in exports
        assert "export ANTHROPIC_AUTH_TOKEN=" in exports
        assert "DEEPSEEK_API_KEY" in exports

    def test_generate_for_kimi_global(self) -> None:
        """Test generation for Kimi global region."""
        exports, success = self.generator.generate_for_provider("kimi", "global")

        assert success is True
        assert "api.moonshot.ai" in exports

    def test_generate_for_kimi_china(self) -> None:
        """Test generation for Kimi china region."""
        exports, success = self.generator.generate_for_provider("kimi", "china")

        assert success is True
        assert "api.kimi.com" in exports

    def test_generate_for_unknown_provider(self) -> None:
        """Test generation for unknown provider."""
        exports, success = self.generator.generate_for_provider("unknown")

        assert success is False
        assert "Unknown provider" in exports

    def test_generate_for_missing_api_key(self) -> None:
        """Test generation with missing API key."""
        config = Config()  # No API keys set
        generator = ShellExportGenerator(config)

        exports, success = generator.generate_for_provider("deepseek")

        assert success is False
        assert "Please configure" in exports

    def test_generate_for_openrouter(self) -> None:
        """Test generation for OpenRouter."""
        exports, success = self.generator.generate_for_openrouter("kimi")

        assert success is True
        assert "openrouter.ai" in exports
        assert "OPENROUTER_API_KEY" in exports

    def test_generate_for_openrouter_unknown_provider(self) -> None:
        """Test OpenRouter with unknown provider."""
        exports, success = self.generator.generate_for_openrouter("unknown")

        assert success is False
        assert "Unknown OpenRouter provider" in exports

    def test_generate_for_openrouter_missing_key(self) -> None:
        """Test OpenRouter with missing API key."""
        config = Config()
        generator = ShellExportGenerator(config)

        exports, success = generator.generate_for_openrouter("kimi")

        assert success is False
        assert "OPENROUTER_API_KEY" in exports

    def test_generate_for_seed_with_variant(self) -> None:
        """Test generation for Seed with variant."""
        config = Config(ark_api_key="test-ark-key")
        generator = ShellExportGenerator(config)

        exports, success = generator.generate_for_provider("seed", variant="deepseek")

        assert success is True
        assert "deepseek-v3.2" in exports

    def test_generate_for_claude_without_key(self) -> None:
        """Test generation for Claude without API key (Pro subscription)."""
        config = Config()
        generator = ShellExportGenerator(config)

        exports, success = generator.generate_for_provider("claude")

        # Claude should work without API key (Pro subscription)
        assert success is True
        assert "api.anthropic.com" in exports


class TestExportConfig:
    """Tests for ExportConfig dataclass."""

    def test_defaults(self) -> None:
        """Test default values."""
        config = ExportConfig()
        assert config.base_url is None
        assert config.auth_token_var is None
        assert config.model is None

    def test_full_config(self) -> None:
        """Test full configuration."""
        config = ExportConfig(
            base_url="https://test.com",
            auth_token_var="TEST_KEY",
            model="test-model",
            sonnet_model="sonnet",
            opus_model="opus",
            haiku_model="haiku",
            extra_env={"FOO": "bar"},
        )
        assert config.base_url == "https://test.com"
        assert config.model == "test-model"
        assert config.extra_env == {"FOO": "bar"}

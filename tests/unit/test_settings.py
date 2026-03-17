"""Tests for settings management."""

import json
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

from ccm.settings.project import (
    get_project_settings_path,
    is_ccm_managed,
    write_project_settings,
    reset_project_settings,
)
from ccm.settings.user import (
    get_user_settings_path,
    is_ccm_managed as is_user_ccm_managed,
    write_user_settings,
    reset_user_settings,
)


class TestProjectSettings:
    """Tests for project-level settings."""

    def test_get_project_settings_path(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test getting project settings path."""
        monkeypatch.chdir(tmp_path)
        path = get_project_settings_path()
        assert path == tmp_path / ".claude" / "settings.local.json"

    def test_is_ccm_managed_true(self, tmp_path: Path) -> None:
        """Test detecting CCM-managed settings."""
        settings_file = tmp_path / "settings.json"
        settings_file.write_text(json.dumps({"ccmManaged": True, "env": {}}))
        assert is_ccm_managed(settings_file) is True

    def test_is_ccm_managed_false(self, tmp_path: Path) -> None:
        """Test detecting non-CCM-managed settings."""
        settings_file = tmp_path / "settings.json"
        settings_file.write_text(json.dumps({"env": {}}))
        assert is_ccm_managed(settings_file) is False

    def test_is_ccm_managed_no_file(self, tmp_path: Path) -> None:
        """Test detecting CCM-managed when no file exists."""
        settings_file = tmp_path / "nonexistent.json"
        assert is_ccm_managed(settings_file) is False

    def test_write_project_settings_deepseek(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test writing project settings for DeepSeek."""
        monkeypatch.chdir(tmp_path)

        with patch("ccm.settings.project.load_config") as mock_load:
            mock_config = MagicMock()
            mock_config.get.return_value = "sk-test-key"
            mock_load.return_value = mock_config

            result = write_project_settings("deepseek", config=mock_config)
            assert result is True

        # Check the file was created
        settings_path = tmp_path / ".claude" / "settings.local.json"
        assert settings_path.exists()

        data = json.loads(settings_path.read_text())
        assert data["ccmManaged"] is True
        assert data["ccmProvider"] == "deepseek"
        assert "deepseek.com" in data["env"]["ANTHROPIC_BASE_URL"]

    def test_write_project_settings_missing_key(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """Test writing project settings with missing API key."""
        monkeypatch.chdir(tmp_path)

        with patch("ccm.settings.project.load_config") as mock_load:
            mock_config = MagicMock()
            mock_config.get.return_value = None
            mock_load.return_value = mock_config

            result = write_project_settings("deepseek", config=mock_config)
            assert result is False


class TestUserSettings:
    """Tests for user-level settings."""

    def test_get_user_settings_path(self) -> None:
        """Test getting user settings path."""
        path = get_user_settings_path()
        assert ".claude" in str(path)
        assert "settings.json" in str(path)

    def test_write_user_settings_kimi(self, tmp_path: Path) -> None:
        """Test writing user settings for Kimi."""
        settings_path = tmp_path / "settings.json"

        with patch("ccm.settings.user.get_user_settings_path", return_value=settings_path):
            with patch("ccm.settings.user.load_config") as mock_load:
                mock_config = MagicMock()
                mock_config.get.return_value = "test-kimi-key"
                mock_load.return_value = mock_config

                result = write_user_settings("kimi", "global", config=mock_config)
                assert result is True

        # Check the file was created
        assert settings_path.exists()

        data = json.loads(settings_path.read_text())
        assert data["ccmManaged"] is True
        assert data["ccmProvider"] == "kimi"
        assert data["ccmRegion"] == "global"
        assert "moonshot.ai" in data["env"]["ANTHROPIC_BASE_URL"]

    def test_reset_user_settings_ccm_managed(self, tmp_path: Path) -> None:
        """Test resetting CCM-managed user settings."""
        settings_path = tmp_path / "settings.json"
        settings_path.write_text(json.dumps({"ccmManaged": True, "env": {}}))

        with patch("ccm.settings.user.get_user_settings_path", return_value=settings_path):
            result = reset_user_settings()

        assert result is True
        assert not settings_path.exists()

    def test_reset_user_settings_not_ccm_managed(self, tmp_path: Path) -> None:
        """Test resetting non-CCM-managed user settings."""
        settings_path = tmp_path / "settings.json"
        settings_path.write_text(json.dumps({"env": {}}))

        with patch("ccm.settings.user.get_user_settings_path", return_value=settings_path):
            result = reset_user_settings()

        # Should not delete non-CCM-managed settings
        assert result is True
        assert settings_path.exists()

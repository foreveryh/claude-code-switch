"""Integration tests for CLI functionality."""

import subprocess
import sys
from pathlib import Path


class TestCLIIntegration:
    """Integration tests for CLI commands."""

    def test_help_command(self) -> None:
        """Test help command runs successfully."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "help"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 0
        assert "Claude Code" in result.stderr or "usage" in result.stderr.lower()

    def test_status_command(self) -> None:
        """Test status command runs successfully."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "status"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 0
        # Status outputs to stderr
        assert "Environment" in result.stderr or "config" in result.stderr.lower()

    def test_deepseek_export_without_key(self) -> None:
        """Test DeepSeek export fails gracefully without API key."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "deepseek"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
            env={},  # Clean environment
        )
        assert result.returncode == 1
        assert "DEEPSEEK_API_KEY" in result.stderr or "configure" in result.stderr.lower()

    def test_claude_export_works(self) -> None:
        """Test Claude export works (supports Pro subscription)."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "claude"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 0
        # Check that output is valid shell syntax
        assert "export ANTHROPIC_BASE_URL=" in result.stdout
        assert "api.anthropic.com" in result.stdout

    def test_export_output_is_shell_compatible(self) -> None:
        """Test that export output can be parsed by shell."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "claude"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
        )
        assert result.returncode == 0

        # Verify the output can be parsed by bash
        # Use printf to avoid issues with newlines and semicolons
        verify_result = subprocess.run(
            ["bash", "-c", result.stdout + "\necho $ANTHROPIC_BASE_URL"],
            capture_output=True,
            text=True,
        )
        assert "anthropic.com" in verify_result.stdout


class TestEvalPattern:
    """Tests for eval pattern functionality."""

    def test_eval_pattern_deepseek_with_key(self) -> None:
        """Test eval pattern with DeepSeek when key is set."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "deepseek"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
            env={"DEEPSEEK_API_KEY": "sk-test-key-12345"},
        )
        assert result.returncode == 0

        # Verify shell can eval the output - add newline before echo
        verify = subprocess.run(
            ["bash", "-c", result.stdout + "\necho URL:$ANTHROPIC_BASE_URL"],
            capture_output=True,
            text=True,
        )
        assert "deepseek.com" in verify.stdout

    def test_eval_pattern_kimi_china(self) -> None:
        """Test eval pattern with Kimi China region."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "kimi", "china"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
            env={"KIMI_API_KEY": "test-kimi-key"},
        )
        assert result.returncode == 0

        verify = subprocess.run(
            ["bash", "-c", result.stdout + "\necho URL:$ANTHROPIC_BASE_URL"],
            capture_output=True,
            text=True,
        )
        assert "api.kimi.com" in verify.stdout

    def test_eval_pattern_openrouter(self) -> None:
        """Test eval pattern with OpenRouter."""
        result = subprocess.run(
            [sys.executable, "-m", "ccm", "open", "kimi"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent.parent,
            env={"OPENROUTER_API_KEY": "test-or-key"},
        )
        assert result.returncode == 0

        verify = subprocess.run(
            ["bash", "-c", result.stdout + "\necho URL:$ANTHROPIC_BASE_URL"],
            capture_output=True,
            text=True,
        )
        assert "openrouter.ai" in verify.stdout

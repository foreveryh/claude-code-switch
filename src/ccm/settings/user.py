"""User-level settings management.

Writes provider configuration to ~/.claude/settings.json
for user-wide Claude Code configuration.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any

from rich.console import Console

from ccm.core.config import Config, is_effectively_set, load_config
from ccm.core.providers import ProviderConfig, get_provider, normalize_region

console = Console(stderr=True)

USER_SETTINGS_PATH = Path.home() / ".claude" / "settings.json"


def get_user_settings_path() -> Path:
    """Get the path to user-level settings."""
    return USER_SETTINGS_PATH


def backup_settings(path: Path) -> None:
    """Backup existing settings file."""
    if not path.exists():
        return

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = path.with_suffix(f".json.bak.{ts}")
    path.rename(backup_path)
    console.print(f"[yellow]Backup created: {backup_path}[/yellow]")


def is_ccm_managed(path: Path) -> bool:
    """Check if settings file is managed by CCM."""
    if not path.exists():
        return False

    try:
        data = json.loads(path.read_text())
        return data.get("ccmManaged", False) is True
    except (json.JSONDecodeError, OSError):
        return False


def write_user_settings(
    provider_name: str,
    region: str | None = None,
    config: Config | None = None,
) -> bool:
    """Write user-level settings for a provider.

    Args:
        provider_name: Provider name (e.g., 'glm', 'deepseek')
        region: Region for region-aware providers (e.g., 'global', 'china')
        config: Config instance (will load if not provided)

    Returns:
        True if successful, False otherwise
    """
    if config is None:
        config = load_config()

    result = get_provider(provider_name)
    if result is None:
        console.print(f"[red]❌ Unknown provider: {provider_name}[/red]")
        return False

    provider, canonical_name = result

    # Normalize region if provider supports it
    if provider.regions:
        try:
            region = normalize_region(region)
        except ValueError as e:
            console.print(f"[red]❌ {e}[/red]")
            console.print(f"[yellow]💡 Usage: ccm user {provider_name} [global|china][/yellow]")
            return False

    # Check API key
    if not is_effectively_set(config.get(provider.auth_token_var or "")):
        # Special case: Claude can work without API key
        if canonical_name != "claude":
            console.print(f"[red]❌ Please configure {provider.auth_token_var} first[/red]")
            return False

    # Get configuration values
    base_url = provider.get_base_url(region)
    model_env = provider.get_model_env(region)
    model_default = provider.get_model_default(region)

    model = config.get(model_env or "") or model_default

    # Get API key value (not the variable name)
    api_key_value = None
    if provider.auth_token_var:
        api_key_value = config.get(provider.auth_token_var)

    # Build settings
    settings: dict[str, Any] = {
        "ccmManaged": True,
        "ccmProvider": canonical_name,
        "ccmRegion": region,
        "env": {
            "ANTHROPIC_BASE_URL": base_url,
            "ANTHROPIC_MODEL": model,
            "ANTHROPIC_DEFAULT_SONNET_MODEL": model,
            "ANTHROPIC_DEFAULT_OPUS_MODEL": model,
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": model,
            "CLAUDE_CODE_SUBAGENT_MODEL": model,
        },
    }

    if api_key_value:
        settings["env"]["ANTHROPIC_AUTH_TOKEN"] = api_key_value

    # Write settings
    settings_path = get_user_settings_path()
    settings_dir = settings_path.parent

    # Backup existing if not CCM-managed
    if settings_path.exists() and not is_ccm_managed(settings_path):
        backup_settings(settings_path)

    # Create directory
    settings_dir.mkdir(parents=True, exist_ok=True)

    # Write file
    settings_path.write_text(json.dumps(settings, indent=2))
    os.chmod(settings_path, 0o600)

    region_str = f" ({region})" if region else ""
    console.print(f"[green]✅ Wrote user-level settings for {canonical_name}{region_str}[/green]")
    console.print(f"[blue]   File: {settings_path}[/blue]")
    console.print(f"[yellow]💡 This overrides environment variables and takes highest priority.[/yellow]")
    console.print(f"[yellow]💡 Use 'ccm user reset' to restore environment variable control.[/yellow]")

    return True


def reset_user_settings() -> bool:
    """Remove user-level settings."""
    settings_path = get_user_settings_path()

    if not settings_path.exists():
        console.print(f"[yellow]⚠️  No user settings to reset at: {settings_path}[/yellow]")
        return True

    if not is_ccm_managed(settings_path):
        console.print(f"[yellow]⚠️  Settings file is not managed by CCM. Not modifying.[/yellow]")
        console.print(f"[yellow]   File: {settings_path}[/yellow]")
        return True

    settings_path.unlink()
    console.print(f"[green]✅ Removed user settings: {settings_path}[/green]")
    console.print(f"[yellow]💡 Environment variables and project settings will be used.[/yellow]")

    return True


def show_user_settings() -> None:
    """Show current user settings."""
    settings_path = get_user_settings_path()

    if not settings_path.exists():
        console.print("[yellow]No user settings configured.[/yellow]")
        console.print("[blue]Use 'ccm user <provider> [region]' to set.[/blue]")
        return

    try:
        data = json.loads(settings_path.read_text())

        console.print(f"[bold]User settings:[/bold] {settings_path}")
        console.print()

        if data.get("ccmManaged"):
            provider = data.get("ccmProvider", "unknown")
            region = data.get("ccmRegion")
            console.print(f"[cyan]Provider:[/cyan] {provider}")
            if region:
                console.print(f"[cyan]Region:[/cyan] {region}")

        if "env" in data:
            console.print("[bold]Environment variables:[/bold]")
            for key, value in data["env"].items():
                # Mask sensitive values
                if "TOKEN" in key or "KEY" in key:
                    if value and len(value) > 8:
                        value = f"{value[:4]}...{value[-4:]}"
                console.print(f"  [blue]{key}:[/blue] {value}")

    except (json.JSONDecodeError, OSError) as e:
        console.print(f"[red]Error reading settings: {e}[/red]")

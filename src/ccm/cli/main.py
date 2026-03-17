"""Main CLI entry point for CCM."""

import sys
from typing import Optional

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from ccm.core.config import Config, create_default_config, is_effectively_set, load_config
from ccm.core.exports import ShellExportGenerator
from ccm.core.providers import (
    OPENROUTER_PROVIDERS,
    get_openrouter_provider,
    get_provider,
    normalize_region,
)

app = typer.Typer(
    name="ccm",
    help="Claude Code Model Switcher - Switch between AI providers for Claude Code CLI",
    no_args_is_help=False,
    add_completion=False,
)

console = Console(stderr=True)


def _get_config() -> Config:
    """Load and return config."""
    return load_config()


def _get_generator(config: Config | None = None) -> ShellExportGenerator:
    """Get export generator."""
    return ShellExportGenerator(config)


def _is_eval_command() -> bool:
    """Check if we're being run for eval (stdout will be captured)."""
    return not sys.stdout.isatty()


@app.callback(invoke_without_command=True)
def main(
    ctx: typer.Context,
    help_flag: bool = typer.Option(
        False, "--help", "-h", is_flag=True, help="Show this help message"
    ),
):
    """CCM - Claude Code Model Switcher."""
    if help_flag:
        show_help()
        raise typer.Exit(0)

    if ctx.invoked_subcommand is None:
        show_help()
        raise typer.Exit(0)


@app.command("help")
def help_cmd():
    """Show help information."""
    show_help()


def show_help():
    """Display help information."""
    console.print(
        Panel.fit(
            "[bold blue]Claude Code Model Switcher[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    # Usage
    console.print("[bold]Usage:[/bold] ccm <command> [options]")
    console.print()

    # Model options
    console.print("[bold]Model options (equivalent to env, outputs export statements for eval):[/bold]")
    console.print("  ccm deepseek            # DeepSeek")
    console.print("  ccm kimi [global|china] # Kimi (Moonshot AI)")
    console.print("  ccm glm [global|china]  # Zhipu GLM")
    console.print("  ccm qwen [global|china] # Alibaba Qwen")
    console.print("  ccm minimax [global|china] # MiniMax")
    console.print("  ccm seed [variant]      # Doubao/Seed (ARK)")
    console.print("  ccm stepfun             # StepFun")
    console.print("  ccm claude              # Claude (official)")
    console.print("  ccm open <provider>     # OpenRouter mode")
    console.print()

    # Tool options
    console.print("[bold]Tool options:[/bold]")
    console.print("  ccm status              # Show current configuration")
    console.print("  ccm config              # Edit configuration file")
    console.print("  ccm help                # Show this help")
    console.print()

    # Settings
    console.print("[bold]Settings:[/bold]")
    console.print("  ccm project <provider> [region] # Write project-level settings")
    console.print("  ccm user <provider> [region]    # Write user-level settings")
    console.print()

    # Examples
    console.print("[bold]Examples:[/bold]")
    console.print('  eval "$(ccm deepseek)"  # Switch to DeepSeek')
    console.print("  ccc glm global           # Switch + launch Claude Code")
    console.print()


# Dynamic provider commands
def create_provider_command(provider_name: str):
    """Create a command function for a provider."""

    def provider_cmd(
        region: Optional[str] = typer.Argument(None, help="Region (global|china)"),
    ):
        config = _get_config()
        generator = _get_generator(config)

        # Handle kimi-cn alias
        actual_provider = provider_name
        actual_region = region
        if provider_name == "kimi-cn":
            actual_provider = "kimi"
            actual_region = "china"

        exports, success = generator.generate_for_provider(actual_provider, actual_region)

        if success:
            print(exports)  # stdout for eval
        else:
            console.print(f"[red]❌ {exports}[/red]")
            raise typer.Exit(1)

    return provider_cmd


# Register provider commands
for provider_name in ["deepseek", "ds", "kimi", "kimi2", "kimi-cn", "glm", "glm5", "qwen", "minimax", "mm", "seed", "doubao", "stepfun", "claude", "sonnet", "s"]:
    app.command(provider_name)(create_provider_command(provider_name))


# StepFun provider (separate command for clarity)
@app.command("stepfun")
def stepfun_cmd():
    """Switch to StepFun provider."""
    config = _get_config()
    generator = _get_generator(config)

    exports, success = generator.generate_for_provider("stepfun")

    if success:
        print(exports)
    else:
        console.print(f"[red]❌ {exports}[/red]")
        raise typer.Exit(1)


@app.command("open")
def open_cmd(
    provider: str = typer.Argument(..., help="Provider to use via OpenRouter"),
):
    """Switch to a provider via OpenRouter."""
    config = _get_config()
    generator = _get_generator(config)

    exports, success = generator.generate_for_openrouter(provider)

    if success:
        print(exports)  # stdout for eval
    else:
        console.print(f"[red]❌ {exports}[/red]")
        raise typer.Exit(1)


@app.command("status")
def status_cmd():
    """Show current configuration status."""
    config = _get_config()
    show_status(config)


def show_status(config: Config):
    """Display current configuration status."""
    console.print()
    console.print(Panel("[bold]Current model configuration[/bold]", border_style="blue"))

    # Environment variables status
    table = Table(title="Environment variables status", show_header=True, header_style="bold")
    table.add_column("Variable", style="cyan")
    table.add_column("Status", style="green")

    env_vars = [
        ("ANTHROPIC_BASE_URL", None),
        ("ANTHROPIC_MODEL", None),
        ("DEEPSEEK_API_KEY", "DEEPSEEK_API_KEY"),
        ("KIMI_API_KEY", "KIMI_API_KEY"),
        ("GLM_API_KEY", "GLM_API_KEY"),
        ("QWEN_API_KEY", "QWEN_API_KEY"),
        ("MINIMAX_API_KEY", "MINIMAX_API_KEY"),
        ("ARK_API_KEY", "ARK_API_KEY"),
        ("STEPFUN_API_KEY", "STEPFUN_API_KEY"),
        ("CLAUDE_API_KEY", "CLAUDE_API_KEY"),
        ("OPENROUTER_API_KEY", "OPENROUTER_API_KEY"),
    ]

    import os

    for var_name, config_key in env_vars:
        value = os.environ.get(var_name)
        if config_key:
            config_value = config.get(config_key)
            if is_effectively_set(value):
                status = f"[green]Set[/green] {mask_token(value)}"
            elif is_effectively_set(config_value):
                status = f"[green]Set[/green] (from config) {mask_token(config_value)}"
            else:
                status = "[red]Not set[/red]"
        else:
            if is_effectively_set(value):
                status = f"[green]Set[/green] {value}"
            else:
                status = "[red]Not set[/red]"

        table.add_row(var_name, status)

    console.print(table)
    console.print()

    # Config file info
    import os

    config_path = os.path.expanduser("~/.ccm_config")
    if os.path.exists(config_path):
        console.print(f"[blue]Configuration file path:[/blue] {config_path}")
    else:
        console.print("[yellow]Configuration file path: not configured[/yellow]")

    console.print()


def mask_token(token: str | None) -> str:
    """Mask a token for display."""
    if not token:
        return ""
    if len(token) <= 8:
        return "****"
    return f"{token[:4]}...{token[-4:]}"


@app.command("config")
def config_cmd():
    """Edit configuration file."""
    import os
    import subprocess

    config_path = os.path.expanduser("~/.ccm_config")

    # Create default config if it doesn't exist
    if not os.path.exists(config_path):
        with open(config_path, "w", encoding="utf-8") as f:
            f.write(create_default_config())
        os.chmod(config_path, 0o600)
        console.print(f"[green]Configuration file created: {config_path}[/green]")
        console.print("[yellow]Please edit this file to add your API keys[/yellow]")

    # Find editor
    editors = [
        (os.environ.get("EDITOR"), "default"),
        ("cursor", "Cursor"),
        ("code", "VS Code"),
        ("vim", "vim"),
        ("nano", "nano"),
    ]

    for editor, name in editors:
        if editor:
            try:
                console.print("[blue]Opening configuration file for editing...[/blue]")
                subprocess.run([editor, config_path])
                return
            except FileNotFoundError:
                continue

    console.print("[red]No available editor found[/red]")
    console.print(f"[yellow]Please manually edit configuration file: {config_path}[/yellow]")


# Settings commands
@app.command("project")
def project_cmd(
    provider: str = typer.Argument(..., help="Provider name (or 'reset' to remove)"),
    region: Optional[str] = typer.Argument(None, help="Region (global|china)"),
):
    """Write project-level settings to .claude/settings.local.json."""
    from ccm.settings.project import (
        get_project_settings_path,
        is_ccm_managed,
        reset_project_settings,
        show_project_settings,
        write_project_settings,
    )

    # Handle show/reset subcommands
    if provider == "reset":
        reset_project_settings()
        return

    if provider == "show" or provider == "status":
        show_project_settings()
        return

    # Write provider settings
    if not write_project_settings(provider, region):
        raise typer.Exit(1)


@app.command("user")
def user_cmd(
    provider: str = typer.Argument(..., help="Provider name (or 'reset' to remove)"),
    region: Optional[str] = typer.Argument(None, help="Region (global|china)"),
):
    """Write user-level settings to ~/.claude/settings.json."""
    from ccm.settings.user import (
        get_user_settings_path,
        is_ccm_managed,
        reset_user_settings,
        show_user_settings,
        write_user_settings,
    )

    # Handle show/reset subcommands
    if provider == "reset":
        reset_user_settings()
        return

    if provider == "show" or provider == "status":
        show_user_settings()
        return

    # Write provider settings
    if not write_user_settings(provider, region):
        raise typer.Exit(1)


if __name__ == "__main__":
    app()

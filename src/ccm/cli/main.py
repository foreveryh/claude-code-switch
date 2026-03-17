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
from ccm.i18n import t

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
    config = _get_config()
    lang = config.ccm_language

    console.print(
        Panel.fit(
            f"[bold blue]{t('switching_info')}[/bold blue]",
            border_style="blue",
        )
    )
    console.print()

    # Usage
    console.print(f"[bold]{t('usage')}:[/bold] ccm <command> [options]")
    console.print()

    # Model options
    console.print(f"[bold]{t('model_options')}:[/bold]")
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
    console.print(f"[bold]{t('tool_options')}:[/bold]")
    console.print("  ccm status              # Show current configuration")
    console.print("  ccm config              # Edit configuration file")
    console.print("  ccm help                # Show this help")
    console.print()

    # Account management
    console.print("[bold]Account management (Claude Pro):[/bold]")
    console.print("  ccm save-account <name> # Save current account")
    console.print("  ccm switch-account <name> # Switch to saved account")
    console.print("  ccm list-accounts       # List saved accounts")
    console.print("  ccm delete-account <name> # Delete saved account")
    console.print("  ccm current-account     # Show current account")
    console.print()

    # Settings
    console.print("[bold]Settings:[/bold]")
    console.print("  ccm project <provider> [region] # Write project-level settings")
    console.print("  ccm user <provider> [region]    # Write user-level settings")
    console.print()

    # Examples
    console.print(f"[bold]{t('examples')}:[/bold]")
    console.print("  eval \"$(ccm deepseek)\"  # Switch to DeepSeek")
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
    console.print(Panel(f"[bold]{t('current_model_config')}[/bold]", border_style="blue"))

    # Environment variables status
    table = Table(title=t("env_vars_status"), show_header=True, header_style="bold")
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
                status = f"[green]{t('set')}[/green] {mask_token(value)}"
            elif is_effectively_set(config_value):
                status = f"[green]{t('set')}[/green] (from config) {mask_token(config_value)}"
            else:
                status = f"[red]{t('not_set')}[/red]"
        else:
            if is_effectively_set(value):
                status = f"[green]{t('set')}[/green] {value}"
            else:
                status = f"[red]{t('not_set')}[/red]"

        table.add_row(var_name, status)

    console.print(table)
    console.print()

    # Config file info
    import os

    config_path = os.path.expanduser("~/.ccm_config")
    if os.path.exists(config_path):
        console.print(f"[blue]{t('config_file_path')}:[/blue] {config_path}")
    else:
        console.print(f"[yellow]{t('config_file_path')}: {t('not_configured')}[/yellow]")

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
        console.print(f"[green]{t('config_created')}: {config_path}[/green]")
        console.print(f"[yellow]{t('edit_file_to_add_keys')}[/yellow]")

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
                console.print(f"[blue]{t('opening_config_file')}...[/blue]")
                subprocess.run([editor, config_path])
                return
            except FileNotFoundError:
                continue

    console.print(f"[red]{t('no_editor_found')}[/red]")
    console.print(f"[yellow]{t('edit_manually')}: {config_path}[/yellow]")


# Account management commands
@app.command("save-account")
def save_account_cmd(
    name: str = typer.Argument(..., help="Account name"),
):
    """Save current Claude Pro account."""
    from ccm.core.accounts import save_account
    from ccm.core.keychain import has_current_credentials

    if not has_current_credentials():
        console.print(f"[red]❌ {t('no_credentials_found')}[/red]")
        console.print(f"[yellow]{t('please_login_first')}[/yellow]")
        raise typer.Exit(1)

    account = save_account(name)
    if account:
        console.print(f"[green]✅ {t('account_saved')}: {name}[/green]")
        if account.credentials.subscription_type:
            console.print(f"[blue]   {t('subscription_type')}: {account.credentials.subscription_type}[/blue]")
    else:
        console.print(f"[red]❌ {t('failed_to_switch_account')}[/red]")
        raise typer.Exit(1)


@app.command("switch-account")
def switch_account_cmd(
    name: str = typer.Argument(..., help="Account name"),
):
    """Switch to a saved Claude Pro account."""
    from ccm.core.accounts import get_manager

    manager = get_manager()
    account = manager.get_account(name)

    if not account:
        console.print(f"[red]❌ {t('account_not_found')}: {name}[/red]")
        console.print(f"[yellow]{t('use_list_accounts')}[/yellow]")
        raise typer.Exit(1)

    # Switch to the account
    switched = manager.switch_account(name)
    if switched:
        console.print(f"[green]✅ {t('account_switched')}: {name}[/green]")
        console.print(f"[yellow]{t('please_restart_claude_code')}[/yellow]")
    else:
        console.print(f"[red]❌ {t('failed_to_switch_account')}[/red]")
        raise typer.Exit(1)


@app.command("list-accounts")
def list_accounts_cmd():
    """List saved Claude Pro accounts."""
    from ccm.core.accounts import get_current_account_name, has_accounts, list_accounts

    if not has_accounts():
        console.print(f"[yellow]{t('no_accounts_saved')}[/yellow]")
        console.print(f"[blue]{t('use_save_account')}[/blue]")
        return

    accounts = list_accounts()
    current_name = get_current_account_name()

    console.print(f"[bold]{t('saved_accounts')}:[/bold]")
    console.print()

    table = Table(show_header=True, header_style="bold")
    table.add_column(t("account_name"), style="cyan")
    table.add_column(t("subscription_type"), style="green")
    table.add_column("Status", style="blue")

    for account in accounts:
        is_current = "✓" if account.name == current_name else ""
        status = f"[green]{t('active')}[/green]" if is_current else ""
        sub_type = account.credentials.subscription_type or "-"

        table.add_row(account.name, sub_type, status)

    console.print(table)


@app.command("delete-account")
def delete_account_cmd(
    name: str = typer.Argument(..., help="Account name"),
):
    """Delete a saved Claude Pro account."""
    from ccm.core.accounts import delete_account, has_accounts

    if not has_accounts():
        console.print(f"[yellow]{t('no_accounts_saved')}[/yellow]")
        return

    if delete_account(name):
        console.print(f"[green]✅ {t('account_deleted')}: {name}[/green]")
    else:
        console.print(f"[red]❌ {t('account_not_found')}: {name}[/red]")
        raise typer.Exit(1)


@app.command("current-account")
def current_account_cmd():
    """Show current Claude Pro account."""
    from ccm.core.accounts import get_current_account_name, has_accounts
    from ccm.core.keychain import has_current_credentials, read_current_credentials

    current_name = get_current_account_name()

    if not has_current_credentials():
        console.print(f"[yellow]{t('no_current_account')}[/yellow]")
        console.print(f"[blue]{t('please_login_or_switch')}[/blue]")
        return

    credentials = read_current_credentials()

    console.print(f"[bold]{t('current_account_info')}:[/bold]")
    console.print()

    if current_name:
        console.print(f"[cyan]{t('account_name')}:[/cyan] {current_name}")

    if credentials:
        if credentials.subscription_type:
            console.print(f"[cyan]{t('subscription_type')}:[/cyan] {credentials.subscription_type}")

        if credentials.expires_at:
            from datetime import datetime
            try:
                expires_dt = datetime.fromtimestamp(credentials.expires_at)
                console.print(f"[cyan]{t('token_expires')}:[/cyan] {expires_dt.isoformat()}")
            except (ValueError, TypeError):
                pass

        # Mask the access token
        if credentials.access_token:
            masked = f"{credentials.access_token[:8]}...{credentials.access_token[-4:]}" if len(credentials.access_token) > 12 else "****"
            console.print(f"[cyan]{t('access_token')}:[/cyan] {masked}")


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

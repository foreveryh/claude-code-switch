"""Launcher module for CCM (ccc command).

This module implements the 'ccc' command that switches to a provider
and launches Claude Code.
"""

import os
import subprocess
import sys
from typing import Optional

from rich.console import Console

from ccm.core.config import load_config
from ccm.core.exports import ShellExportGenerator
from ccm.core.providers import get_provider, normalize_region

console = Console(stderr=True)


def main():
    """Main entry point for ccc command."""
    if len(sys.argv) < 2:
        show_usage()
        sys.exit(1)

    args = sys.argv[1:]
    model = args[0]
    remaining_args = args[1:]

    # Handle open mode
    if model == "open":
        if len(args) < 2:
            console.print("[red]Usage: ccc open <provider> [claude-options][/red]")
            sys.exit(1)
        open_provider = args[1]
        remaining_args = args[2:]
        switch_and_launch_openrouter(open_provider, remaining_args)
        return

    # Check if it's a known model or an account name
    result = get_provider(model)

    if result is None and not model.startswith("-"):
        # Treat as account name
        switch_and_launch_account(model, remaining_args)
        return

    # Handle model:account format
    if ":" in model:
        parts = model.split(":", 1)
        model_type = parts[0]
        account_name = parts[1]
        switch_and_launch_with_account(model_type, account_name, remaining_args)
        return

    # Switch to provider and launch
    region_or_variant = None
    if remaining_args and not remaining_args[0].startswith("-"):
        # Check if it's a region or variant
        provider_config, _ = result
        if provider_config.regions:
            try:
                region_or_variant = normalize_region(remaining_args[0])
                remaining_args = remaining_args[1:]
            except ValueError:
                pass
        elif provider_config.variants:
            if remaining_args[0].lower() in provider_config.variants:
                region_or_variant = remaining_args[0].lower()
                remaining_args = remaining_args[1:]

    switch_and_launch(model, region_or_variant, remaining_args)


def show_usage():
    """Display usage information."""
    console.print("""
[bold]Usage:[/bold] ccc <model> [region|variant] [claude-options]
       ccc open <provider> [claude-options]
       ccc <account> [claude-options]        # Switch account then launch (default model)
       ccc <model>:<account> [claude-options]

[bold]Examples:[/bold]
  ccc deepseek                              # Launch with DeepSeek
  ccc open kimi                             # Launch with OpenRouter (kimi)
  ccc kimi --dangerously-skip-permissions   # Pass options to Claude Code
  ccc woohelps                              # Switch to 'woohelps' account and launch
  ccc claude:work                           # Switch to 'work' account and use Claude

[bold]Available models:[/bold]
  Official: deepseek, glm, kimi, qwen, seed|doubao, claude, minimax
  OpenRouter: open <provider>
  Account:  <account> | claude:<account>
""")


def switch_and_launch(model: str, region: str | None, claude_args: list[str]):
    """Switch to provider and launch Claude Code."""
    config = load_config()
    generator = ShellExportGenerator(config)

    exports, success = generator.generate_for_provider(model, region)

    if not success:
        console.print(f"[red]❌ {exports}[/red]")
        sys.exit(1)

    # Apply exports to current process environment
    apply_exports(exports)

    console.print()
    console.print(f"[green]🚀 Launching Claude Code...[/green]")
    console.print(f"   [blue]Model:[/blue] {os.environ.get('ANTHROPIC_MODEL', '(unset)')}")
    console.print(f"   [blue]Base URL:[/blue] {os.environ.get('ANTHROPIC_BASE_URL', 'Default (Anthropic)')}")
    console.print()

    # Launch Claude Code
    launch_claude(claude_args)


def switch_and_launch_openrouter(provider: str, claude_args: list[str]):
    """Switch to OpenRouter provider and launch Claude Code."""
    config = load_config()
    generator = ShellExportGenerator(config)

    exports, success = generator.generate_for_openrouter(provider)

    if not success:
        console.print(f"[red]❌ {exports}[/red]")
        sys.exit(1)

    # Apply exports to current process environment
    apply_exports(exports)

    console.print()
    console.print(f"[green]🚀 Launching Claude Code with OpenRouter ({provider})...[/green]")
    console.print(f"   [blue]Model:[/blue] {os.environ.get('ANTHROPIC_MODEL', '(unset)')}")
    console.print()

    # Launch Claude Code
    launch_claude(claude_args)


def switch_and_launch_account(account_name: str, claude_args: list[str]):
    """Switch to account and launch Claude Code."""
    # TODO: Implement account switching in Phase 3
    console.print(f"[yellow]Account switching not yet implemented. Would switch to: {account_name}[/yellow]")
    console.print("[yellow]Falling back to default claude...[/yellow]")

    config = load_config()
    generator = ShellExportGenerator(config)

    exports, success = generator.generate_for_provider("claude")

    if not success:
        console.print(f"[red]❌ {exports}[/red]")
        sys.exit(1)

    apply_exports(exports)

    console.print()
    console.print(f"[green]🚀 Launching Claude Code...[/green]")
    console.print()

    launch_claude(claude_args)


def switch_and_launch_with_account(model: str, account_name: str, claude_args: list[str]):
    """Switch account and model, then launch Claude Code."""
    # TODO: Implement account switching in Phase 3
    console.print(f"[yellow]Account switching not yet implemented. Would switch to: {account_name}[/yellow]")

    switch_and_launch(model, None, claude_args)


def apply_exports(exports: str):
    """Apply shell exports to the current process environment."""
    for line in exports.splitlines():
        if line.startswith("export "):
            # Parse export VAR='value' or export VAR="${VAR}"
            line = line[7:]  # Remove 'export '
            if "=" in line:
                var, value = line.split("=", 1)
                # Remove surrounding quotes
                if value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]
                elif value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]
                # Handle variable references like ${VAR}
                if value.startswith("${") and value.endswith("}"):
                    ref_var = value[2:-1]
                    value = os.environ.get(ref_var, "")
                os.environ[var] = value
        elif line.startswith("unset "):
            var = line[6:]
            os.environ.pop(var, None)


def launch_claude(args: list[str]):
    """Launch Claude Code CLI."""
    # Check if claude CLI exists
    try:
        subprocess.run(["claude", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        console.print("[red]❌ 'claude' CLI not found.[/red]")
        console.print("[yellow]Install it first: npm install -g @anthropic-ai/claude-code[/yellow]")
        sys.exit(127)

    # Launch claude with arguments
    try:
        if args:
            os.execvp("claude", ["claude"] + args)
        else:
            os.execvp("claude", ["claude"])
    except OSError as e:
        console.print(f"[red]❌ Failed to launch Claude Code: {e}[/red]")
        sys.exit(1)


if __name__ == "__main__":
    main()

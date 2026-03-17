"""Claude Code Model Switcher (CCM).

A CLI tool to switch Claude Code between different AI providers.
"""

__version__ = "3.0.0"
__author__ = "Peng"

from ccm.core.config import Config, load_config
from ccm.core.exports import ShellExportGenerator
from ccm.core.providers import PROVIDERS, ProviderConfig, get_provider

__all__ = [
    "__version__",
    "__author__",
    "Config",
    "load_config",
    "ShellExportGenerator",
    "PROVIDERS",
    "ProviderConfig",
    "get_provider",
]

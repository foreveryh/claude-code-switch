"""Translation loading and management for CCM."""

import json
import os
from functools import lru_cache
from pathlib import Path
from typing import Any


# Default translations (embedded for offline use)
DEFAULT_TRANSLATIONS: dict[str, dict[str, str]] = {
    "en": {
        "switching_to": "Switching to",
        "model": "model",
        "switched_to": "Switched to",
        "official": "official",
        "backup": "backup",
        "not_detected": "not detected",
        "cannot_switch": "cannot switch",
        "and": "and",
        "not_configured": "not configured",
        "config_created": "Configuration file created",
        "edit_file_to_add_keys": "Please edit this file to add your API keys",
        "current_model_config": "Current model configuration",
        "env_vars_status": "Environment variables status",
        "set": "Set",
        "not_set": "Not set",
        "switching_info": "Claude Code Model Switcher",
        "usage": "Usage",
        "model_options": "Model options (equivalent to env, outputs export statements for eval)",
        "tool_options": "Tool options",
        "show_current_config": "Show current configuration (masked display)",
        "output_export_only": "Output export statements only (for eval), no plaintext keys",
        "edit_config_file": "Edit configuration file",
        "show_help": "Show this help information",
        "examples": "Examples",
        "supported_models": "Supported models",
        "opening_config_file": "Opening configuration file for editing",
        "config_file_path": "Configuration file path",
        "using_cursor": "Using Cursor editor to open configuration file",
        "using_vscode": "Using VS Code editor to open configuration file",
        "using_default_editor": "Using default editor to open configuration file",
        "using_vim": "Using vim editor to open configuration file",
        "using_nano": "Using nano editor to open configuration file",
        "config_opened": "Configuration file opened in",
        "opened_edit_save": ", edit and save to take effect",
        "config_opened_default": "Configuration file opened with system default editor",
        "no_editor_found": "No available editor found",
        "edit_manually": "Please manually edit configuration file",
        "install_editor": "or install one of the following editors",
        "unknown_option": "Unknown option",
        "missing_api_key": "Missing API key",
        "please_set_in_config": "Please set this in your config file or environment variable",
        "example_config": "Example config:",
        "get_endpoint_id_from": "Get your endpoint ID from",
        "requires_official_key": "Only supports official key, please set",
        "or": "or",
        "export_if_env_not_set": "If environment variable is not set, will read from ~/.ccm_config",
        "usage_env_eval": "Usage: env [model] - Output export statements only (for eval), no plaintext keys",
        "account_name_required": "Account name is required",
        "no_credentials_found": "No credentials found in Keychain",
        "please_login_first": "Please login to Claude Code first",
        "account_saved": "Account saved",
        "subscription_type": "Subscription type",
        "account_switched": "Account switched",
        "please_restart_claude_code": "Please restart Claude Code for changes to take effect",
        "failed_to_switch_account": "Failed to switch account",
        "no_accounts_found": "No saved accounts found",
        "save_account_first": "Please save an account first",
        "account_not_found": "Account not found",
        "use_list_accounts": "Use 'ccm list-accounts' to view all saved accounts",
        "no_accounts_saved": "No accounts saved yet",
        "use_save_account": "Use 'ccm save-account <name>' to save an account",
        "saved_accounts": "Saved Claude Pro accounts",
        "active": "active",
        "account_deleted": "Account deleted",
        "no_current_account": "No current account detected",
        "please_login_or_switch": "Please login to Claude Code or switch to a saved account",
        "current_account_info": "Current account information",
        "account_name": "Account name",
        "token_expires": "Token expires at",
        "access_token": "Access token",
        "account": "Account",
        "credentials_written_to_file": "Credentials written to file",
        "credentials_source_keychain": "Credentials (from macOS Keychain)",
        "credentials_source_file": "Credentials (from ~/.claude/.credentials.json)",
        "credentials_found": "Credentials found",
        "service_name": "Service name",
        "file_path": "File path",
        "trying_to_match_accounts": "Trying to match saved accounts...",
        "matched_account": "Matched account",
        "no_matching_account": "No matching saved accounts",
        "project_config": "Project config detected",
        "openrouter_active": "Active",
        "openrouter_configured_not_active": "Configured but not active",
        "openrouter_use_eval_hint": "Use 'eval $(ccm open <provider>)' to activate",
        "saved_accounts": "Saved Claude Pro accounts",
        "active": "active",
        "account_deleted": "Account deleted",
    },
    "zh": {
        "switching_to": "切换到",
        "model": "模型",
        "switched_to": "已切换到",
        "official": "官方",
        "backup": "备用",
        "not_detected": "未检测到",
        "cannot_switch": "无法切换",
        "and": "且",
        "not_configured": "未配置",
        "config_created": "配置文件已创建",
        "edit_file_to_add_keys": "请编辑此文件添加你的API密钥",
        "current_model_config": "当前模型配置",
        "env_vars_status": "环境变量状态",
        "set": "已设置",
        "not_set": "未设置",
        "switching_info": "Claude Code 模型切换工具",
        "usage": "用法",
        "model_options": "模型选项（与 env 等价，输出 export 语句，便于 eval）",
        "tool_options": "工具选项",
        "show_current_config": "显示当前配置（脱敏显示）",
        "output_export_only": "仅输出 export 语句（用于 eval），不打印密钥明文",
        "edit_config_file": "编辑配置文件",
        "show_help": "显示此帮助信息",
        "examples": "示例",
        "supported_models": "支持的模型",
        "opening_config_file": "打开配置文件进行编辑",
        "config_file_path": "配置文件路径",
        "using_cursor": "使用 Cursor 编辑器打开配置文件",
        "using_vscode": "使用 VS Code 编辑器打开配置文件",
        "using_default_editor": "使用默认编辑器打开配置文件",
        "using_vim": "使用 vim 编辑器打开配置文件",
        "using_nano": "使用 nano 编辑器打开配置文件",
        "config_opened": "配置文件已在",
        "opened_edit_save": "中打开，编辑完成后保存即可生效",
        "config_opened_default": "配置文件已用系统默认编辑器打开",
        "no_editor_found": "未找到可用的编辑器",
        "edit_manually": "请手动编辑配置文件",
        "install_editor": "或安装以下编辑器之一",
        "unknown_option": "未知选项",
        "missing_api_key": "缺少API密钥",
        "please_set_in_config": "请在配置文件或环境变量中设置",
        "example_config": "配置示例：",
        "get_endpoint_id_from": "获取端点ID请访问",
        "requires_official_key": "仅支持官方密钥，请设置",
        "or": "或",
        "export_if_env_not_set": "如果环境变量中未设置，将从 ~/.ccm_config 读取",
        "usage_env_eval": "用法: env [模型] - 仅输出 export 语句（用于 eval），不打印密钥明文",
        "account_name_required": "账号名称必须提供",
        "no_credentials_found": "Keychain 中未找到凭证",
        "please_login_first": "请先登录 Claude Code",
        "account_saved": "账号已保存",
        "subscription_type": "订阅类型",
        "account_switched": "账号已切换",
        "please_restart_claude_code": "请重启 Claude Code 以使更改生效",
        "failed_to_switch_account": "切换账号失败",
        "no_accounts_found": "未找到已保存的账号",
        "save_account_first": "请先保存账号",
        "account_not_found": "账号未找到",
        "use_list_accounts": "使用 'ccm list-accounts' 查看所有已保存的账号",
        "no_accounts_saved": "暂无已保存的账号",
        "use_save_account": "使用 'ccm save-account <名称>' 保存账号",
        "saved_accounts": "已保存的 Claude Pro 账号",
        "active": "当前",
        "account_deleted": "账号已删除",
        "no_current_account": "未检测到当前账号",
        "please_login_or_switch": "请登录 Claude Code 或切换到已保存的账号",
        "current_account_info": "当前账号信息",
        "account_name": "账号名称",
        "token_expires": "Token 过期时间",
        "access_token": "Access Token",
        "account": "账号",
        "credentials_written_to_file": "凭证已写入文件",
        "credentials_source_keychain": "凭证 (来自 macOS Keychain)",
        "credentials_source_file": "凭证 (来自 ~/.claude/.credentials.json)",
        "credentials_found": "找到凭证",
        "service_name": "服务名",
        "file_path": "文件路径",
        "trying_to_match_accounts": "尝试匹配保存的账号...",
        "matched_account": "匹配到账号",
        "no_matching_account": "没有匹配到任何保存的账号",
        "project_config": "检测到项目配置",
        "openrouter_active": "已激活",
        "openrouter_configured_not_active": "已配置但未激活",
        "openrouter_use_eval_hint": "使用 'eval $(ccm open <provider>)' 激活",
    },
}


class Translation:
    """Translation manager."""

    def __init__(self, lang: str = "en"):
        self.lang = lang
        self._translations: dict[str, str] = {}
        self._load_translations()

    def _find_lang_dir(self) -> Path | None:
        """Find the lang directory."""
        # Check multiple locations
        candidates = [
            # When running from source
            Path(__file__).parent.parent.parent.parent / "lang",
            # When installed via uv/pip
            Path(__file__).parent.parent.parent / "lang",
            # Installed data directory
            Path.home() / ".local" / "share" / "ccm" / "lang",
        ]

        for candidate in candidates:
            if candidate.is_dir():
                return candidate
        return None

    def _load_translations(self) -> None:
        """Load translations from file or use defaults."""
        lang_dir = self._find_lang_dir()

        if lang_dir:
            lang_file = lang_dir / f"{self.lang}.json"
            if lang_file.exists():
                try:
                    self._translations = json.loads(lang_file.read_text(encoding="utf-8"))
                    return
                except (json.JSONDecodeError, OSError):
                    pass

        # Fall back to embedded defaults
        self._translations = DEFAULT_TRANSLATIONS.get(self.lang, DEFAULT_TRANSLATIONS["en"])

    def get(self, key: str, default: str | None = None) -> str:
        """Get a translation by key."""
        return self._translations.get(key, default or key)

    def __getitem__(self, key: str) -> str:
        """Get a translation by key using bracket notation."""
        return self._translations.get(key, key)


# Global translation instance (lazy initialized)
_translation: Translation | None = None


def get_translation(lang: str | None = None) -> Translation:
    """Get translation instance for the specified language."""
    global _translation

    if lang is None:
        # Detect language from environment
        lang = os.environ.get("CCM_LANGUAGE", "")
        if not lang:
            # Check LANG environment variable
            sys_lang = os.environ.get("LANG", "")
            if sys_lang.startswith("zh"):
                lang = "zh"
            else:
                lang = "en"

    # Create new translation if language changed or not yet created
    if _translation is None or _translation.lang != lang:
        _translation = Translation(lang)

    return _translation


def t(key: str, default: str | None = None) -> str:
    """Get a translation by key (convenience function)."""
    return get_translation().get(key, default)

"""Account management for Claude Pro subscriptions.

This module handles saving, loading, switching, and deleting
Claude Pro accounts stored in ~/.ccm_accounts.
"""

import json
import os
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

from ccm.core.keychain import (
    Credentials,
    delete_current_credentials,
    has_current_credentials,
    read_current_credentials,
    write_current_credentials,
)
from ccm.i18n import t


@dataclass
class SavedAccount:
    """A saved Claude Pro account."""

    name: str
    credentials: Credentials
    saved_at: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "name": self.name,
            "credentials": self.credentials.to_dict(),
            "saved_at": self.saved_at,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "SavedAccount":
        """Create from dictionary."""
        return cls(
            name=data.get("name", ""),
            credentials=Credentials.from_dict(data.get("credentials", {})),
            saved_at=data.get("saved_at", datetime.now().isoformat()),
        )


class AccountManager:
    """Manages saved Claude Pro accounts."""

    ACCOUNTS_FILE = Path.home() / ".ccm_accounts"

    def __init__(self, accounts_file: Path | None = None):
        self.accounts_file = accounts_file or self.ACCOUNTS_FILE
        self._accounts: dict[str, SavedAccount] | None = None

    def _load_accounts(self) -> dict[str, SavedAccount]:
        """Load accounts from file."""
        if self._accounts is not None:
            return self._accounts

        if not self.accounts_file.exists():
            self._accounts = {}
            return self._accounts

        try:
            data = json.loads(self.accounts_file.read_text())
            self._accounts = {
                name: SavedAccount.from_dict(acc_data)
                for name, acc_data in data.items()
            }
        except (json.JSONDecodeError, OSError):
            self._accounts = {}

        return self._accounts

    def _save_accounts(self) -> None:
        """Save accounts to file."""
        if self._accounts is None:
            return

        data = {
            name: account.to_dict()
            for name, account in self._accounts.items()
        }

        self.accounts_file.write_text(json.dumps(data, indent=2))
        os.chmod(self.accounts_file, 0o600)

    def save_account(self, name: str) -> SavedAccount | None:
        """Save current credentials as a named account."""
        # Read current credentials
        credentials = read_current_credentials()
        if credentials is None:
            return None

        accounts = self._load_accounts()
        account = SavedAccount(name=name, credentials=credentials)
        accounts[name] = account
        self._save_accounts()

        return account

    def switch_account(self, name: str) -> SavedAccount | None:
        """Switch to a saved account."""
        accounts = self._load_accounts()
        account = accounts.get(name)

        if account is None:
            return None

        # Write credentials to system keychain/file
        write_current_credentials(account.credentials)

        return account

    def delete_account(self, name: str) -> bool:
        """Delete a saved account."""
        accounts = self._load_accounts()

        if name not in accounts:
            return False

        del accounts[name]
        self._save_accounts()
        return True

    def list_accounts(self) -> list[SavedAccount]:
        """List all saved accounts."""
        accounts = self._load_accounts()
        return list(accounts.values())

    def get_account(self, name: str) -> SavedAccount | None:
        """Get a specific account."""
        accounts = self._load_accounts()
        return accounts.get(name)

    def get_current_account_name(self) -> str | None:
        """Get the name of the current account by matching credentials."""
        current = read_current_credentials()
        if current is None:
            return None

        accounts = self._load_accounts()

        for name, account in accounts.items():
            if account.credentials.access_token == current.access_token:
                return name

        return None

    def has_accounts(self) -> bool:
        """Check if any accounts are saved."""
        accounts = self._load_accounts()
        return len(accounts) > 0


# Convenience functions
_manager: AccountManager | None = None


def get_manager() -> AccountManager:
    """Get the singleton account manager."""
    global _manager
    if _manager is None:
        _manager = AccountManager()
    return _manager


def save_account(name: str) -> SavedAccount | None:
    """Save current credentials as a named account."""
    return get_manager().save_account(name)


def switch_account(name: str) -> SavedAccount | None:
    """Switch to a saved account."""
    return get_manager().switch_account(name)


def delete_account(name: str) -> bool:
    """Delete a saved account."""
    return get_manager().delete_account(name)


def list_accounts() -> list[SavedAccount]:
    """List all saved accounts."""
    return get_manager().list_accounts()


def get_current_account_name() -> str | None:
    """Get the name of the current account."""
    return get_manager().get_current_account_name()


def has_accounts() -> bool:
    """Check if any accounts are saved."""
    return get_manager().has_accounts()

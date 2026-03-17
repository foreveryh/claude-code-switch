"""Tests for account management."""

import json
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

from ccm.core.accounts import AccountManager, SavedAccount
from ccm.core.keychain import Credentials


class TestCredentials:
    """Tests for Credentials dataclass."""

    def test_credentials_creation(self) -> None:
        """Test creating credentials."""
        creds = Credentials(
            access_token="test-token",
            refresh_token="refresh-token",
            expires_at=1234567890,
            subscription_type="pro",
        )
        assert creds.access_token == "test-token"
        assert creds.refresh_token == "refresh-token"
        assert creds.expires_at == 1234567890
        assert creds.subscription_type == "pro"

    def test_credentials_to_dict(self) -> None:
        """Test converting credentials to dict."""
        creds = Credentials(
            access_token="test-token",
            subscription_type="pro",
        )
        d = creds.to_dict()
        assert d["access_token"] == "test-token"
        assert d["subscription_type"] == "pro"
        assert "refresh_token" not in d  # None values excluded

    def test_credentials_from_dict(self) -> None:
        """Test creating credentials from dict."""
        d = {
            "access_token": "test-token",
            "subscription_type": "pro",
            "extra_field": "value",
        }
        creds = Credentials.from_dict(d)
        assert creds.access_token == "test-token"
        assert creds.subscription_type == "pro"
        assert creds.extra == {"extra_field": "value"}


class TestSavedAccount:
    """Tests for SavedAccount dataclass."""

    def test_saved_account_creation(self) -> None:
        """Test creating a saved account."""
        creds = Credentials(access_token="test-token")
        account = SavedAccount(name="work", credentials=creds)
        assert account.name == "work"
        assert account.credentials.access_token == "test-token"
        assert account.saved_at is not None

    def test_saved_account_to_dict(self) -> None:
        """Test converting saved account to dict."""
        creds = Credentials(access_token="test-token")
        account = SavedAccount(name="work", credentials=creds, saved_at="2024-01-01T00:00:00")
        d = account.to_dict()
        assert d["name"] == "work"
        assert d["saved_at"] == "2024-01-01T00:00:00"
        assert "credentials" in d

    def test_saved_account_from_dict(self) -> None:
        """Test creating saved account from dict."""
        d = {
            "name": "work",
            "saved_at": "2024-01-01T00:00:00",
            "credentials": {
                "access_token": "test-token",
            },
        }
        account = SavedAccount.from_dict(d)
        assert account.name == "work"
        assert account.saved_at == "2024-01-01T00:00:00"
        assert account.credentials.access_token == "test-token"


class TestAccountManager:
    """Tests for AccountManager."""

    def test_empty_accounts_file(self, tmp_path: Path) -> None:
        """Test with no accounts file."""
        manager = AccountManager(accounts_file=tmp_path / "accounts.json")
        assert not manager.has_accounts()
        assert manager.list_accounts() == []
        assert manager.get_account("test") is None

    def test_save_and_list_accounts(self, tmp_path: Path) -> None:
        """Test saving and listing accounts."""
        accounts_file = tmp_path / "accounts.json"
        manager = AccountManager(accounts_file=accounts_file)

        # Mock the keychain to return credentials
        with patch("ccm.core.accounts.read_current_credentials") as mock_read:
            mock_read.return_value = Credentials(
                access_token="test-token",
                subscription_type="pro",
            )

            # Save an account
            account = manager.save_account("work")
            assert account is not None
            assert account.name == "work"

        # List accounts
        accounts = manager.list_accounts()
        assert len(accounts) == 1
        assert accounts[0].name == "work"

    def test_delete_account(self, tmp_path: Path) -> None:
        """Test deleting an account."""
        accounts_file = tmp_path / "accounts.json"
        manager = AccountManager(accounts_file=accounts_file)

        with patch("ccm.core.accounts.read_current_credentials") as mock_read:
            mock_read.return_value = Credentials(access_token="test-token")
            manager.save_account("work")

        # Delete the account
        assert manager.delete_account("work") is True
        assert not manager.has_accounts()

        # Try to delete non-existent account
        assert manager.delete_account("nonexistent") is False

    def test_switch_account(self, tmp_path: Path) -> None:
        """Test switching accounts."""
        accounts_file = tmp_path / "accounts.json"
        manager = AccountManager(accounts_file=accounts_file)

        # First save an account
        with patch("ccm.core.accounts.read_current_credentials") as mock_read:
            mock_read.return_value = Credentials(
                access_token="test-token",
                subscription_type="pro",
            )
            manager.save_account("work")

        # Then switch to it
        with patch("ccm.core.accounts.write_current_credentials") as mock_write:
            account = manager.switch_account("work")
            assert account is not None
            assert account.name == "work"
            mock_write.assert_called_once()

        # Try to switch to non-existent account
        assert manager.switch_account("nonexistent") is None

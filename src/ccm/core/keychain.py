"""Keychain integration for secure credential storage.

Supports:
- macOS: Keychain via 'security' command
- Linux: File-based storage at ~/.claude/.credentials.json
"""

import json
import os
import platform
import subprocess
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class Credentials:
    """Claude Pro credentials."""

    access_token: str
    refresh_token: str | None = None
    expires_at: int | None = None
    subscription_type: str | None = None
    account_id: str | None = None
    # Store additional fields
    extra: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        result = {
            "access_token": self.access_token,
            "refresh_token": self.refresh_token,
            "expires_at": self.expires_at,
            "subscription_type": self.subscription_type,
            "account_id": self.account_id,
        }
        if self.extra:
            result.update(self.extra)
        return {k: v for k, v in result.items() if v is not None}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Credentials":
        """Create from dictionary."""
        known_keys = {
            "access_token",
            "refresh_token",
            "expires_at",
            "subscription_type",
            "account_id",
        }
        extra = {k: v for k, v in data.items() if k not in known_keys}

        return cls(
            access_token=data.get("access_token", ""),
            refresh_token=data.get("refresh_token"),
            expires_at=data.get("expires_at"),
            subscription_type=data.get("subscription_type"),
            account_id=data.get("account_id"),
            extra=extra if extra else None,
        )


class KeychainBackend(ABC):
    """Abstract base class for keychain backends."""

    @abstractmethod
    def read_credentials(self) -> Credentials | None:
        """Read credentials from storage."""
        pass

    @abstractmethod
    def write_credentials(self, credentials: Credentials) -> None:
        """Write credentials to storage."""
        pass

    @abstractmethod
    def delete_credentials(self) -> None:
        """Delete credentials from storage."""
        pass

    @abstractmethod
    def has_credentials(self) -> bool:
        """Check if credentials exist."""
        pass


class MacOSKeychain(KeychainBackend):
    """macOS Keychain backend using 'security' command."""

    def __init__(self, service_name: str = "Claude Code-credentials"):
        self.service_name = service_name

    def read_credentials(self) -> Credentials | None:
        """Read credentials from macOS Keychain."""
        try:
            result = subprocess.run(
                [
                    "security",
                    "find-generic-password",
                    "-s",
                    self.service_name,
                    "-w",
                ],
                capture_output=True,
                text=True,
            )

            if result.returncode != 0:
                return None

            # The password is JSON data
            json_data = result.stdout.strip()
            if not json_data:
                return None

            data = json.loads(json_data)
            return Credentials.from_dict(data)

        except (subprocess.SubprocessError, json.JSONDecodeError):
            return None

    def write_credentials(self, credentials: Credentials) -> None:
        """Write credentials to macOS Keychain."""
        # First, delete any existing credentials
        self.delete_credentials()

        json_data = json.dumps(credentials.to_dict())

        result = subprocess.run(
            [
                "security",
                "add-generic-password",
                "-s",
                self.service_name,
                "-w",
                json_data,
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            raise RuntimeError(f"Failed to write to keychain: {result.stderr}")

    def delete_credentials(self) -> None:
        """Delete credentials from macOS Keychain."""
        subprocess.run(
            [
                "security",
                "delete-generic-password",
                "-s",
                self.service_name,
            ],
            capture_output=True,
        )

    def has_credentials(self) -> bool:
        """Check if credentials exist in macOS Keychain."""
        result = subprocess.run(
            [
                "security",
                "find-generic-password",
                "-s",
                self.service_name,
            ],
            capture_output=True,
        )
        return result.returncode == 0


class LinuxFileBackend(KeychainBackend):
    """Linux file-based credential storage."""

    CREDENTIALS_FILE = Path.home() / ".claude" / ".credentials.json"

    def __init__(self, file_path: Path | None = None):
        self.file_path = file_path or self.CREDENTIALS_FILE

    def read_credentials(self) -> Credentials | None:
        """Read credentials from file."""
        if not self.file_path.exists():
            return None

        try:
            data = json.loads(self.file_path.read_text())
            return Credentials.from_dict(data)
        except (json.JSONDecodeError, OSError):
            return None

    def write_credentials(self, credentials: Credentials) -> None:
        """Write credentials to file."""
        self.file_path.parent.mkdir(parents=True, exist_ok=True)

        # Write with restricted permissions
        content = json.dumps(credentials.to_dict(), indent=2)
        self.file_path.write_text(content)

        # Set restrictive permissions (600)
        os.chmod(self.file_path, 0o600)

    def delete_credentials(self) -> None:
        """Delete credentials file."""
        if self.file_path.exists():
            self.file_path.unlink()

    def has_credentials(self) -> bool:
        """Check if credentials file exists."""
        return self.file_path.exists()


def get_keychain_backend() -> KeychainBackend:
    """Get the appropriate keychain backend for the current platform."""
    system = platform.system()

    if system == "Darwin":
        service_name = os.environ.get("CCM_KEYCHAIN_SERVICE", "Claude Code-credentials")
        return MacOSKeychain(service_name)
    else:
        return LinuxFileBackend()


def read_current_credentials() -> Credentials | None:
    """Read current Claude credentials from the system."""
    backend = get_keychain_backend()
    return backend.read_credentials()


def write_current_credentials(credentials: Credentials) -> None:
    """Write current Claude credentials to the system."""
    backend = get_keychain_backend()
    backend.write_credentials(credentials)


def delete_current_credentials() -> None:
    """Delete current Claude credentials from the system."""
    backend = get_keychain_backend()
    backend.delete_credentials()


def has_current_credentials() -> bool:
    """Check if current Claude credentials exist."""
    backend = get_keychain_backend()
    return backend.has_credentials()

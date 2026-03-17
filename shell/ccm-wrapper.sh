#!/usr/bin/env bash
# CCM Shell Wrapper - Minimal wrapper for eval mode
# This script enables the eval pattern: eval "$(ccm deepseek)"

set -euo pipefail

# Find the Python module
CCM_MODULE="ccm"

# Check if uv is available (preferred)
if command -v uv >/dev/null 2>&1; then
    exec uv run python -m "$CCM_MODULE" "$@"
fi

# Fall back to python3
if command -v python3 >/dev/null 2>&1; then
    exec python3 -m "$CCM_MODULE" "$@"
fi

# Fall back to python
if command -v python >/dev/null 2>&1; then
    exec python -m "$CCM_MODULE" "$@"
fi

echo "ccm error: Python not found" >&2
exit 1

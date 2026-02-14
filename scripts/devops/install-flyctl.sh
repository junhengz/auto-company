#!/usr/bin/env bash
set -euo pipefail

# Installs Fly.io CLI (flyctl) into ~/.fly/bin if missing.
# Safe to re-run: the upstream installer is idempotent.

if command -v flyctl >/dev/null 2>&1; then
  echo "flyctl already installed: $(command -v flyctl)" >&2
  flyctl version || true
  exit 0
fi

echo "Installing flyctl via https://fly.io/install.sh ..." >&2
curl -L https://fly.io/install.sh | sh

export FLYCTL_INSTALL="${FLYCTL_INSTALL:-$HOME/.fly}"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

if ! command -v flyctl >/dev/null 2>&1; then
  echo "flyctl install completed, but flyctl is still not on PATH." >&2
  echo "Fix:" >&2
  echo "  export FLYCTL_INSTALL=\"$HOME/.fly\"" >&2
  echo "  export PATH=\"\\$FLYCTL_INSTALL/bin:\\$PATH\"" >&2
  exit 2
fi

flyctl version >&2 || true


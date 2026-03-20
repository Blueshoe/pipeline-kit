#!/bin/bash
# =============================================================================
# Install Scanning Tools
# =============================================================================
# Installs pip-audit for Python dependency scanning.
#
# Required env vars:
#   SCAN_PYTHON - "true" to install pip-audit
# =============================================================================

set -e

if [[ "$SCAN_PYTHON" == "true" ]]; then
  echo "::group::Install pip-audit"
  pip install pip-audit 2>&1
  echo "::endgroup::"

  # Verify installation
  if ! command -v pip-audit &> /dev/null; then
    echo "::error::pip-audit installation failed"
    exit 1
  fi
  echo "✓ pip-audit installed"
fi

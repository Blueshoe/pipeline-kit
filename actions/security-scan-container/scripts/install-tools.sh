#!/bin/bash
# =============================================================================
# Install Scanning Tools
# =============================================================================
# Installs osv-scanner for container image vulnerability scanning.
# Verifies Docker is available on the runner.
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Verify Docker is available
# ---------------------------------------------------------------------------

if ! command -v docker &> /dev/null; then
  echo "::error::Docker is required for container scanning but was not found"
  exit 1
fi

echo "Docker: $(docker --version)"

# ---------------------------------------------------------------------------
# Install osv-scanner
# ---------------------------------------------------------------------------

echo "::group::Install osv-scanner"
curl -fsSL https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_amd64 \
  -o /usr/local/bin/osv-scanner
chmod +x /usr/local/bin/osv-scanner
echo "::endgroup::"

if ! command -v osv-scanner &> /dev/null; then
  echo "::error::osv-scanner installation failed"
  exit 1
fi

echo "osv-scanner: $(osv-scanner --version | head -1)"

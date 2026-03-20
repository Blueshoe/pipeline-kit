#!/bin/bash
# =============================================================================
# Install Scanning Tools
# =============================================================================
# Installs osv-scanner for dependency vulnerability scanning.
# =============================================================================

set -e

echo "::group::Install osv-scanner"
curl -fsSL https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_amd64 \
  -o /usr/local/bin/osv-scanner
chmod +x /usr/local/bin/osv-scanner
echo "::endgroup::"

if ! command -v osv-scanner &> /dev/null; then
  echo "::error::osv-scanner installation failed"
  exit 1
fi

echo "✓ $(osv-scanner --version | head -1)"

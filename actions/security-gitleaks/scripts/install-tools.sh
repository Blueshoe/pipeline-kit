#!/bin/bash
# =============================================================================
# Install Gitleaks
# =============================================================================
# Downloads the gitleaks binary from GitHub releases.
#
# Required env vars:
#   GITLEAKS_VERSION - Version to install (e.g. 8.30.1)
# =============================================================================

set -e

echo "::group::Install gitleaks v${GITLEAKS_VERSION}"

curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  | tar -xz -C /usr/local/bin gitleaks

chmod +x /usr/local/bin/gitleaks

echo "::endgroup::"

if ! command -v gitleaks &> /dev/null; then
  echo "::error::gitleaks installation failed"
  exit 1
fi

echo "gitleaks: $(gitleaks version)"

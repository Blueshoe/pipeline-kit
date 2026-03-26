#!/bin/bash
# =============================================================================
# Cleanup — Gitleaks
# =============================================================================
# Removes temporary files created during the gitleaks scan.
# =============================================================================

rm -f /tmp/security-gitleaks-results.json
rm -f /tmp/security-gitleaks-aggregated.json
rm -f /tmp/gitleaks-stderr.log

#!/bin/bash
# =============================================================================
# Cleanup
# =============================================================================
# Removes temporary files created during the security scan.
# =============================================================================

rm -f /tmp/security-scan-python.json
rm -f /tmp/security-scan-npm.json
rm -f /tmp/security-scan-results.json
rm -f /tmp/osv-scanner-python-stderr.log
rm -f /tmp/osv-scanner-npm-stderr.log

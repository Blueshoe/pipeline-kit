#!/bin/bash
# =============================================================================
# Cleanup
# =============================================================================
# Removes temporary files created during the action run.
#
# Optional env vars:
#   CLEANUP_PACKAGE_JSON - "true" if we created package.json
# =============================================================================

rm -f eslint.config.js-prefix.cjs eslint-results.json

if [[ "$CLEANUP_PACKAGE_JSON" == "true" ]]; then
  rm -f package.json package-lock.json
  rm -rf node_modules
fi

#!/bin/bash
# =============================================================================
# Install ESLint
# =============================================================================
# Installs ESLint 9 and the js-prefix plugin.
#
# Required env vars:
#   PLUGIN_PATH - Path to the plugin directory
#
# Side effects:
#   - Creates package.json if not present (sets CLEANUP_PACKAGE_JSON=true)
#   - Installs node_modules
# =============================================================================

set -e

# Create temporary package.json if project doesn't have one
if [[ ! -f "package.json" ]]; then
  echo '{"private": true}' > package.json
  echo "CLEANUP_PACKAGE_JSON=true" >> "$GITHUB_ENV"
fi

# Install ESLint 9 and the plugin together
echo "Installing ESLint and plugin..."
npm install --no-save eslint@^9.0.0 "$PLUGIN_PATH" 2>/dev/null

# Verify installation
if [[ ! -f "./node_modules/.bin/eslint" ]]; then
  echo "::error::ESLint installation failed"
  exit 1
fi

echo "✓ ESLint installed"

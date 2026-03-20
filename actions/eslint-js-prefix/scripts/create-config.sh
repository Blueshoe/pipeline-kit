#!/bin/bash
# =============================================================================
# Create ESLint Config
# =============================================================================
# Generates an ESLint 9 flat config file for the js-prefix rule.
#
# Required env vars:
#   INPUT_PREFIX   - Required prefix (e.g., "js-")
#   INPUT_SEVERITY - Rule severity ("error" or "warn")
#   INPUT_PATTERNS - JSON array of allowed patterns
#   INPUT_IGNORED  - JSON array of ignored selectors
#
# Output:
#   Creates eslint.config.js-prefix.cjs in current directory
# =============================================================================

set -e

cat > eslint.config.js-prefix.cjs << 'EOF'
const jsPrefix = require('eslint-plugin-js-prefix');

module.exports = [{
  plugins: { 'js-prefix': jsPrefix },
  rules: {
    'js-prefix/require-js-prefix': ['SEVERITY', {
      prefix: 'PREFIX',
      allowedPatterns: PATTERNS,
      ignoredSelectors: IGNORED
    }]
  }
}];
EOF

# Replace placeholders with actual values
sed -i "s/SEVERITY/$INPUT_SEVERITY/g" eslint.config.js-prefix.cjs
sed -i "s/PREFIX/$INPUT_PREFIX/g" eslint.config.js-prefix.cjs
sed -i "s/PATTERNS/$INPUT_PATTERNS/g" eslint.config.js-prefix.cjs
sed -i "s/IGNORED/$INPUT_IGNORED/g" eslint.config.js-prefix.cjs

echo "✓ ESLint config created"

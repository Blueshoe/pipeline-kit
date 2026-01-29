#!/bin/bash
# =============================================================================
# Detect Frameworks
# =============================================================================
# Scans package.json for known frameworks and outputs allowed patterns.
# Patterns are merged with user-provided patterns.
#
# Required env vars:
#   USER_PATTERNS  - JSON array of user-provided patterns
#   AUTO_DETECT    - "true" to enable detection
#
# Output:
#   patterns       - JSON array of all patterns (to GITHUB_OUTPUT)
# =============================================================================

set -e

PATTERNS="$USER_PATTERNS"

# Skip if auto-detect is disabled or no package.json
if [[ "$AUTO_DETECT" != "true" ]] || [[ ! -f "package.json" ]]; then
  echo "Framework detection: skipped"
  echo "patterns=$PATTERNS" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "Scanning package.json for frameworks..."

# Helper: Add pattern if not already present
add_pattern() {
  local pattern="$1"
  PATTERNS=$(echo "$PATTERNS" | node -e "
    const arr = JSON.parse(require('fs').readFileSync(0, 'utf8').trim() || '[]');
    if (!arr.includes('$pattern')) arr.push('$pattern');
    console.log(JSON.stringify(arr));
  ")
}

# React / React Testing Library / Playwright
if grep -qE '"(react|@testing-library|@playwright/test)"' package.json 2>/dev/null; then
  echo "  ✓ Detected: React/Testing Library/Playwright → data-testid"
  add_pattern "^data-testid$"
  add_pattern "^data-test$"
fi

# Vue
if grep -q '"vue"' package.json 2>/dev/null; then
  echo "  ✓ Detected: Vue → ref"
  add_pattern "^ref$"
fi

# Cypress
if grep -q '"cypress"' package.json 2>/dev/null; then
  echo "  ✓ Detected: Cypress → data-cy"
  add_pattern "^data-cy"
fi

echo ""
echo "Final patterns: $PATTERNS"
echo "patterns=$PATTERNS" >> "$GITHUB_OUTPUT"

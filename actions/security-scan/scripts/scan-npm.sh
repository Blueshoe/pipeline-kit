#!/bin/bash
# =============================================================================
# Scan NPM Dependencies
# =============================================================================
# Runs npm audit to find vulnerable NPM packages.
#
# Required env vars:
#   NPM_PACKAGE_PATH    - Path to directory with package-lock.json (empty for cwd)
#   SEVERITY_THRESHOLD   - low, medium, high, critical
#   ACTION_PATH          - Path to the action directory
#
# Outputs:
#   vulnerability_count  - Number of vulnerabilities found
#   result_file          - Path to JSON results file
# =============================================================================

set -e

RESULT_FILE="/tmp/security-scan-npm.json"
SCAN_DIR="."

# =============================================================================
# Locate package-lock.json
# =============================================================================

if [[ -n "$NPM_PACKAGE_PATH" ]]; then
  SCAN_DIR="$NPM_PACKAGE_PATH"
fi

if [[ ! -f "$SCAN_DIR/package-lock.json" ]]; then
  echo "::warning::No package-lock.json found in $SCAN_DIR — skipping NPM scan"
  echo "vulnerability_count=0" >> "$GITHUB_OUTPUT"
  echo "result_file=" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "Scanning NPM dependencies in: $SCAN_DIR"

# =============================================================================
# Run npm audit
# =============================================================================

echo "::group::Run npm audit"

# npm audit exits non-zero when vulnerabilities are found — that is expected
set +e
npm audit --json --prefix "$SCAN_DIR" > "$RESULT_FILE" 2>&1
AUDIT_EXIT=$?
set -e

echo "::endgroup::"

# =============================================================================
# Count vulnerabilities by severity
# =============================================================================

if [[ -f "$RESULT_FILE" ]]; then
  # Map severity threshold to npm audit levels
  COUNT=$(node -e "
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync('${RESULT_FILE}', 'utf8'));

    const severityOrder = { low: 0, moderate: 1, high: 2, critical: 3 };
    // Map our threshold names to npm's names
    const thresholdMap = { low: 'low', medium: 'moderate', high: 'high', critical: 'critical' };
    const threshold = thresholdMap['${SEVERITY_THRESHOLD}'.toLowerCase()] || 'high';
    const thresholdLevel = severityOrder[threshold] || 2;

    let count = 0;

    if (data.vulnerabilities) {
      // npm audit v2 format
      for (const [name, vuln] of Object.entries(data.vulnerabilities)) {
        const vulnLevel = severityOrder[vuln.severity] || 0;
        if (vulnLevel >= thresholdLevel) {
          count++;
        }
      }
    } else if (data.advisories) {
      // npm audit v1 format
      for (const [id, advisory] of Object.entries(data.advisories)) {
        const vulnLevel = severityOrder[advisory.severity] || 0;
        if (vulnLevel >= thresholdLevel) {
          count++;
        }
      }
    }

    console.log(count);
  ")

  echo "NPM vulnerabilities found (>= $SEVERITY_THRESHOLD): $COUNT"
  echo "vulnerability_count=$COUNT" >> "$GITHUB_OUTPUT"
  echo "result_file=$RESULT_FILE" >> "$GITHUB_OUTPUT"
else
  echo "vulnerability_count=0" >> "$GITHUB_OUTPUT"
  echo "result_file=" >> "$GITHUB_OUTPUT"
fi

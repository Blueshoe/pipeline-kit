#!/bin/bash
# =============================================================================
# Run ESLint
# =============================================================================
# Finds JS/TS files and runs ESLint with the js-prefix rule.
#
# Required env vars:
#   SEVERITY - Rule severity for exit code handling
#
# Output (to GITHUB_OUTPUT):
#   violations     - Number of violations found
#   has_violations - "true" or "false"
#
# Side effects:
#   - Creates eslint-results.json with raw ESLint output
#   - Creates GitHub annotations for violations
# =============================================================================

set -e

# Find JS/TS files (excluding common build directories)
FILES=$(find . -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.vue" \) \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  2>/dev/null || true)

# Handle empty project
if [[ -z "$FILES" ]]; then
  echo "No JavaScript/TypeScript files found"
  echo "violations=0" >> "$GITHUB_OUTPUT"
  echo "has_violations=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "Linting $(echo "$FILES" | wc -l | tr -d ' ') files..."

# Run ESLint (use binary directly to avoid npx stdout pollution)
set +e
OUTPUT=$(./node_modules/.bin/eslint --config eslint.config.js-prefix.cjs --format json $FILES 2>&1)
EXIT_CODE=$?
set -e

# Check if output is valid JSON
if ! echo "$OUTPUT" | node -e "JSON.parse(require('fs').readFileSync(0, 'utf8'))" 2>/dev/null; then
  echo "::error::ESLint failed"
  echo "$OUTPUT"
  exit 1
fi

# Save results for summary step
echo "$OUTPUT" > eslint-results.json

# Count violations
VIOLATIONS=$(echo "$OUTPUT" | node -e "
  const r = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  console.log(r.reduce((s, f) => s + f.errorCount + f.warningCount, 0));
")

echo "violations=$VIOLATIONS" >> "$GITHUB_OUTPUT"
echo "has_violations=$([[ $VIOLATIONS -gt 0 ]] && echo true || echo false)" >> "$GITHUB_OUTPUT"

# Print violations to console
if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo ""
  echo "::group::Found $VIOLATIONS violation(s)"
  node -e "
    const r = JSON.parse(require('fs').readFileSync('eslint-results.json', 'utf8'));
    const cwd = process.cwd();
    for (const f of r) {
      if (f.messages.length === 0) continue;
      console.log('\n' + f.filePath.replace(cwd + '/', '') + ':');
      for (const m of f.messages) {
        console.log('  L' + m.line + ': ' + m.message);
      }
    }
  "
  echo "::endgroup::"

  # Create GitHub annotations
  node -e "
    const r = JSON.parse(require('fs').readFileSync('eslint-results.json', 'utf8'));
    const cwd = process.cwd();
    for (const f of r) {
      const file = f.filePath.replace(cwd + '/', '');
      for (const m of f.messages) {
        const lvl = m.severity === 2 ? 'error' : 'warning';
        console.log('::' + lvl + ' file=' + file + ',line=' + m.line + '::' + m.message);
      }
    }
  "
else
  echo "✅ No violations found"
fi

# Fail build if severity is error and violations exist
if [[ "$EXIT_CODE" -ne 0 ]] && [[ "$SEVERITY" == "error" ]]; then
  exit 1
fi

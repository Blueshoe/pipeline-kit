#!/bin/bash
# =============================================================================
# Create GitHub Summary
# =============================================================================
# Generates a GitHub Step Summary with violation details.
#
# Required env vars:
#   VIOLATIONS     - Number of violations found
#   HAS_VIOLATIONS - "true" or "false"
#   PREFIX         - The required prefix
#
# Reads:
#   eslint-results.json - ESLint output from run-eslint.sh
# =============================================================================

if [[ "$HAS_VIOLATIONS" == "true" ]]; then
  # Failed summary with violations table
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## ❌ JS Prefix Check Failed

Found **$VIOLATIONS** violation(s).

### Violations

| File | Line | Selector |
|------|------|----------|
EOF

  # Generate table rows
  if [[ -f "eslint-results.json" ]]; then
    node -e "
      const r = JSON.parse(require('fs').readFileSync('eslint-results.json', 'utf8'));
      const cwd = process.cwd();
      for (const f of r) {
        const file = f.filePath.replace(cwd + '/', '');
        for (const m of f.messages) {
          const match = m.message.match(/Selector '([^']+)'/);
          const sel = match ? match[1] : '-';
          console.log('| \`' + file + '\` | ' + m.line + ' | \`' + sel + '\` |');
        }
      }
    " >> "$GITHUB_STEP_SUMMARY"
  fi

  cat >> "$GITHUB_STEP_SUMMARY" << EOF

### How to fix

Use \`${PREFIX}\` prefixed selectors:

\`\`\`javascript
// ❌ Before
document.querySelector('.btn-danger')

// ✅ After
document.querySelector('.${PREFIX}delete-button')
\`\`\`
EOF

else
  # Success summary
  echo "## ✅ JS Prefix Check Passed" >> "$GITHUB_STEP_SUMMARY"
  echo "" >> "$GITHUB_STEP_SUMMARY"
  echo "All DOM selectors follow the \`$PREFIX\` prefix convention." >> "$GITHUB_STEP_SUMMARY"
fi

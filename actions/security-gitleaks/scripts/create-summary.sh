#!/bin/bash
# =============================================================================
# Create Summary — Gitleaks
# =============================================================================
# Builds an aggregated JSON results file and a GitHub Step Summary.
#
# Required env vars:
#   SCAN_MODE       - "git" or "dir"
#   LEAKS_RESULT    - Path to gitleaks JSON results
#   LEAKS_COUNT     - Number of leaks found
#   FAIL_ON_LEAKS   - "true" to fail on findings
#   REDACT          - Redact percentage
#
# Outputs:
#   leaks_count     - Number of leaks
#   results_path    - Path to aggregated JSON
#   has_leaks       - "true" or "false"
# =============================================================================

RESULTS_FILE="/tmp/security-gitleaks-aggregated.json"
LEAKS_COUNT="${LEAKS_COUNT:-0}"

# =============================================================================
# Build aggregated JSON
# =============================================================================

python3 << PYEOF
import json
from datetime import datetime, timezone

findings = []
rule_counts = {}

leaks_file = "${LEAKS_RESULT}"
if leaks_file:
    try:
        with open(leaks_file) as f:
            data = json.load(f)
        if isinstance(data, list):
            findings = data
            for f_item in findings:
                rule_id = f_item.get("RuleID", "unknown")
                rule_counts[rule_id] = rule_counts.get(rule_id, 0) + 1
    except Exception:
        pass

result = {
    "scan_date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "scanner": "gitleaks",
    "scan_mode": "${SCAN_MODE}",
    "total_count": ${LEAKS_COUNT},
    "rule_counts": rule_counts,
    "findings": findings
}

with open("${RESULTS_FILE}", "w") as f:
    json.dump(result, f, indent=2)
PYEOF

# =============================================================================
# Set outputs
# =============================================================================

echo "leaks_count=$LEAKS_COUNT" >> "$GITHUB_OUTPUT"
echo "results_path=$RESULTS_FILE" >> "$GITHUB_OUTPUT"

if [[ $LEAKS_COUNT -gt 0 ]]; then
  echo "has_leaks=true" >> "$GITHUB_OUTPUT"
else
  echo "has_leaks=false" >> "$GITHUB_OUTPUT"
fi

# =============================================================================
# GitHub Step Summary
# =============================================================================

MAX_ENTRIES=50

if [[ $LEAKS_COUNT -gt 0 ]]; then
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## Gitleaks — $LEAKS_COUNT Secret$([ $LEAKS_COUNT -eq 1 ] && echo "" || echo "s") Found

Scan mode: **${SCAN_MODE}**

EOF

  python3 << PYEOF >> "$GITHUB_STEP_SUMMARY"
import json

with open("${RESULTS_FILE}") as f:
    data = json.load(f)

# Rule summary table
rule_counts = data.get("rule_counts", {})
if rule_counts:
    lines = []
    lines.append("### By Rule")
    lines.append("")
    lines.append("| Rule | Count |")
    lines.append("|------|-------|")
    for rule, count in sorted(rule_counts.items(), key=lambda x: -x[1]):
        lines.append(f"| \`{rule}\` | {count} |")
    lines.append("")
    print("\n".join(lines))

# Findings detail table
findings = data.get("findings", [])
max_entries = ${MAX_ENTRIES}
redact = int("${REDACT}" or "0")

if findings:
    lines = []
    lines.append("### Findings")
    lines.append("")
    lines.append("| Rule | File | Line | Commit |")
    lines.append("|------|------|------|--------|")
    for i, f_item in enumerate(findings):
        if i >= max_entries:
            lines.append(f"| ... | truncated at {max_entries} entries | | |")
            break
        rule = f_item.get("RuleID", "unknown")
        filepath = f_item.get("File", "unknown")
        line = f_item.get("StartLine", "-")
        commit = f_item.get("Commit", "")[:8] or "-"
        lines.append(f"| \`{rule}\` | \`{filepath}\` | {line} | \`{commit}\` |")
    print("\n".join(lines))
PYEOF

else
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## Gitleaks — No Secrets Found

Scan mode: **${SCAN_MODE}**
EOF
fi

# =============================================================================
# Fail if configured and leaks found
# =============================================================================

if [[ "$FAIL_ON_LEAKS" == "true" && $LEAKS_COUNT -gt 0 ]]; then
  echo "::error::Found $LEAKS_COUNT leaked secret$([ $LEAKS_COUNT -eq 1 ] && echo "" || echo "s")"
  exit 1
fi

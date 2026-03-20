#!/bin/bash
# =============================================================================
# Create Summary
# =============================================================================
# Aggregates osv-scanner results into a JSON file and GitHub Step Summary.
#
# Required env vars:
#   SCAN_PYTHON            - "true" if Python scan was enabled
#   SCAN_NPM               - "true" if NPM scan was enabled
#   PYTHON_RESULT          - Path to Python osv-scanner JSON results
#   NPM_RESULT             - Path to NPM osv-scanner JSON results
#   PYTHON_COUNT           - Number of Python vulnerabilities
#   NPM_COUNT              - Number of NPM vulnerabilities
#   SEVERITY_THRESHOLD     - Severity filter applied
#   FAIL_ON_VULNERABILITIES - "true" to fail on findings
#   ACTION_PATH            - Path to the action directory
#
# Outputs:
#   python_count       - Python vulnerability count
#   npm_count          - NPM vulnerability count
#   total_count        - Total vulnerability count
#   results_path       - Path to aggregated JSON
#   has_vulnerabilities - "true" or "false"
# =============================================================================

RESULTS_FILE="/tmp/security-scan-results.json"
PYTHON_COUNT="${PYTHON_COUNT:-0}"
NPM_COUNT="${NPM_COUNT:-0}"
TOTAL_COUNT=$((PYTHON_COUNT + NPM_COUNT))

# =============================================================================
# Build aggregated JSON
# =============================================================================

python3 << PYEOF
import json, sys
from datetime import datetime, timezone

def cvss_to_severity(score_str):
    try:
        score = float(score_str)
    except (ValueError, TypeError):
        return "unknown"
    if score >= 9.0:
        return "critical"
    elif score >= 7.0:
        return "high"
    elif score >= 4.0:
        return "medium"
    elif score > 0:
        return "low"
    return "unknown"

def parse_osv_results(filepath):
    """Parse osv-scanner JSON into a list of vulnerabilities with severity."""
    vulns = []
    severity_counts = {"low": 0, "medium": 0, "high": 0, "critical": 0}

    if not filepath:
        return vulns, severity_counts

    try:
        with open(filepath) as f:
            data = json.load(f)
    except Exception:
        return vulns, severity_counts

    for result in data.get("results", []):
        for pkg in result.get("packages", []):
            p = pkg.get("package", {})
            pkg_name = p.get("name", "unknown")
            pkg_version = p.get("version", "unknown")

            for group in pkg.get("groups", []):
                sev = cvss_to_severity(group.get("max_severity", ""))
                ids = group.get("ids", [])
                aliases = group.get("aliases", [])

                vulns.append({
                    "package": pkg_name,
                    "version": pkg_version,
                    "severity": sev,
                    "cvss_score": group.get("max_severity", ""),
                    "ids": ids,
                    "aliases": aliases
                })

                if sev in severity_counts:
                    severity_counts[sev] += 1

    return vulns, severity_counts

python_vulns, python_sev = parse_osv_results("${PYTHON_RESULT}")
npm_vulns, npm_sev = parse_osv_results("${NPM_RESULT}")

total_sev = {k: python_sev.get(k, 0) + npm_sev.get(k, 0) for k in ["low", "medium", "high", "critical"]}

result = {
    "scan_date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "scanner": "osv-scanner",
    "severity_threshold": "${SEVERITY_THRESHOLD}",
    "severity_counts": total_sev,
    "python": {
        "vulnerabilities": python_vulns,
        "count": ${PYTHON_COUNT},
        "severity_counts": python_sev
    },
    "npm": {
        "vulnerabilities": npm_vulns,
        "count": ${NPM_COUNT},
        "severity_counts": npm_sev
    },
    "total_count": ${TOTAL_COUNT}
}

with open("${RESULTS_FILE}", "w") as f:
    json.dump(result, f, indent=2)
PYEOF

# =============================================================================
# Set outputs
# =============================================================================

echo "python_count=$PYTHON_COUNT" >> "$GITHUB_OUTPUT"
echo "npm_count=$NPM_COUNT" >> "$GITHUB_OUTPUT"
echo "total_count=$TOTAL_COUNT" >> "$GITHUB_OUTPUT"
echo "results_path=$RESULTS_FILE" >> "$GITHUB_OUTPUT"

if [[ $TOTAL_COUNT -gt 0 ]]; then
  echo "has_vulnerabilities=true" >> "$GITHUB_OUTPUT"
else
  echo "has_vulnerabilities=false" >> "$GITHUB_OUTPUT"
fi

# =============================================================================
# GitHub Step Summary
# =============================================================================

MAX_ENTRIES=50

if [[ $TOTAL_COUNT -gt 0 ]]; then
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## ❌ Security Scan — $TOTAL_COUNT Vulnerabilit$([ $TOTAL_COUNT -eq 1 ] && echo "y" || echo "ies") Found

Scanner: **osv-scanner** | Severity threshold: **$SEVERITY_THRESHOLD**

### Overview

| Scan | Vulnerabilities | Status |
|------|----------------|--------|
EOF

  if [[ "$SCAN_PYTHON" == "true" ]]; then
    if [[ $PYTHON_COUNT -gt 0 ]]; then
      echo "| Python | $PYTHON_COUNT | ❌ |" >> "$GITHUB_STEP_SUMMARY"
    else
      echo "| Python | 0 | ✅ |" >> "$GITHUB_STEP_SUMMARY"
    fi
  else
    echo "| Python | — | Skipped |" >> "$GITHUB_STEP_SUMMARY"
  fi

  if [[ "$SCAN_NPM" == "true" ]]; then
    if [[ $NPM_COUNT -gt 0 ]]; then
      echo "| NPM | $NPM_COUNT | ❌ |" >> "$GITHUB_STEP_SUMMARY"
    else
      echo "| NPM | 0 | ✅ |" >> "$GITHUB_STEP_SUMMARY"
    fi
  else
    echo "| NPM | — | Skipped |" >> "$GITHUB_STEP_SUMMARY"
  fi

  # Detail tables from aggregated results
  python3 << PYEOF
import json

with open("${RESULTS_FILE}") as f:
    data = json.load(f)

max_entries = ${MAX_ENTRIES}

# Python details
py_vulns = data["python"]["vulnerabilities"]
if py_vulns:
    lines = []
    lines.append("")
    lines.append("### Python Vulnerabilities")
    lines.append("")
    lines.append("| Package | Version | Severity | CVSS | IDs |")
    lines.append("|---------|---------|----------|------|-----|")
    for i, v in enumerate(py_vulns):
        if i >= max_entries:
            lines.append(f"| ... | truncated at {max_entries} entries | | | |")
            break
        ids = ", ".join(v.get("ids", [])[:2])
        lines.append(f"| \`{v['package']}\` | {v['version']} | {v['severity']} | {v.get('cvss_score', '-')} | {ids} |")
    print("\n".join(lines))

# NPM details
npm_vulns = data["npm"]["vulnerabilities"]
if npm_vulns:
    lines = []
    lines.append("")
    lines.append("### NPM Vulnerabilities")
    lines.append("")
    lines.append("| Package | Version | Severity | CVSS | IDs |")
    lines.append("|---------|---------|----------|------|-----|")
    for i, v in enumerate(npm_vulns):
        if i >= max_entries:
            lines.append(f"| ... | truncated at {max_entries} entries | | | |")
            break
        ids = ", ".join(v.get("ids", [])[:2])
        lines.append(f"| \`{v['package']}\` | {v['version']} | {v['severity']} | {v.get('cvss_score', '-')} | {ids} |")
    print("\n".join(lines))
PYEOF
  >> "$GITHUB_STEP_SUMMARY"

else
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## ✅ Security Scan — No Vulnerabilities Found

Scanner: **osv-scanner** | Severity threshold: **$SEVERITY_THRESHOLD**

### Overview

| Scan | Vulnerabilities | Status |
|------|----------------|--------|
EOF

  if [[ "$SCAN_PYTHON" == "true" ]]; then
    echo "| Python | 0 | ✅ |" >> "$GITHUB_STEP_SUMMARY"
  else
    echo "| Python | — | Skipped |" >> "$GITHUB_STEP_SUMMARY"
  fi

  if [[ "$SCAN_NPM" == "true" ]]; then
    echo "| NPM | 0 | ✅ |" >> "$GITHUB_STEP_SUMMARY"
  else
    echo "| NPM | — | Skipped |" >> "$GITHUB_STEP_SUMMARY"
  fi
fi

# =============================================================================
# Fail if configured and vulnerabilities found
# =============================================================================

if [[ "$FAIL_ON_VULNERABILITIES" == "true" && $TOTAL_COUNT -gt 0 ]]; then
  echo "::error::Found $TOTAL_COUNT vulnerabilit$([ $TOTAL_COUNT -eq 1 ] && echo "y" || echo "ies") (threshold: $SEVERITY_THRESHOLD)"
  exit 1
fi

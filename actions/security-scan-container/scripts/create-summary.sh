#!/bin/bash
# =============================================================================
# Create Summary — Container Scan
# =============================================================================
# Aggregates osv-scanner container results into a JSON file and GitHub Step
# Summary.
#
# Required env vars:
#   CONTAINER_IMAGE          - Scanned image reference
#   CONTAINER_RESULT         - Path to osv-scanner JSON results
#   CONTAINER_COUNT          - Number of vulnerabilities meeting threshold
#   SEVERITY_THRESHOLD       - Severity filter applied
#   FAIL_ON_VULNERABILITIES  - "true" to fail on findings
#
# Outputs:
#   container_count    - Vulnerability count
#   results_path       - Path to aggregated JSON
#   has_vulnerabilities - "true" or "false"
# =============================================================================

RESULTS_FILE="/tmp/security-scan-container-results.json"
CONTAINER_COUNT="${CONTAINER_COUNT:-0}"

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

container_vulns, container_sev = parse_osv_results("${CONTAINER_RESULT}")

result = {
    "scan_date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "scanner": "osv-scanner",
    "scan_type": "container",
    "image": "${CONTAINER_IMAGE}",
    "severity_threshold": "${SEVERITY_THRESHOLD}",
    "severity_counts": container_sev,
    "container": {
        "vulnerabilities": container_vulns,
        "count": ${CONTAINER_COUNT},
        "severity_counts": container_sev
    },
    "total_count": ${CONTAINER_COUNT}
}

with open("${RESULTS_FILE}", "w") as f:
    json.dump(result, f, indent=2)
PYEOF

# =============================================================================
# Set outputs
# =============================================================================

echo "container_count=$CONTAINER_COUNT" >> "$GITHUB_OUTPUT"
echo "results_path=$RESULTS_FILE" >> "$GITHUB_OUTPUT"

if [[ $CONTAINER_COUNT -gt 0 ]]; then
  echo "has_vulnerabilities=true" >> "$GITHUB_OUTPUT"
else
  echo "has_vulnerabilities=false" >> "$GITHUB_OUTPUT"
fi

# =============================================================================
# GitHub Step Summary
# =============================================================================

MAX_ENTRIES=50

if [[ $CONTAINER_COUNT -gt 0 ]]; then
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## Container Scan — $CONTAINER_COUNT Vulnerabilit$([ $CONTAINER_COUNT -eq 1 ] && echo "y" || echo "ies") Found

Scanner: **osv-scanner** | Severity threshold: **$SEVERITY_THRESHOLD**
Image: \`$CONTAINER_IMAGE\`

### Overview

| Image | Vulnerabilities | Status |
|-------|----------------|--------|
| \`$CONTAINER_IMAGE\` | $CONTAINER_COUNT | Failed |

EOF

  python3 << PYEOF >> "$GITHUB_STEP_SUMMARY"
import json

with open("${RESULTS_FILE}") as f:
    data = json.load(f)

max_entries = ${MAX_ENTRIES}
vulns = data["container"]["vulnerabilities"]
if vulns:
    lines = []
    lines.append("### Vulnerabilities")
    lines.append("")
    lines.append("| Package | Version | Severity | CVSS | IDs |")
    lines.append("|---------|---------|----------|------|-----|")
    for i, v in enumerate(vulns):
        if i >= max_entries:
            lines.append(f"| ... | truncated at {max_entries} entries | | | |")
            break
        ids = ", ".join(v.get("ids", [])[:2])
        lines.append(f"| \`{v['package']}\` | {v['version']} | {v['severity']} | {v.get('cvss_score', '-')} | {ids} |")
    print("\n".join(lines))
PYEOF

else
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## Container Scan — No Vulnerabilities Found

Scanner: **osv-scanner** | Severity threshold: **$SEVERITY_THRESHOLD**
Image: \`$CONTAINER_IMAGE\`

| Image | Vulnerabilities | Status |
|-------|----------------|--------|
| \`$CONTAINER_IMAGE\` | 0 | Passed |
EOF
fi

# =============================================================================
# Fail if configured and vulnerabilities found
# =============================================================================

if [[ "$FAIL_ON_VULNERABILITIES" == "true" && $CONTAINER_COUNT -gt 0 ]]; then
  echo "::error::Found $CONTAINER_COUNT container vulnerabilit$([ $CONTAINER_COUNT -eq 1 ] && echo "y" || echo "ies") (threshold: $SEVERITY_THRESHOLD)"
  exit 1
fi

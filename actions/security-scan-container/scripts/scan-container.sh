#!/bin/bash
# =============================================================================
# Scan Container Image
# =============================================================================
# Pulls the container image and runs osv-scanner to detect vulnerabilities
# in OS packages and language artifacts.
#
# Required env vars:
#   CONTAINER_IMAGE      - Full image reference (e.g. quay.io/blueshoe/app:latest)
#   SEVERITY_THRESHOLD   - low, medium, high, critical
#
# Outputs:
#   container_count       - Number of vulnerabilities meeting threshold
#   container_result_file - Path to JSON results
# =============================================================================

set -e

CONTAINER_RESULT="/tmp/security-scan-container.json"

echo "::group::Scan container image"
echo "Image: $CONTAINER_IMAGE"

# ---------------------------------------------------------------------------
# Pull the image
# ---------------------------------------------------------------------------

echo "Pulling image..."
docker pull "$CONTAINER_IMAGE"

# ---------------------------------------------------------------------------
# Run osv-scanner
# ---------------------------------------------------------------------------

echo "Scanning image with osv-scanner..."

set +e
osv-scanner scan image --format json "$CONTAINER_IMAGE" > "$CONTAINER_RESULT" 2>/tmp/osv-scanner-container-stderr.log
OSV_EXIT=$?
set -e

# Exit code 1 = vulnerabilities found (expected), >1 = error
if [[ $OSV_EXIT -gt 1 ]]; then
  echo "::error::osv-scanner failed with exit code $OSV_EXIT"
  cat /tmp/osv-scanner-container-stderr.log || true
  echo "container_count=0" >> "$GITHUB_OUTPUT"
  echo "container_result_file=" >> "$GITHUB_OUTPUT"
  echo "::endgroup::"
  exit 0
fi

if [[ ! -f "$CONTAINER_RESULT" || ! -s "$CONTAINER_RESULT" ]]; then
  echo "No container vulnerabilities found"
  echo "container_count=0" >> "$GITHUB_OUTPUT"
  echo "container_result_file=" >> "$GITHUB_OUTPUT"
  echo "::endgroup::"
  exit 0
fi

# ---------------------------------------------------------------------------
# Count vulnerabilities meeting severity threshold
# ---------------------------------------------------------------------------

COUNT=$(python3 << PYEOF
import json, sys

SEVERITY_ORDER = {"low": 0, "medium": 1, "high": 2, "critical": 3}
THRESHOLD = SEVERITY_ORDER.get("${SEVERITY_THRESHOLD}".lower(), 2)

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

try:
    with open("${CONTAINER_RESULT}") as f:
        data = json.load(f)
except Exception:
    print(0)
    sys.exit(0)

count = 0
for result in data.get("results", []):
    for pkg in result.get("packages", []):
        for group in pkg.get("groups", []):
            sev = cvss_to_severity(group.get("max_severity", ""))
            sev_level = SEVERITY_ORDER.get(sev, -1)
            if sev_level >= THRESHOLD:
                count += 1
print(count)
PYEOF
)

echo "Container vulnerabilities found: $COUNT"
echo "container_count=$COUNT" >> "$GITHUB_OUTPUT"
echo "container_result_file=$CONTAINER_RESULT" >> "$GITHUB_OUTPUT"

echo "::endgroup::"

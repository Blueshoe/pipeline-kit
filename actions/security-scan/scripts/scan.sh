#!/bin/bash
# =============================================================================
# Scan Dependencies
# =============================================================================
# Runs osv-scanner on Python and/or NPM lock files.
# osv-scanner reads lock files directly — no package manager needed.
#
# Required env vars:
#   SCAN_PYTHON          - "true" to scan Python lock files
#   SCAN_NPM             - "true" to scan NPM lock files
#   SEVERITY_THRESHOLD   - low, medium, high, critical
#   ACTION_PATH          - Path to the action directory
#
# Outputs:
#   python_count         - Number of Python vulnerabilities
#   npm_count            - Number of NPM vulnerabilities
#   python_result_file   - Path to Python JSON results
#   npm_result_file      - Path to NPM JSON results
#
# Supported lock files:
#   Python: requirements.txt, poetry.lock, uv.lock
#   NPM:    package-lock.json
# =============================================================================

set -e

PYTHON_RESULT="/tmp/security-scan-python.json"
NPM_RESULT="/tmp/security-scan-npm.json"

# =============================================================================
# Scan Python dependencies
# =============================================================================

if [[ "$SCAN_PYTHON" == "true" ]]; then
  echo "::group::Scan Python dependencies"

  PYTHON_LOCKFILES=()
  for lockfile in uv.lock poetry.lock requirements.txt; do
    if [[ -f "$lockfile" ]]; then
      PYTHON_LOCKFILES+=("$lockfile")
      echo "Found: $lockfile"
    fi
  done

  if [[ ${#PYTHON_LOCKFILES[@]} -eq 0 ]]; then
    echo "::warning::No Python lock files found — skipping Python scan"
    echo "python_count=0" >> "$GITHUB_OUTPUT"
    echo "python_result_file=" >> "$GITHUB_OUTPUT"
  else
    # Build --lockfile flags
    LOCKFILE_ARGS=()
    for lf in "${PYTHON_LOCKFILES[@]}"; do
      LOCKFILE_ARGS+=("--lockfile" "$lf")
    done

    # osv-scanner exits 1 when vulnerabilities are found — expected
    set +e
    osv-scanner scan --format json "${LOCKFILE_ARGS[@]}" > "$PYTHON_RESULT" 2>/tmp/osv-scanner-python-stderr.log
    OSV_EXIT=$?
    set -e

    if [[ $OSV_EXIT -gt 1 ]]; then
      echo "::error::osv-scanner failed with exit code $OSV_EXIT"
      cat /tmp/osv-scanner-python-stderr.log || true
      echo "python_count=0" >> "$GITHUB_OUTPUT"
      echo "python_result_file=" >> "$GITHUB_OUTPUT"
    elif [[ -f "$PYTHON_RESULT" && -s "$PYTHON_RESULT" ]]; then
      # Count vulnerability groups meeting severity threshold
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
    with open("${PYTHON_RESULT}") as f:
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

      echo "Python vulnerabilities found: $COUNT"
      echo "python_count=$COUNT" >> "$GITHUB_OUTPUT"
      echo "python_result_file=$PYTHON_RESULT" >> "$GITHUB_OUTPUT"
    else
      echo "No Python vulnerabilities found"
      echo "python_count=0" >> "$GITHUB_OUTPUT"
      echo "python_result_file=" >> "$GITHUB_OUTPUT"
    fi
  fi

  echo "::endgroup::"
else
  echo "python_count=0" >> "$GITHUB_OUTPUT"
  echo "python_result_file=" >> "$GITHUB_OUTPUT"
fi

# =============================================================================
# Scan NPM dependencies
# =============================================================================

if [[ "$SCAN_NPM" == "true" ]]; then
  echo "::group::Scan NPM dependencies"

  if [[ ! -f "package-lock.json" ]]; then
    echo "::warning::No package-lock.json found — skipping NPM scan"
    echo "npm_count=0" >> "$GITHUB_OUTPUT"
    echo "npm_result_file=" >> "$GITHUB_OUTPUT"
  else
    echo "Found: package-lock.json"

    set +e
    osv-scanner scan --format json --lockfile package-lock.json > "$NPM_RESULT" 2>/tmp/osv-scanner-npm-stderr.log
    OSV_EXIT=$?
    set -e

    if [[ $OSV_EXIT -gt 1 ]]; then
      echo "::error::osv-scanner failed with exit code $OSV_EXIT"
      cat /tmp/osv-scanner-npm-stderr.log || true
      echo "npm_count=0" >> "$GITHUB_OUTPUT"
      echo "npm_result_file=" >> "$GITHUB_OUTPUT"
    elif [[ -f "$NPM_RESULT" && -s "$NPM_RESULT" ]]; then
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
    with open("${NPM_RESULT}") as f:
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

      echo "NPM vulnerabilities found: $COUNT"
      echo "npm_count=$COUNT" >> "$GITHUB_OUTPUT"
      echo "npm_result_file=$NPM_RESULT" >> "$GITHUB_OUTPUT"
    else
      echo "No NPM vulnerabilities found"
      echo "npm_count=0" >> "$GITHUB_OUTPUT"
      echo "npm_result_file=" >> "$GITHUB_OUTPUT"
    fi
  fi

  echo "::endgroup::"
else
  echo "npm_count=0" >> "$GITHUB_OUTPUT"
  echo "npm_result_file=" >> "$GITHUB_OUTPUT"
fi

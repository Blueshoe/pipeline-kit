#!/bin/bash
# =============================================================================
# Scan Python Dependencies
# =============================================================================
# Detects Python package manager, generates requirements.txt, and runs pip-audit.
#
# Required env vars:
#   REQUIREMENTS_PATH    - Manual path to requirements.txt (empty for auto-detect)
#   PACKAGE_MANAGER      - auto, pip, poetry, uv
#   SEVERITY_THRESHOLD   - low, medium, high, critical
#   ACTION_PATH          - Path to the action directory
#
# Outputs:
#   vulnerability_count  - Number of vulnerabilities found
#   result_file          - Path to JSON results file
#
# Package manager detection priority (when auto):
#   1. uv.lock         → uv export
#   2. poetry.lock      → poetry export
#   3. requirements.txt → direct use
#   4. pyproject.toml   → inspect content for tool.uv / tool.poetry
#   5. Nothing found    → skip with warning
# =============================================================================

set -e

RESULT_FILE="/tmp/security-scan-python.json"
REQUIREMENTS_FILE=""
DETECTED_PM="none"

# =============================================================================
# Helper: export requirements from poetry
# =============================================================================
poetry_export() {
  local output_file="$1"
  # Poetry 2.x requires the export plugin to be installed separately
  if ! poetry self show plugins 2>/dev/null | grep -q "poetry-plugin-export"; then
    echo "Installing poetry-plugin-export..."
    poetry self add poetry-plugin-export 2>&1
  fi
  poetry export -f requirements.txt --without-hashes -o "$output_file"
}

# =============================================================================
# Resolve requirements.txt
# =============================================================================

if [[ -n "$REQUIREMENTS_PATH" ]]; then
  # Manual path provided
  if [[ ! -f "$REQUIREMENTS_PATH" ]]; then
    echo "::error::Specified requirements file not found: $REQUIREMENTS_PATH"
    exit 1
  fi
  REQUIREMENTS_FILE="$REQUIREMENTS_PATH"
  DETECTED_PM="manual"
  echo "Using manually specified requirements: $REQUIREMENTS_FILE"

elif [[ "$PACKAGE_MANAGER" != "auto" ]]; then
  # Explicit package manager specified
  case "$PACKAGE_MANAGER" in
    uv)
      echo "::group::Export requirements from uv"
      REQUIREMENTS_FILE="/tmp/security-scan-requirements.txt"
      uv export --format requirements-txt --no-hashes > "$REQUIREMENTS_FILE"
      echo "::endgroup::"
      DETECTED_PM="uv"
      ;;
    poetry)
      echo "::group::Export requirements from poetry"
      REQUIREMENTS_FILE="/tmp/security-scan-requirements.txt"
      poetry_export "$REQUIREMENTS_FILE"
      echo "::endgroup::"
      DETECTED_PM="poetry"
      ;;
    pip)
      if [[ ! -f "requirements.txt" ]]; then
        echo "::error::requirements.txt not found for pip"
        exit 1
      fi
      REQUIREMENTS_FILE="requirements.txt"
      DETECTED_PM="pip"
      ;;
    *)
      echo "::error::Unknown package manager: $PACKAGE_MANAGER"
      exit 1
      ;;
  esac

else
  # Auto-detect package manager
  if [[ -f "uv.lock" ]]; then
    echo "Detected uv.lock"
    echo "::group::Export requirements from uv"
    REQUIREMENTS_FILE="/tmp/security-scan-requirements.txt"
    uv export --format requirements-txt --no-hashes > "$REQUIREMENTS_FILE"
    echo "::endgroup::"
    DETECTED_PM="uv"

  elif [[ -f "poetry.lock" ]]; then
    echo "Detected poetry.lock"
    echo "::group::Export requirements from poetry"
    REQUIREMENTS_FILE="/tmp/security-scan-requirements.txt"
    poetry_export "$REQUIREMENTS_FILE"
    echo "::endgroup::"
    DETECTED_PM="poetry"

  elif [[ -f "requirements.txt" ]]; then
    echo "Detected requirements.txt"
    REQUIREMENTS_FILE="requirements.txt"
    DETECTED_PM="pip"

  elif [[ -f "pyproject.toml" ]]; then
    echo "Detected pyproject.toml, inspecting content..."
    if grep -q '\[tool\.uv\]' pyproject.toml; then
      echo "Found [tool.uv] section"
      echo "::group::Export requirements from uv"
      REQUIREMENTS_FILE="/tmp/security-scan-requirements.txt"
      uv export --format requirements-txt --no-hashes > "$REQUIREMENTS_FILE"
      echo "::endgroup::"
      DETECTED_PM="uv"
    elif grep -q '\[tool\.poetry\]' pyproject.toml; then
      echo "Found [tool.poetry] section"
      echo "::group::Export requirements from poetry"
      REQUIREMENTS_FILE="/tmp/security-scan-requirements.txt"
      poetry_export "$REQUIREMENTS_FILE"
      echo "::endgroup::"
      DETECTED_PM="poetry"
    else
      echo "::warning::pyproject.toml found but no supported package manager detected"
      echo "vulnerability_count=0" >> "$GITHUB_OUTPUT"
      echo "result_file=" >> "$GITHUB_OUTPUT"
      exit 0
    fi

  else
    echo "::warning::No Python dependency files found — skipping Python scan"
    echo "vulnerability_count=0" >> "$GITHUB_OUTPUT"
    echo "result_file=" >> "$GITHUB_OUTPUT"
    exit 0
  fi
fi

echo "Package manager: $DETECTED_PM"
echo "Requirements file: $REQUIREMENTS_FILE"

# =============================================================================
# Run pip-audit
# =============================================================================

echo "::group::Run pip-audit"

# pip-audit exits non-zero when vulnerabilities are found — that is expected
# Use --no-deps to skip dependency resolution (we only check listed packages)
set +e
pip-audit -r "$REQUIREMENTS_FILE" --format json --no-deps --output "$RESULT_FILE" 2>/tmp/pip-audit-stderr.log
AUDIT_EXIT=$?
set -e

cat /tmp/pip-audit-stderr.log || true
echo "pip-audit exit code: $AUDIT_EXIT"

echo "::endgroup::"

# Exit code 1 = vulnerabilities found (expected), other codes = real errors
if [[ $AUDIT_EXIT -gt 1 ]]; then
  echo "::error::pip-audit failed with exit code $AUDIT_EXIT"
  cat /tmp/pip-audit-stderr.log || true
  exit 1
fi

# Debug: show what pip-audit produced
if [[ -f "$RESULT_FILE" ]]; then
  echo "pip-audit output:"
  cat "$RESULT_FILE"
else
  echo "::warning::pip-audit did not produce output file"
fi

# =============================================================================
# Count vulnerabilities by severity
# =============================================================================

if [[ -f "$RESULT_FILE" ]]; then
  # Count vulnerabilities
  COUNT=$(python3 << 'PYEOF'
import json, sys

try:
    with open("/tmp/security-scan-python.json") as f:
        data = json.load(f)
except Exception as e:
    print(0)
    sys.exit(0)

count = 0
# pip-audit JSON: list of dicts or {"dependencies": [...]}
deps = data if isinstance(data, list) else data.get("dependencies", [])
for dep in deps:
    vulns = dep.get("vulns", [])
    count += len(vulns)

print(count)
PYEOF
)

  echo "Python vulnerabilities found: $COUNT"
  echo "vulnerability_count=$COUNT" >> "$GITHUB_OUTPUT"
  echo "result_file=$RESULT_FILE" >> "$GITHUB_OUTPUT"
else
  echo "vulnerability_count=0" >> "$GITHUB_OUTPUT"
  echo "result_file=" >> "$GITHUB_OUTPUT"
fi

#!/bin/bash
# =============================================================================
# Scan for Secrets
# =============================================================================
# Runs gitleaks to detect leaked secrets in git history or the working
# directory.
#
# Required env vars:
#   SCAN_MODE     - "git" (full history) or "dir" (working directory only)
#
# Optional env vars:
#   CONFIG_PATH   - Path to custom .gitleaks.toml
#   BASELINE_PATH - Path to baseline JSON (known findings to ignore)
#   REDACT        - Redact percentage (0 = fully redacted)
#
# Outputs:
#   leaks_count       - Number of leaks found
#   leaks_result_file - Path to JSON results
# =============================================================================

set -e

LEAKS_RESULT="/tmp/security-gitleaks-results.json"

echo "::group::Scan for secrets (mode: $SCAN_MODE)"

# ---------------------------------------------------------------------------
# Build gitleaks command
# ---------------------------------------------------------------------------

GITLEAKS_ARGS=("$SCAN_MODE")
GITLEAKS_ARGS+=("--report-format" "json")
GITLEAKS_ARGS+=("--report-path" "$LEAKS_RESULT")

# Use exit code 2 for leaks so we can distinguish from tool errors (exit 1)
GITLEAKS_ARGS+=("--exit-code" "2")

if [[ -n "$CONFIG_PATH" ]]; then
  GITLEAKS_ARGS+=("--config" "$CONFIG_PATH")
fi

if [[ -n "$BASELINE_PATH" ]]; then
  GITLEAKS_ARGS+=("--baseline-path" "$BASELINE_PATH")
fi

if [[ -n "$REDACT" ]]; then
  GITLEAKS_ARGS+=("--redact" "$REDACT")
fi

# Scan current directory
GITLEAKS_ARGS+=(".")

echo "Running: gitleaks ${GITLEAKS_ARGS[*]}"
echo "Working directory: $(pwd)"

# ---------------------------------------------------------------------------
# Run gitleaks
# ---------------------------------------------------------------------------

set +e
gitleaks "${GITLEAKS_ARGS[@]}" -v 2>/tmp/gitleaks-stderr.log
GITLEAKS_EXIT=$?
set -e

echo "gitleaks exit code: $GITLEAKS_EXIT"
cat /tmp/gitleaks-stderr.log || true

# Exit codes: 0 = clean, 2 = leaks found (our custom), 1 = tool error
if [[ $GITLEAKS_EXIT -eq 1 ]]; then
  echo "::error::gitleaks encountered an error"
  echo "leaks_count=0" >> "$GITHUB_OUTPUT"
  echo "leaks_result_file=" >> "$GITHUB_OUTPUT"
  echo "::endgroup::"
  exit 0
fi

if [[ $GITLEAKS_EXIT -eq 0 ]]; then
  echo "No secrets found"
  echo "leaks_count=0" >> "$GITHUB_OUTPUT"
  echo "leaks_result_file=" >> "$GITHUB_OUTPUT"
  echo "::endgroup::"
  exit 0
fi

# Exit code 2 = leaks found
if [[ ! -f "$LEAKS_RESULT" || ! -s "$LEAKS_RESULT" ]]; then
  echo "leaks_count=0" >> "$GITHUB_OUTPUT"
  echo "leaks_result_file=" >> "$GITHUB_OUTPUT"
  echo "::endgroup::"
  exit 0
fi

# Count findings
COUNT=$(python3 << PYEOF
import json
try:
    with open("${LEAKS_RESULT}") as f:
        data = json.load(f)
    print(len(data) if isinstance(data, list) else 0)
except Exception:
    print(0)
PYEOF
)

echo "Secrets found: $COUNT"
echo "leaks_count=$COUNT" >> "$GITHUB_OUTPUT"
echo "leaks_result_file=$LEAKS_RESULT" >> "$GITHUB_OUTPUT"

echo "::endgroup::"

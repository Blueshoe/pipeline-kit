#!/bin/bash
# =============================================================================
# Report to Webhook — Gitleaks
# =============================================================================
# Sends gitleaks findings to a webhook API.
#
# Payload format:
#   {
#     "repository_url": "https://github.com/org/repo",
#     "report_data": [ ...findings... ],
#     "scanned_at": "2026-03-26T10:00:00Z",
#     "release": "v1.0.0",
#     "scanner": "gitleaks"
#   }
#
# Required env vars:
#   WEBHOOK_URL            - API base URL
#   WEBHOOK_API_KEY        - API key (sent as X-API-Key header)
#   WEBHOOK_REPOSITORY_URL - Git repository URL
#
# Optional env vars:
#   WEBHOOK_RELEASE - Release name
#   LEAKS_RESULT    - Path to gitleaks JSON results
#
# API endpoint:
#   POST {WEBHOOK_URL}/api/reports/gitleaks
# =============================================================================

set -e

SCAN_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "::group::Report to webhook"
echo "Webhook URL: $WEBHOOK_URL"
echo "Repository: $WEBHOOK_REPOSITORY_URL"

PAYLOAD=$(python3 << PYEOF
import json, sys

findings = []

leaks_file = "${LEAKS_RESULT}"
if leaks_file:
    try:
        with open(leaks_file) as f:
            data = json.load(f)
        if isinstance(data, list):
            findings = data
    except Exception as e:
        print(f"Warning: Could not read gitleaks results: {e}", file=sys.stderr)

if not findings:
    print("No results to report", file=sys.stderr)
    sys.exit(0)

payload = {
    "repository_url": "${WEBHOOK_REPOSITORY_URL}",
    "report_data": findings,
    "scanned_at": "${SCAN_DATE}",
    "scanner": "gitleaks"
}

release = "${WEBHOOK_RELEASE}"
if release:
    payload["release"] = release

print(json.dumps(payload))
PYEOF
)

if [[ -z "$PAYLOAD" ]]; then
  echo "No results to report"
  echo "::endgroup::"
  exit 0
fi

echo "Submitting gitleaks report..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${WEBHOOK_URL}/api/reports/gitleaks" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${WEBHOOK_API_KEY}" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "Gitleaks report submitted (HTTP $HTTP_CODE)"
  echo "  Response: $BODY"
else
  echo "::warning::Failed to submit gitleaks report (HTTP $HTTP_CODE): $BODY"
fi

echo "::endgroup::"

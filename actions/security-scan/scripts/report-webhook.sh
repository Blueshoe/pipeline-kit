#!/bin/bash
# =============================================================================
# Report to Webhook
# =============================================================================
# Sends raw scan results to a webhook API.
# Submits pip-audit and npm audit JSON to dedicated endpoints.
#
# Payload format (per report type):
#   {
#     "repository_url": "https://github.com/org/repo",
#     "report_data": { ... raw tool output ... },
#     "scanned_at": "2026-03-20T10:00:00Z",
#     "release": "v1.0.0"          (optional)
#   }
#
# Required env vars:
#   WEBHOOK_URL            - API base URL (e.g. https://watchdog.blueshoe.de)
#   WEBHOOK_API_KEY        - API key (sent as X-API-Key header)
#   WEBHOOK_REPOSITORY_URL - Git repository URL
#
# Optional env vars:
#   WEBHOOK_RELEASE        - Release name to associate
#   SCAN_PYTHON            - "true" if Python scan was enabled
#   SCAN_NPM               - "true" if NPM scan was enabled
#   PYTHON_RESULT          - Path to pip-audit JSON results
#   NPM_RESULT             - Path to npm audit JSON results
#
# API endpoints:
#   POST {WEBHOOK_URL}/api/reports/pip-audit  - Python vulnerability report
#   POST {WEBHOOK_URL}/api/reports/npm        - NPM vulnerability report
# =============================================================================

set -e

SCAN_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "::group::Report to webhook"
echo "Webhook URL: $WEBHOOK_URL"
echo "Repository: $WEBHOOK_REPOSITORY_URL"

# =============================================================================
# Submit pip-audit report
# =============================================================================

if [[ "$SCAN_PYTHON" == "true" && -n "$PYTHON_RESULT" && -f "$PYTHON_RESULT" ]]; then
  echo "Submitting pip-audit report..."

  # Build request payload
  PAYLOAD=$(python3 -c "
import json, sys

report_data = {}
with open('${PYTHON_RESULT}') as f:
    report_data = json.load(f)

payload = {
    'repository_url': '${WEBHOOK_REPOSITORY_URL}',
    'report_data': report_data,
    'scanned_at': '${SCAN_DATE}'
}

release = '${WEBHOOK_RELEASE}'
if release:
    payload['release'] = release

print(json.dumps(payload))
")

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "${WEBHOOK_URL}/api/reports/pip-audit" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${WEBHOOK_API_KEY}" \
    -d "$PAYLOAD")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "✓ pip-audit report submitted (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
  else
    echo "::warning::Failed to submit pip-audit report (HTTP $HTTP_CODE): $BODY"
  fi
else
  echo "No Python results to report"
fi

# =============================================================================
# Submit npm audit report
# =============================================================================

if [[ "$SCAN_NPM" == "true" && -n "$NPM_RESULT" && -f "$NPM_RESULT" ]]; then
  echo "Submitting npm audit report..."

  PAYLOAD=$(python3 -c "
import json, sys

report_data = {}
with open('${NPM_RESULT}') as f:
    report_data = json.load(f)

payload = {
    'repository_url': '${WEBHOOK_REPOSITORY_URL}',
    'report_data': report_data,
    'scanned_at': '${SCAN_DATE}'
}

release = '${WEBHOOK_RELEASE}'
if release:
    payload['release'] = release

print(json.dumps(payload))
")

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "${WEBHOOK_URL}/api/reports/npm" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${WEBHOOK_API_KEY}" \
    -d "$PAYLOAD")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "✓ npm audit report submitted (HTTP $HTTP_CODE)"
    echo "  Response: $BODY"
  else
    echo "::warning::Failed to submit npm audit report (HTTP $HTTP_CODE): $BODY"
  fi
else
  echo "No NPM results to report"
fi

echo "::endgroup::"

#!/bin/bash
# =============================================================================
# Report to Webhook — Container Scan
# =============================================================================
# Sends osv-scanner container results to a webhook API.
#
# Payload format:
#   {
#     "repository_url": "https://github.com/org/repo",
#     "report_data": { "results": [...] },
#     "scanned_at": "2026-03-20T10:00:00Z",
#     "release": "v1.0.0",
#     "image": "quay.io/blueshoe/app:latest"
#   }
#
# Required env vars:
#   WEBHOOK_URL            - API base URL
#   WEBHOOK_API_KEY        - API key (sent as X-API-Key header)
#   WEBHOOK_REPOSITORY_URL - Git repository URL
#
# Optional env vars:
#   WEBHOOK_RELEASE        - Release name to associate
#   CONTAINER_IMAGE        - Scanned image reference
#   CONTAINER_RESULT       - Path to osv-scanner JSON results
#
# API endpoint:
#   POST {WEBHOOK_URL}/api/reports/osv
# =============================================================================

set -e

SCAN_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "::group::Report to webhook"
echo "Webhook URL: $WEBHOOK_URL"
echo "Repository: $WEBHOOK_REPOSITORY_URL"
echo "Image: $CONTAINER_IMAGE"

# =============================================================================
# Build payload and submit
# =============================================================================

PAYLOAD=$(python3 << PYEOF
import json, sys

results = []

container_file = "${CONTAINER_RESULT}"
if container_file:
    try:
        with open(container_file) as f:
            data = json.load(f)
        results.extend(data.get("results", []))
    except Exception as e:
        print(f"Warning: Could not read container results: {e}", file=sys.stderr)

if not results:
    print("No results to report", file=sys.stderr)
    sys.exit(0)

payload = {
    "repository_url": "${WEBHOOK_REPOSITORY_URL}",
    "report_data": {"results": results},
    "scanned_at": "${SCAN_DATE}",
    "image": "${CONTAINER_IMAGE}"
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

echo "Submitting container OSV report..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${WEBHOOK_URL}/api/reports/osv" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${WEBHOOK_API_KEY}" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
  echo "Container OSV report submitted (HTTP $HTTP_CODE)"
  echo "  Response: $BODY"
else
  echo "::warning::Failed to submit container OSV report (HTTP $HTTP_CODE): $BODY"
fi

echo "::endgroup::"

#!/bin/bash
# =============================================================================
# Cleanup — Container Scan
# =============================================================================
# Removes temporary files and the pulled container image.
# =============================================================================

# Remove temporary scan files
rm -f /tmp/security-scan-container.json
rm -f /tmp/security-scan-container-results.json
rm -f /tmp/osv-scanner-container-stderr.log

# Remove pulled image to save disk space on the runner
if [[ -n "$CONTAINER_IMAGE" ]]; then
  docker rmi "$CONTAINER_IMAGE" 2>/dev/null || true
fi

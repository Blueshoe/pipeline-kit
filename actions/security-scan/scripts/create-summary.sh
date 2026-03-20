#!/bin/bash
# =============================================================================
# Create Summary
# =============================================================================
# Aggregates scan results into a JSON file and generates a GitHub Step Summary.
#
# Required env vars:
#   SCAN_PYTHON            - "true" if Python scan was enabled
#   SCAN_NPM               - "true" if NPM scan was enabled
#   PYTHON_RESULT          - Path to Python JSON results (may be empty)
#   NPM_RESULT             - Path to NPM JSON results (may be empty)
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

python3 -c "
import json, sys
from datetime import datetime, timezone

severity_template = {'low': 0, 'medium': 0, 'high': 0, 'critical': 0}

result = {
    'scan_date': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'severity_threshold': '${SEVERITY_THRESHOLD}',
    'python': {'vulnerabilities': [], 'count': ${PYTHON_COUNT}, 'package_manager': 'unknown', 'severity_counts': dict(severity_template)},
    'npm': {'vulnerabilities': [], 'count': ${NPM_COUNT}, 'severity_counts': dict(severity_template)},
    'total_count': ${TOTAL_COUNT},
    'severity_counts': dict(severity_template)
}

# Include Python results
python_file = '${PYTHON_RESULT}'
if python_file:
    try:
        with open(python_file) as f:
            data = json.load(f)
        deps = data if isinstance(data, list) else data.get('dependencies', [])
        vulns = []
        py_sev = dict(severity_template)
        for dep in deps:
            for vuln in dep.get('vulns', []):
                # pip-audit may include aliases with severity via OSV
                aliases = vuln.get('aliases', [])
                sev = vuln.get('severity', 'unknown')
                # Normalize: pip-audit uses 'UNKNOWN' uppercase sometimes
                sev = sev.lower() if sev else 'unknown'
                if sev in py_sev:
                    py_sev[sev] += 1
                vulns.append({
                    'package': dep.get('name', 'unknown'),
                    'version': dep.get('version', 'unknown'),
                    'id': vuln.get('id', ''),
                    'severity': sev,
                    'fix_versions': vuln.get('fix_versions', []),
                    'description': vuln.get('description', '')
                })
        result['python']['vulnerabilities'] = vulns
        result['python']['severity_counts'] = py_sev
    except Exception as e:
        print(f'Warning: Could not parse Python results: {e}', file=sys.stderr)

# Include NPM results
npm_file = '${NPM_RESULT}'
if npm_file:
    try:
        with open(npm_file) as f:
            data = json.load(f)
        vulns = []
        npm_sev = dict(severity_template)
        # npm uses 'moderate' instead of 'medium' — normalize
        npm_sev_map = {'low': 'low', 'moderate': 'medium', 'high': 'high', 'critical': 'critical'}
        if 'vulnerabilities' in data:
            for name, vuln in data['vulnerabilities'].items():
                raw_sev = vuln.get('severity', 'unknown')
                sev = npm_sev_map.get(raw_sev, raw_sev)
                if sev in npm_sev:
                    npm_sev[sev] += 1
                vulns.append({
                    'package': name,
                    'severity': sev,
                    'via': [v if isinstance(v, str) else v.get('title', '') for v in vuln.get('via', [])],
                    'range': vuln.get('range', ''),
                    'fix_available': vuln.get('fixAvailable', False)
                })
        elif 'advisories' in data:
            for id, advisory in data['advisories'].items():
                raw_sev = advisory.get('severity', 'unknown')
                sev = npm_sev_map.get(raw_sev, raw_sev)
                if sev in npm_sev:
                    npm_sev[sev] += 1
                vulns.append({
                    'package': advisory.get('module_name', 'unknown'),
                    'severity': sev,
                    'title': advisory.get('title', ''),
                    'url': advisory.get('url', ''),
                    'range': advisory.get('vulnerable_versions', '')
                })
        result['npm']['vulnerabilities'] = vulns
        result['npm']['severity_counts'] = npm_sev
    except Exception as e:
        print(f'Warning: Could not parse NPM results: {e}', file=sys.stderr)

# Aggregate severity counts across all scanners
for level in severity_template:
    result['severity_counts'][level] = (
        result['python']['severity_counts'].get(level, 0) +
        result['npm']['severity_counts'].get(level, 0)
    )

with open('${RESULTS_FILE}', 'w') as f:
    json.dump(result, f, indent=2)
"

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

Severity threshold: **$SEVERITY_THRESHOLD**

### Overview

| Scan | Vulnerabilities | Status |
|------|----------------|--------|
EOF

  # Python row
  if [[ "$SCAN_PYTHON" == "true" ]]; then
    if [[ $PYTHON_COUNT -gt 0 ]]; then
      echo "| Python | $PYTHON_COUNT | ❌ |" >> "$GITHUB_STEP_SUMMARY"
    else
      echo "| Python | 0 | ✅ |" >> "$GITHUB_STEP_SUMMARY"
    fi
  else
    echo "| Python | — | Skipped |" >> "$GITHUB_STEP_SUMMARY"
  fi

  # NPM row
  if [[ "$SCAN_NPM" == "true" ]]; then
    if [[ $NPM_COUNT -gt 0 ]]; then
      echo "| NPM | $NPM_COUNT | ❌ |" >> "$GITHUB_STEP_SUMMARY"
    else
      echo "| NPM | 0 | ✅ |" >> "$GITHUB_STEP_SUMMARY"
    fi
  else
    echo "| NPM | — | Skipped |" >> "$GITHUB_STEP_SUMMARY"
  fi

  # Python details
  if [[ "$SCAN_PYTHON" == "true" && $PYTHON_COUNT -gt 0 && -n "$PYTHON_RESULT" ]]; then
    cat >> "$GITHUB_STEP_SUMMARY" << 'EOF'

### Python Vulnerabilities

| Package | Version | Severity | ID | Fix Versions |
|---------|---------|----------|----|-------------|
EOF

    python3 -c "
import json
with open('${PYTHON_RESULT}') as f:
    data = json.load(f)
deps = data if isinstance(data, list) else data.get('dependencies', [])
count = 0
for dep in deps:
    for vuln in dep.get('vulns', []):
        if count >= ${MAX_ENTRIES}:
            print('| ... | truncated at ${MAX_ENTRIES} entries | | | |')
            break
        pkg = dep.get('name', 'unknown')
        ver = dep.get('version', 'unknown')
        sev = vuln.get('severity', 'unknown') or 'unknown'
        vid = vuln.get('id', '-')
        fix = ', '.join(vuln.get('fix_versions', ['-']))
        print(f'| \`{pkg}\` | {ver} | {sev} | {vid} | {fix} |')
        count += 1
    if count >= ${MAX_ENTRIES}:
        break
" >> "$GITHUB_STEP_SUMMARY"
  fi

  # NPM details
  if [[ "$SCAN_NPM" == "true" && $NPM_COUNT -gt 0 && -n "$NPM_RESULT" ]]; then
    cat >> "$GITHUB_STEP_SUMMARY" << 'EOF'

### NPM Vulnerabilities

| Package | Severity | Details |
|---------|----------|---------|
EOF

    node -e "
      const fs = require('fs');
      const data = JSON.parse(fs.readFileSync('${NPM_RESULT}', 'utf8'));
      const max = ${MAX_ENTRIES};
      let count = 0;

      if (data.vulnerabilities) {
        for (const [name, vuln] of Object.entries(data.vulnerabilities)) {
          if (count >= max) {
            console.log('| ... | truncated at ${MAX_ENTRIES} entries | |');
            break;
          }
          const via = (vuln.via || []).map(v => typeof v === 'string' ? v : v.title || '').filter(Boolean).join(', ');
          console.log('| \`' + name + '\` | ' + (vuln.severity || '-') + ' | ' + (via || '-') + ' |');
          count++;
        }
      } else if (data.advisories) {
        for (const [id, advisory] of Object.entries(data.advisories)) {
          if (count >= max) {
            console.log('| ... | truncated at ${MAX_ENTRIES} entries | |');
            break;
          }
          console.log('| \`' + (advisory.module_name || '-') + '\` | ' + (advisory.severity || '-') + ' | ' + (advisory.title || '-') + ' |');
          count++;
        }
      }
    " >> "$GITHUB_STEP_SUMMARY"
  fi

else
  # All clean
  cat >> "$GITHUB_STEP_SUMMARY" << EOF
## ✅ Security Scan — No Vulnerabilities Found

Severity threshold: **$SEVERITY_THRESHOLD**

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

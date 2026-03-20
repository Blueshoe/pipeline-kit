# security-scan

Scans Python and NPM dependencies for known vulnerabilities using `pip-audit` and `npm audit`.

## The Problem

Dependency vulnerabilities accumulate silently. By the time a CVE makes headlines, your project may have been exposed for weeks. Manual auditing doesn't scale across multiple projects with different package managers.

## The Solution

Run automated security scans on a schedule (or on every push) with automatic package manager detection:

- **Python**: Supports pip, poetry, and uv — auto-detects from lock files
- **NPM**: Runs `npm audit` against `package-lock.json`

---

## Quick Start

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
```

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `scan-python` | `'true'` | Enable Python dependency scanning |
| `scan-npm` | `'true'` | Enable NPM dependency scanning |
| `working-directory` | `'.'` | Working directory for scanning |
| `python-requirements-path` | `''` | Manual path to requirements.txt (skips auto-detection) |
| `python-package-manager` | `'auto'` | Python package manager: `auto`, `pip`, `poetry`, `uv` |
| `npm-package-path` | `''` | Path to directory containing package-lock.json |
| `severity-threshold` | `'high'` | Minimum severity to report: `low`, `medium`, `high`, `critical` |
| `fail-on-vulnerabilities` | `'false'` | Fail the action if vulnerabilities are found |
| `webhook-url` | `''` | Webhook API base URL to report results to |
| `webhook-api-key` | `''` | API key for webhook authentication (sent as `X-API-Key` header) |
| `webhook-repository-url` | `''` | Git repository URL to include in the report (defaults to current repo) |
| `webhook-release` | `''` | Release name to associate with the report |

## Outputs

| Output | Description |
|--------|-------------|
| `python-vulnerabilities` | Number of Python vulnerabilities found |
| `npm-vulnerabilities` | Number of NPM vulnerabilities found |
| `total-vulnerabilities` | Total number of vulnerabilities |
| `results-path` | Path to aggregated JSON results file |
| `has-vulnerabilities` | `"true"` or `"false"` |

## Python Package Manager Detection

When `python-package-manager` is set to `auto` (default), detection follows this priority:

1. `uv.lock` exists → `uv export --format requirements-txt --no-hashes`
2. `poetry.lock` exists → `poetry export -f requirements.txt --without-hashes`
3. `requirements.txt` exists → used directly
4. `pyproject.toml` exists → inspects content for `[tool.uv]` or `[tool.poetry]`
5. Nothing found → skips with warning

## Examples

### Scheduled Weekly Scan

```yaml
on:
  schedule:
    - cron: '0 8 * * 1'  # Mondays at 8:00 UTC
  workflow_dispatch:

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - uses: Blueshoe/pipeline-kit/actions/security-scan@v1
        with:
          severity-threshold: 'high'
```

### Python Only (Poetry Project)

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    scan-npm: 'false'
    python-package-manager: 'poetry'
```

### NPM Only with Fail on Findings

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    scan-python: 'false'
    fail-on-vulnerabilities: 'true'
```

### Custom Requirements Path

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    python-requirements-path: './backend/requirements/production.txt'
    scan-npm: 'false'
```

### Monorepo with Separate Directories

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    working-directory: './backend'
    npm-package-path: './frontend'
```

### Report to Webhook

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    webhook-url: 'https://watchdog.blueshoe.de'
    webhook-api-key: ${{ secrets.WEBHOOK_API_KEY }}
    webhook-release: 'v1.2.3'
```

The action sends raw scan results to two endpoints on the configured base URL:

- `POST {webhook-url}/api/reports/pip-audit` — Python results
- `POST {webhook-url}/api/reports/npm` — NPM results

Each request body follows this format:

```json
{
  "repository_url": "https://github.com/org/repo",
  "report_data": { "...raw tool output..." },
  "scanned_at": "2026-03-20T10:00:00Z",
  "release": "v1.2.3"
}
```

The `report_data` field contains the unmodified JSON output from pip-audit or npm audit. The repository URL defaults to the current GitHub repository. Reporting is completely optional — if `webhook-url` or `webhook-api-key` are not set, the step is skipped. Failures in reporting are non-blocking (warnings only).

Any backend implementing these two endpoints can receive reports from this action.

## Results JSON Format

The aggregated results file (path available via `results-path` output) follows this structure:

```json
{
  "scan_date": "2026-03-20T10:00:00Z",
  "severity_threshold": "high",
  "severity_counts": { "low": 0, "medium": 0, "high": 1, "critical": 1 },
  "python": {
    "vulnerabilities": [
      {
        "package": "requests",
        "version": "2.19.1",
        "severity": "high",
        "id": "PYSEC-2023-XXX",
        "fix_versions": ["2.31.0"],
        "description": "..."
      }
    ],
    "count": 1,
    "package_manager": "pip",
    "severity_counts": { "low": 0, "medium": 0, "high": 1, "critical": 0 }
  },
  "npm": {
    "vulnerabilities": [
      {
        "package": "lodash",
        "severity": "critical",
        "via": ["Prototype Pollution"],
        "range": "<4.17.21",
        "fix_available": true
      }
    ],
    "count": 1,
    "severity_counts": { "low": 0, "medium": 0, "high": 0, "critical": 1 }
  },
  "total_count": 2
}
```

## GitHub Step Summary

The action generates a Step Summary with:

- Banner showing total vulnerability count
- Overview table with per-scanner results
- Detail tables per scanner (package, version, CVE, severity)
- Truncated at 50 entries per scanner

## Prerequisites

- **Python scans**: Requires `actions/setup-python` in a prior step
- **NPM scans**: Requires Node.js (provided by runner or `actions/setup-node`)
- **Poetry projects**: Requires `poetry` installed
- **uv projects**: Requires `uv` installed

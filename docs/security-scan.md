# security-scan

Scans Python and NPM dependencies for known vulnerabilities using [osv-scanner](https://github.com/google/osv-scanner).

## The Problem

Dependency vulnerabilities accumulate silently. By the time a CVE makes headlines, your project may have been exposed for weeks. Manual auditing doesn't scale across multiple projects with different package managers.

## The Solution

Run automated security scans on a schedule (or on every push). osv-scanner reads lock files directly — no package manager installation needed:

- **Python**: Reads `requirements.txt`, `poetry.lock`, `uv.lock`
- **NPM**: Reads `package-lock.json`
- **Severity**: CVSS scores included automatically

---

## Quick Start

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
```

No `setup-python` or `setup-node` required — osv-scanner is a standalone binary.

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `scan-python` | `'true'` | Enable Python dependency scanning |
| `scan-npm` | `'true'` | Enable NPM dependency scanning |
| `working-directory` | `'.'` | Working directory for scanning |
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

## Lock File Detection

osv-scanner reads lock files directly from the working directory. No package manager installation or export step needed.

| Lock file | Ecosystem |
|-----------|-----------|
| `requirements.txt` | Python (pip) |
| `poetry.lock` | Python (poetry) |
| `uv.lock` | Python (uv) |
| `package-lock.json` | NPM |

Multiple Python lock files can coexist — all found files are scanned. Priority: `uv.lock`, `poetry.lock`, `requirements.txt`.

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
      - uses: Blueshoe/pipeline-kit/actions/security-scan@v1
        with:
          severity-threshold: 'high'
```

### Python Only

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    scan-npm: 'false'
```

### NPM Only with Fail on Findings

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    scan-python: 'false'
    fail-on-vulnerabilities: 'true'
```

### Subdirectory

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    working-directory: './backend'
```

### Report to Webhook

```yaml
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    webhook-url: ${{ vars.WATCHDOG_URL }}
    webhook-api-key: ${{ secrets.WATCHDOG_API_KEY }}
    webhook-release: 'v1.2.3'
```

The action sends osv-scanner results to a single endpoint:

- `POST {webhook-url}/api/reports/osv`

Request body:

```json
{
  "repository_url": "https://github.com/org/repo",
  "report_data": { "results": [ "...osv-scanner output..." ] },
  "scanned_at": "2026-03-20T10:00:00Z",
  "release": "v1.2.3"
}
```

The `report_data` contains the raw osv-scanner JSON output with full vulnerability details and CVSS severity scores. Reporting is completely optional — if `webhook-url` or `webhook-api-key` are not set, the step is skipped. Failures in reporting are non-blocking (warnings only).

Any backend implementing the `/api/reports/osv` endpoint can receive reports from this action.

## Results JSON Format

The aggregated results file (path available via `results-path` output) follows this structure:

```json
{
  "scan_date": "2026-03-20T10:00:00Z",
  "scanner": "osv-scanner",
  "severity_threshold": "high",
  "severity_counts": { "low": 1, "medium": 2, "high": 1, "critical": 1 },
  "python": {
    "vulnerabilities": [
      {
        "package": "jinja2",
        "version": "2.10",
        "severity": "high",
        "cvss_score": "8.6",
        "ids": ["PYSEC-2019-217", "GHSA-462w-v97r-4m45"],
        "aliases": ["CVE-2019-10906", "GHSA-462w-v97r-4m45"]
      }
    ],
    "count": 1,
    "severity_counts": { "low": 0, "medium": 0, "high": 1, "critical": 0 }
  },
  "npm": {
    "vulnerabilities": [
      {
        "package": "lodash",
        "version": "4.17.4",
        "severity": "critical",
        "cvss_score": "9.1",
        "ids": ["GHSA-jf85-cpcp-j695"],
        "aliases": ["CVE-2021-23337"]
      }
    ],
    "count": 1,
    "severity_counts": { "low": 0, "medium": 0, "high": 0, "critical": 1 }
  },
  "total_count": 2
}
```

## Severity Mapping

CVSS scores from osv-scanner are mapped to severity levels:

| CVSS Score | Severity |
|-----------|----------|
| 9.0 - 10.0 | critical |
| 7.0 - 8.9 | high |
| 4.0 - 6.9 | medium |
| 0.1 - 3.9 | low |

## GitHub Step Summary

The action generates a Step Summary with:

- Banner showing total vulnerability count
- Overview table with per-ecosystem results
- Detail tables with package, version, severity, CVSS score, and vulnerability IDs
- Truncated at 50 entries per ecosystem

## Prerequisites

None — osv-scanner is installed automatically as a standalone binary. No Python, Node.js, or package manager installation required.

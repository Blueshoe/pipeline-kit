# pipeline-kit

Reusable GitHub Actions and workflows for Blueshoe projects.

## Available Actions

| Action | Description | Docs |
|--------|-------------|------|
| [eslint-js-prefix](#eslint-js-prefix) | Enforce js- prefix for DOM selectors | [Details](docs/eslint-js-prefix.md) |
| [security-scan](#security-scan) | Python & NPM vulnerability scanning | [Details](docs/security-scan.md) |
| security-gitleaks | Secret detection | 🔜 Planned |

---

## eslint-js-prefix

Enforces that JavaScript DOM selectors use a `js-` prefix to decouple your code from CSS frameworks.

```javascript
// ❌ Breaks when CSS framework updates
document.querySelector('.btn-danger')

// ✅ Independent of CSS
document.querySelector('.js-delete-button')
```

### Quick Start

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
```

### Common Use Cases

```yaml
# Custom prefix
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    prefix: 'hook-'

# Additional allowed patterns
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    allowed-patterns: '["^my-component-"]'

# Warn instead of fail
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    severity: 'warn'

# Specific directory
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    working-directory: './frontend'
```

📖 **[Full Documentation](docs/eslint-js-prefix.md)** – All inputs, outputs, framework detection, and examples.

---

## security-scan

Scans Python and NPM dependencies for known vulnerabilities. Supports automatic package manager detection (pip, poetry, uv).

### Quick Start

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
- uses: Blueshoe/pipeline-kit/actions/security-scan@v1
  with:
    severity-threshold: 'high'
```

### Scheduled Weekly Scan

```yaml
on:
  schedule:
    - cron: '0 8 * * 1'
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
```

📖 **[Full Documentation](docs/security-scan.md)** – All inputs, outputs, package manager detection, and examples.

---

## Versioning

```yaml
# Recommended: Latest v1.x.x
uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1

# Pinned version
uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1.2.3
```

## Contributing

1. Fork & create feature branch
2. Make changes
3. Run tests: `cd actions/eslint-js-prefix/plugin && npm test`
4. Submit PR

We use [Conventional Commits](https://www.conventionalcommits.org/):
- `fix:` → Patch (v1.0.0 → v1.0.1)
- `feat:` → Minor (v1.0.0 → v1.1.0)
- `feat!:` → Major (v1 → v2)

## License

MIT

# eslint-js-prefix

Enforces a naming convention for DOM selectors in JavaScript to decouple your code from CSS frameworks.

## The Problem

When CSS frameworks like Bootstrap or Tailwind update, your JavaScript can break:

```javascript
// ❌ This breaks when Bootstrap renames .btn-danger
document.querySelector('.btn-danger')

// ❌ This breaks when your CSS refactors #header
document.getElementById('header')
```

## The Solution

Use a dedicated prefix (default: `js-`) for all DOM selectors used in JavaScript:

```javascript
// ✅ This survives any CSS framework update
document.querySelector('.js-delete-button')

// ✅ Your own prefixed IDs are safe
document.getElementById('js-main-nav')
```

---

## Usage

### Basic

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
```

### Full Example

```yaml
name: Lint
on: [push, pull_request]

jobs:
  js-prefix:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
        with:
          working-directory: './src'
          prefix: 'js-'
          severity: 'error'
          allowed-patterns: '["^my-pattern-"]'
          ignored-selectors: '["app", "root"]'
          auto-detect: 'true'
```

---

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `working-directory` | `.` | Directory to lint |
| `prefix` | `js-` | Required prefix for selectors |
| `severity` | `error` | `error` fails the build, `warn` only warns |
| `allowed-patterns` | `[]` | JSON array of regex patterns to allow (merged with auto-detected) |
| `ignored-selectors` | `[]` | JSON array of selector names to ignore |
| `auto-detect` | `true` | Auto-detect frameworks from package.json |

## Outputs

| Output | Description |
|--------|-------------|
| `violations` | Number of violations found |
| `has-violations` | `true` if any violations found |

### Using Outputs

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  id: lint

- run: echo "Found ${{ steps.lint.outputs.violations }} violations"
```

---

## Framework Auto-Detection

When `auto-detect: true` (default), the action scans `package.json` and automatically allows common testing patterns:

| Framework | Detected By | Allowed Patterns |
|-----------|-------------|------------------|
| React / Testing Library / Playwright | `"react"`, `"@testing-library"`, `"@playwright/test"` | `^data-testid$`, `^data-test$` |
| Vue | `"vue"` | `^ref$` |
| Cypress | `"cypress"` | `^data-cy` |

Auto-detected patterns are **merged** with your `allowed-patterns` input.

### Disable Auto-Detection

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    auto-detect: 'false'
    allowed-patterns: '["^data-testid$"]'
```

---

## What Gets Checked

### Methods

- `document.querySelector()`
- `document.querySelectorAll()`
- `document.getElementById()`
- `document.getElementsByClassName()`
- `element.closest()`
- `element.matches()`
- `$()` (jQuery)
- `jQuery()`

### Violations

```javascript
document.querySelector('.btn')           // ❌ Missing js- prefix
document.querySelector('#header')        // ❌ Missing js- prefix
$('.modal')                              // ❌ Missing js- prefix
document.getElementById('sidebar')       // ❌ Missing js- prefix
```

### Valid Code

```javascript
document.querySelector('.js-submit')     // ✅ Has js- prefix
document.querySelector('button')         // ✅ Tag selector (ignored)
document.querySelector('[data-testid]')  // ✅ Attribute selector (ignored)
document.getElementById('js-nav')        // ✅ Has js- prefix
document.querySelector(variable)         // ✅ Dynamic selector (can't check)
```

---

## Examples

### Custom Prefix

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    prefix: 'hook-'
```

### Allow Additional Patterns

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    allowed-patterns: '["^my-component-", "^test-"]'
```

### Ignore Specific Selectors

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    ignored-selectors: '["app", "root", "modal"]'
```

### Warn Instead of Fail

```yaml
- uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
  with:
    severity: 'warn'
```

### Monorepo with Multiple Directories

```yaml
jobs:
  lint-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
        with:
          working-directory: './packages/frontend'

  lint-admin:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: Blueshoe/pipeline-kit/actions/eslint-js-prefix@v1
        with:
          working-directory: './packages/admin'
```

---

## GitHub Summary

The action generates a GitHub Step Summary with:
- ✅ Pass/fail status
- 📊 Violation count
- 📍 Table with file, line, and selector for each violation
- 💡 How to fix instructions

---

## Troubleshooting

### "No JavaScript/TypeScript files found"

The action searches for `.js`, `.jsx`, `.ts`, `.tsx`, and `.vue` files. Check that:
- Your `working-directory` is correct
- Files are not in excluded directories (`node_modules`, `dist`, `build`)

### Patterns Not Working

Patterns are regex strings. Make sure to:
- Escape special characters: `\\.` for literal dot
- Use anchors: `^data-testid$` for exact match, `^data-cy` for prefix match
- Pass as JSON array: `'["^pattern1$", "^pattern2"]'`

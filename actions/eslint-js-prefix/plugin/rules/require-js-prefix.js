'use strict';

/**
 * ESLint Rule: require-js-prefix
 *
 * PURPOSE:
 * Enforces that DOM selectors in JavaScript use a configurable prefix (default: 'js-').
 * This decouples JavaScript from CSS - when CSS frameworks change, your JS doesn't break.
 *
 * WHAT IT CHECKS:
 * - document.querySelector('.some-class')  → should be '.js-some-class'
 * - document.getElementById('header')      → should be 'js-header'
 * - $('.btn-danger')                       → should be '.js-btn-danger'
 *
 * WHAT IT IGNORES:
 * - Tag selectors: querySelector('div')
 * - Attribute selectors: querySelector('[data-id]')
 * - Dynamic selectors: querySelector(variable)
 */

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Extracts class and ID names from a CSS selector string.
 *
 * Example: '.btn.active #header' → [{type:'class', name:'btn'}, {type:'class', name:'active'}, {type:'id', name:'header'}]
 */
function parseSelector(selector) {
  const results = [];

  // Match .classname
  const classMatches = selector.matchAll(/\.([a-zA-Z_-][a-zA-Z0-9_-]*)/g);
  for (const match of classMatches) {
    results.push({ type: 'class', name: match[1] });
  }

  // Match #idname
  const idMatches = selector.matchAll(/#([a-zA-Z_-][a-zA-Z0-9_-]*)/g);
  for (const match of idMatches) {
    results.push({ type: 'id', name: match[1] });
  }

  return results;
}

/**
 * Checks if a selector name is allowed (has prefix, is ignored, or matches pattern).
 */
function isAllowed(name, prefix, allowedPatterns, ignoredSelectors) {
  // Has the required prefix? OK
  if (name.startsWith(prefix)) return true;

  // Is in ignore list? OK
  if (ignoredSelectors.includes(name)) return true;

  // Matches an allowed pattern? OK
  for (const pattern of allowedPatterns) {
    if (pattern.test(name)) return true;
  }

  return false;
}

/**
 * Gets string value from AST node (only for static strings).
 * Returns null for dynamic values like variables or complex template literals.
 */
function getStringValue(node) {
  // Simple string: 'hello'
  if (node.type === 'Literal' && typeof node.value === 'string') {
    return node.value;
  }
  // Simple template literal: `hello` (no interpolation)
  if (node.type === 'TemplateLiteral' && node.quasis.length === 1) {
    return node.quasis[0].value.cooked;
  }
  return null;
}

// ============================================================================
// RULE DEFINITION
// ============================================================================

module.exports = {
  meta: {
    type: 'suggestion',
    docs: {
      description: 'Enforce js- prefix for DOM selectors to decouple JavaScript from CSS',
      recommended: true
    },
    schema: [{
      type: 'object',
      properties: {
        prefix: { type: 'string', default: 'js-' },
        allowedPatterns: { type: 'array', items: { type: 'string' }, default: [] },
        ignoredSelectors: { type: 'array', items: { type: 'string' }, default: [] }
      },
      additionalProperties: false
    }],
    messages: {
      missingPrefix: "Selector '{{selector}}' should use '{{prefix}}' prefix. Use '{{prefix}}{{selector}}' instead."
    }
  },

  create(context) {
    // Get options with defaults
    const options = context.options[0] || {};
    const prefix = options.prefix || 'js-';
    const allowedPatterns = (options.allowedPatterns || []).map(p => new RegExp(p));
    const ignoredSelectors = options.ignoredSelectors || [];

    // DOM methods that accept CSS selectors
    const SELECTOR_METHODS = ['querySelector', 'querySelectorAll', 'closest', 'matches'];

    /**
     * Reports a violation for a selector that's missing the prefix.
     */
    function report(node, selectorName) {
      context.report({
        node,
        messageId: 'missingPrefix',
        data: { selector: selectorName, prefix }
      });
    }

    /**
     * Checks a CSS selector string and reports violations.
     */
    function checkSelector(node, selectorValue) {
      // Skip pure tag selectors like 'div' or '[data-id]' (no . or #)
      if (!selectorValue.includes('.') && !selectorValue.includes('#')) {
        return;
      }

      for (const { name } of parseSelector(selectorValue)) {
        if (!isAllowed(name, prefix, allowedPatterns, ignoredSelectors)) {
          report(node, name);
        }
      }
    }

    // ========================================================================
    // AST VISITOR
    // ========================================================================

    return {
      CallExpression(node) {
        const { callee, arguments: args } = node;
        if (args.length === 0) return;

        const firstArg = args[0];
        const value = getStringValue(firstArg);
        if (value === null) return; // Skip dynamic values

        // -----------------------------------------------------------------
        // Handle: document.querySelector('.class'), element.closest('#id')
        // -----------------------------------------------------------------
        if (callee.type === 'MemberExpression' && callee.property.type === 'Identifier') {
          const method = callee.property.name;

          if (SELECTOR_METHODS.includes(method)) {
            checkSelector(firstArg, value);
            return;
          }

          // getElementById takes ID without # prefix
          if (method === 'getElementById') {
            if (!isAllowed(value, prefix, allowedPatterns, ignoredSelectors)) {
              report(firstArg, value);
            }
            return;
          }

          // getElementsByClassName takes class names without . prefix (can be space-separated)
          if (method === 'getElementsByClassName') {
            for (const className of value.split(/\s+/).filter(Boolean)) {
              if (!isAllowed(className, prefix, allowedPatterns, ignoredSelectors)) {
                report(firstArg, className);
              }
            }
            return;
          }
        }

        // -----------------------------------------------------------------
        // Handle: $('.class'), jQuery('#id')
        // -----------------------------------------------------------------
        if (callee.type === 'Identifier' && (callee.name === '$' || callee.name === 'jQuery')) {
          checkSelector(firstArg, value);
        }
      }
    };
  }
};

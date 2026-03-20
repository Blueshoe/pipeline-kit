'use strict';

/**
 * Unit Tests for require-js-prefix ESLint rule
 *
 * Run with: npm test
 *
 * These tests verify that:
 * - Selectors with the prefix are allowed
 * - Selectors without the prefix are flagged
 * - Tag selectors (div, button) are ignored
 * - Dynamic selectors (variables) are ignored
 * - Custom prefixes and patterns work correctly
 */

const { RuleTester } = require('eslint');
const rule = require('../rules/require-js-prefix');

const ruleTester = new RuleTester({
  languageOptions: { ecmaVersion: 2020 }
});

ruleTester.run('require-js-prefix', rule, {
  // =========================================================================
  // VALID CASES - These should NOT trigger errors
  // =========================================================================
  valid: [
    // --- Selectors with js- prefix (the correct way) ---
    "document.querySelector('.js-submit')",
    "document.querySelectorAll('.js-item')",
    "element.closest('.js-container')",
    "$('.js-modal')",
    "document.getElementById('js-main-nav')",
    "document.getElementsByClassName('js-item')",

    // --- Tag selectors (always allowed) ---
    "document.querySelector('button')",
    "document.querySelector('div')",
    "document.querySelector('input[type=\"text\"]')",

    // --- Attribute selectors (always allowed) ---
    "document.querySelector('[data-testid]')",
    "document.querySelector('[aria-label=\"close\"]')",

    // --- Dynamic selectors (can't be checked statically) ---
    "document.querySelector(selector)",
    "document.querySelector(getSelector())",
    "document.querySelector(`.${className}`)",

    // --- Custom prefix ---
    {
      code: "document.querySelector('.hook-submit')",
      options: [{ prefix: 'hook-' }]
    },

    // --- Custom allowed patterns ---
    {
      code: "document.querySelector('.data-testid-button')",
      options: [{ allowedPatterns: ['^data-testid-'] }]
    },

    // --- Custom ignored selectors ---
    {
      code: "document.querySelector('.app-root')",
      options: [{ ignoredSelectors: ['app-root'] }]
    }
  ],

  // =========================================================================
  // INVALID CASES - These SHOULD trigger errors
  // =========================================================================
  invalid: [
    // --- Basic class selector without prefix ---
    {
      code: "document.querySelector('.btn')",
      errors: [{ messageId: 'missingPrefix' }]
    },
    {
      code: "document.querySelector('.btn-danger')",
      errors: [{ messageId: 'missingPrefix' }]
    },

    // --- ID selector without prefix ---
    {
      code: "document.querySelector('#header')",
      errors: [{ messageId: 'missingPrefix' }]
    },

    // --- jQuery without prefix ---
    {
      code: "$('.modal')",
      errors: [{ messageId: 'missingPrefix' }]
    },
    {
      code: "jQuery('.dropdown-menu')",
      errors: [{ messageId: 'missingPrefix' }]
    },

    // --- getElementById without prefix ---
    {
      code: "document.getElementById('sidebar')",
      errors: [{ messageId: 'missingPrefix' }]
    },

    // --- getElementsByClassName without prefix ---
    {
      code: "document.getElementsByClassName('item')",
      errors: [{ messageId: 'missingPrefix' }]
    },

    // --- Multiple violations in one selector ---
    {
      code: "document.querySelector('.btn .icon')",
      errors: [
        { messageId: 'missingPrefix' },
        { messageId: 'missingPrefix' }
      ]
    },

    // --- Mixed: one valid, one invalid ---
    {
      code: "document.querySelector('.js-form .invalid-class')",
      errors: [{ messageId: 'missingPrefix' }]
    },

    // --- Wrong prefix when custom prefix is set ---
    {
      code: "document.querySelector('.js-submit')",
      options: [{ prefix: 'hook-' }],
      errors: [{ messageId: 'missingPrefix' }]
    }
  ]
});

console.log('✅ All tests passed!');

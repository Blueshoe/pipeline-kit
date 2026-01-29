'use strict';

/**
 * ESLint Plugin: eslint-plugin-js-prefix
 *
 * Provides the 'require-js-prefix' rule that enforces a prefix convention
 * for DOM selectors in JavaScript code.
 *
 * Usage in ESLint config:
 *
 *   import jsPrefix from 'eslint-plugin-js-prefix';
 *
 *   export default [{
 *     plugins: { 'js-prefix': jsPrefix },
 *     rules: {
 *       'js-prefix/require-js-prefix': ['error', { prefix: 'js-' }]
 *     }
 *   }];
 */

const requireJsPrefix = require('./rules/require-js-prefix');

module.exports = {
  meta: {
    name: 'eslint-plugin-js-prefix',
    version: '1.0.0'
  },
  rules: {
    'require-js-prefix': requireJsPrefix
  }
};

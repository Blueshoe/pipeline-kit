/**
 * Example file with DOM selector violations - uses CSS framework classes
 * This file should produce exactly 5 violations
 */

// Violation 1: Bootstrap button class
const dangerButton = document.querySelector('.btn-danger');

// Violation 2: Bootstrap nav class
const navItems = document.querySelectorAll('.nav-item');

// Violation 3: jQuery with CSS class
$('.modal');

// Violation 4: jQuery with ID
jQuery('#header');

// Violation 5: getElementById without prefix
document.getElementById('sidebar');

// These are valid and should NOT produce violations:
const validButton = document.querySelector('.js-submit');
const validTag = document.querySelector('button');
const validAttr = document.querySelector('[data-testid="login"]');

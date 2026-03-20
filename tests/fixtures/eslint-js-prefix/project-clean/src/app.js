/**
 * Example file with valid DOM selectors using js- prefix convention
 */

// Valid: js- prefixed class selectors
const submitButton = document.querySelector('.js-submit-button');
const deleteButtons = document.querySelectorAll('.js-delete-item');
const modal = document.querySelector('.js-modal');
const dropdown = document.querySelector('.js-dropdown-menu');

// Valid: js- prefixed ID selector
const mainNav = document.querySelector('#js-main-navigation');

// Valid: Tag selectors (no class/ID)
const allButtons = document.querySelectorAll('button');
const inputFields = document.querySelectorAll('input[type="text"]');
const formElement = document.querySelector('form');

// Valid: Attribute selectors
const testElements = document.querySelectorAll('[data-testid]');
const ariaElements = document.querySelector('[aria-label="close"]');

// Valid: Combined selectors with js- prefix
const formSubmit = document.querySelector('.js-form button');
const navLinks = document.querySelectorAll('nav .js-link');

// Valid: element methods with js- prefix
const container = document.querySelector('.js-container');
const parent = container?.closest('.js-wrapper');
const isActive = container?.matches('.js-active');

// Valid: getElementById with js- prefix
const sidebar = document.getElementById('js-sidebar');

// Valid: getElementsByClassName with js- prefix
const items = document.getElementsByClassName('js-list-item');

// Valid: jQuery-style with js- prefix (if jQuery is used)
// $('.js-accordion').slideToggle();
// jQuery('.js-tabs').tabs();

console.log('All selectors follow the js- prefix convention!');

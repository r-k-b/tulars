// ***********************************************************
// This example support/index.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using ES2015 syntax:
import './commands'

// Alternatively you can use CommonJS syntax:
// require('./commands')

const att = (handle) => `[data-cy="${handle}"]`

/**
 * Central list of element references used by all Cypress tests.
 *
 * Pro tip: Keeping all the keys sorted alphabetically will cut down on merge
 * conflicts, and make it easier to spot differences with the Elm equivalent.
 *
 * ---
 *
 * How can we automatically keep these in sync with `app/CypressHandles.elm`?
 *
 * @example
 * import {handle} from '../support'
 * // ...
 *   cy.get(handle.tabs.bar)
 *     .children(handle.tabs.tab)
 *     .should('have.length', 1)
 * // ...
 */
export const handle =
    {
        mainContent: att("main-content"),
        mainMenu:
            {
                about: att("main-menu__about"),
                loadScene: att("main-menu__load-scene"),
            },
        tabs:
            {
                bar: att("tab-bar"),
                tab: att("tab-bar__tab"),
            },
    }

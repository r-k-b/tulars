/// <reference types="cypress" />

import {handle} from '../support'

context('Actions', () => {
    beforeEach(() => {
        cy.visit('/');
    })

    it('should open a new tab for the About page', () => {
        cy.get(handle.tabs.bar)
            .children(handle.tabs.tab)
            .should('have.length', 1)

        cy.get(handle.mainContent)
            .contains('Created by')
            .should('not.exist')

        cy.get(handle.mainMenu.about)
            .click()

        cy.get(handle.mainContent)
            .contains('Created by')
            .should('exist')

        cy.get(handle.tabs.bar)
            .children(handle.tabs.tab)
            .should('have.length', 2)
            .contains('About Tulars')
    })
})

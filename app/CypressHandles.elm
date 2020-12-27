module CypressHandles exposing (cypress)

import Html
import Html.Attributes


{-| Any element reference that is used in a Cypress test should live in this
object.

That'll help keep track of usages, and with autocomplete.

Handles must be safe to use unescaped in an html attribute.
E.g, no `"` or `>`.

See also: <https://docs.cypress.io/guides/references/best-practices.html>

Pro tip: Keeping all the keys sorted alphabetically will cut down on merge
conflicts, and make it easier to spot differences with the Cypress support
object.

---

How can we automatically keep these in sync with `cypress/support/index.js`?

-}
cypress :
    { mainContent : Html.Attribute msg
    , mainMenu :
        { about : Html.Attribute msg
        , agentInfo : Html.Attribute msg
        , loadScene : Html.Attribute msg
        }
    , tabs : { bar : Html.Attribute msg, tab : Html.Attribute msg }
    }
cypress =
    { mainContent = att "main-content"
    , mainMenu =
        { about = att "main-menu__about"
        , agentInfo = att "main-menu__agent-info"
        , loadScene = att "main-menu__load-scene"
        }
    , tabs =
        { bar = att "tab-bar"
        , tab = att "tab-bar__tab"
        }
    }


att : String -> Html.Attribute msg
att handle =
    Html.Attributes.attribute "data-cy" handle

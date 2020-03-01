module StylingClasses exposing (classes, svgClass)

import Svg.Attributes


{-| Here's the only place CSS class strings should be directly referenced.

That'll help keep track of usages, and with autocomplete.

Pro tip: Keeping all the keys sorted alphabetically will cut down on merge
conflicts.

-}
classes =
    { activeMenuItem = "menu-item--active"
    , clickable = "clickable"
    , theme =
        { notSoHarsh = "theme--not-so-harsh"
        }
    , pageGrid =
        { agentInfo = "page-grid__agent-info"
        , container = "page-grid__container"
        , content = "page-grid__content"
        , menu = "page-grid__menu"
        , subMenu = "page-grid__submenu"
        , tabs = "page-grid__tabs"
        }
    , parentButton =
        { button = "parent-button"
        , text = "parent-button__text"
        , indicator = "parent-button__indicator"
        }
    , selectedTab = "page-grid__tabs__tab--selected"
    , tab = "page-grid__tabs__tab"
    , tabCloser = "page-grid__tabs__tab-closer"
    , tabText = "page-grid__tabs__tab__text"
    , zoomSvg = "zoom-svg"
    }


svgClass =
    { borders = Svg.Attributes.class "borders"
    , considerationChart = Svg.Attributes.class "consideration-chart"
    , currentValue = Svg.Attributes.class "current-value"
    , healthBar = Svg.Attributes.class "healthbar"
    , held = Svg.Attributes.class "held"
    , layer =
        { names = Svg.Attributes.class "layer__names"
        , statusBars = Svg.Attributes.class "layer__status-bars"
        }
    , progressBar = Svg.Attributes.class "progressbar"
    , ticks = Svg.Attributes.class "ticks"
    }

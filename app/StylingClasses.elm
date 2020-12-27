module StylingClasses exposing (classes, svgClass)

import Svg
import Svg.Attributes


{-| Here's the only place CSS class strings should be directly referenced.

That'll help keep track of usages, and with autocomplete.

Pro tip: Keeping all the keys sorted alphabetically will cut down on merge
conflicts.

-}
classes :
    { activeMenuItem : String
    , clickable : String
    , fullSize : String
    , theme : { notSoHarsh : String }
    , logHud : String
    , logHudLine : String
    , pageGrid :
        { agentInfo : String
        , container : String
        , content : String
        , menu : String
        , subMenu : String
        , tabs : String
        }
    , parentButton : { button : String, text : String, indicator : String }
    , position : { relative : String }
    , selectedTab : String
    , tab : String
    , tabCloser : String
    , tabText : String
    , zoomSvg : String
    }
classes =
    { activeMenuItem = "menu-item--active"
    , clickable = "clickable"
    , fullSize = "full-size"
    , theme =
        { notSoHarsh = "theme--not-so-harsh"
        }
    , logHud = "log-hud"
    , logHudLine = "log-hud__line"
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
    , position =
        { relative = "pos-relative"
        }
    , selectedTab = "page-grid__tabs__tab--selected"
    , tab = "page-grid__tabs__tab"
    , tabCloser = "page-grid__tabs__tab-closer"
    , tabText = "page-grid__tabs__tab__text"
    , zoomSvg = "zoom-svg"
    }


svgClass :
    { borders : Svg.Attribute msg
    , considerationChart : Svg.Attribute a
    , currentValue : Svg.Attribute b
    , healthBar : Svg.Attribute c
    , held : Svg.Attribute d
    , layer : { names : Svg.Attribute e, statusBars : Svg.Attribute f }
    , progressBar : Svg.Attribute g
    , ticks : Svg.Attribute h
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

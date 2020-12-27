module View exposing (view)

import BoundingBox2d as BoundingBox2d exposing (BoundingBox2d)
import Browser exposing (Document)
import Circle2d as Circle2d
import CypressHandles exposing (cypress)
import Dict
import Direction2d as Direction2d
import Frame2d as Frame2d
import Geometry.Svg as Svg
import Html
    exposing
        ( Attribute
        , Html
        , a
        , button
        , code
        , div
        , em
        , h2
        , h3
        , h4
        , h5
        , li
        , p
        , span
        , table
        , td
        , text
        , th
        , tr
        , ul
        )
import Html.Attributes as HA exposing (href, style)
import Html.Events exposing (onClick)
import Json.Decode as JD
import Length exposing (Meters)
import LineSegment2d
import List exposing (take)
import List.Extra exposing (takeWhile)
import Menu
    exposing
        ( AnnotatedCrumb
        , AnnotatedCrumbChildren(..)
        , zipperToAnnotatedBreadcrumbs
        )
import Pixels exposing (Pixels)
import Point2d as Point2d exposing (xCoordinate, yCoordinate)
import Quantity exposing (Quantity)
import Round
import SelectList exposing (SelectList, selected)
import StylingClasses exposing (classes, svgClass)
import Svg exposing (Svg, g, rect, stop, text_)
import Svg.Attributes
    exposing
        ( cx
        , cy
        , fill
        , fontSize
        , height
        , id
        , offset
        , r
        , stopColor
        , stopOpacity
        , stroke
        , textAnchor
        , viewBox
        , width
        , x
        , x1
        , x2
        , y
        , y1
        , y2
        )
import Time exposing (Posix, millisToPosix, posixToMillis)
import Tree.Zipper as Zipper exposing (Zipper)
import Tuple exposing (first, second)
import Types
    exposing
        ( Action
        , Agent
        , CarryableCheck(..)
        , Consideration
        , ConsiderationInput(..)
        , Fire
        , FireExtinguisher
        , Food
        , Growable
        , GrowableState(..)
        , Hitpoints(..)
        , Holding(..)
        , InputFunction(..)
        , Layer(..)
        , LogEntry
        , MenuItem
        , MenuItemLabel(..)
        , MenuItemType(..)
        , Model
        , Msg(..)
        , Portable(..)
        , Range(..)
        , Retardant
        , Route(..)
        , Signal(..)
        , YDownCoords
        )
import UtilityFunctions
    exposing
        ( boolString
        , clampTo
        , computeConsideration
        , computeUtility
        , differenceInMillis
        , getActions
        , getConsiderationRawValue
        , hpAsFloat
        , isHolding
        , linearTransform
        , normaliseRange
        , rangeCurrentValue
        )
import Vector2d as Vector2d exposing (scaleBy)


view : Model -> Document Msg
view model =
    let
        body =
            div [ classes.pageGrid.container |> HA.class ]
                [ viewMenu model.paused model.menu
                    |> div
                        [ classes.pageGrid.menu |> HA.class
                        , classes.theme.notSoHarsh |> HA.class
                        ]
                , viewTabs model.tabs
                , div
                    [ classes.pageGrid.content |> HA.class
                    , classes.position.relative |> HA.class
                    , cypress.mainContent
                    ]
                    [ case model.tabs |> selected of
                        About ->
                            viewAboutPage model.gitHash

                        MainMap ->
                            mainMap model

                        Variants ->
                            viewVariantsPage
                    ]
                ]
    in
    { title = "Tulars", body = [ body ] }


viewTabs : SelectList Route -> Html Msg
viewTabs tabs =
    div
        [ classes.pageGrid.tabs |> HA.class
        , classes.theme.notSoHarsh |> HA.class
        , cypress.tabs.bar
        ]
        (tabs |> SelectList.indexedMap viewTab)


viewTab : Int -> Route -> Html Msg
viewTab relativeIndex tab =
    div
        [ classes.tab |> HA.class
        , HA.classList [ ( classes.selectedTab, relativeIndex == 0 ) ]
        , classes.clickable |> HA.class
        , onClick <| TabClicked relativeIndex
        , cypress.tabs.tab
        ]
        [ span
            [ classes.tabText |> HA.class ]
            [ tab |> tabName |> text ]
        , span
            [ classes.tabCloser |> HA.class
            , classes.clickable |> HA.class
            , onClickNoPropagation <| TabCloserClicked tab relativeIndex
            , HA.title "Close tab"
            ]
            [ text "×" ]
        ]


onClickNoPropagation : Msg -> Attribute Msg
onClickNoPropagation msg =
    Html.Events.stopPropagationOn "click" (JD.succeed ( msg, True ))


tabName : Route -> String
tabName route =
    case route of
        About ->
            "About Tulars"

        MainMap ->
            "Main Map"

        Variants ->
            "Code Variants"


viewMenu : Bool -> Zipper (MenuItem Msg) -> List (Html Msg)
viewMenu isPaused zipper =
    zipper
        |> zipperToAnnotatedBreadcrumbs
        |> viewCrumbTrail isPaused { atRoot = True }


viewCrumbTrail : Bool -> { atRoot : Bool } -> AnnotatedCrumb (MenuItem Msg) -> List (Html Msg)
viewCrumbTrail isPaused { atRoot } crumbTrail =
    if atRoot then
        crumbTrail.directChildren |> viewChildrenOfCrumb isPaused

    else
        List.concat
            [ crumbTrail.siblingsBefore |> List.concatMap (viewMenuItem isPaused)
            , viewExpandedMenuItem isPaused crumbTrail.focus crumbTrail.directChildren
            , crumbTrail.siblingsAfter |> List.concatMap (viewMenuItem isPaused)
            ]


viewChildrenOfCrumb : Bool -> AnnotatedCrumbChildren (MenuItem Msg) -> List (Html Msg)
viewChildrenOfCrumb isPaused annotatedCrumbChildren =
    case annotatedCrumbChildren of
        NoMoreCrumbs directChildren ->
            directChildren |> List.concatMap (viewMenuItem isPaused)

        CrumbTrailContinues siblingsBefore annotatedCrumb siblingsAfter ->
            List.concat
                [ siblingsBefore |> List.concatMap (viewMenuItem isPaused)
                , viewCrumbTrail isPaused { atRoot = False } annotatedCrumb
                , siblingsAfter |> List.concatMap (viewMenuItem isPaused)
                ]


viewExpandedMenuItem :
    Bool
    -> Zipper (MenuItem Msg)
    -> AnnotatedCrumbChildren (MenuItem Msg)
    -> List (Html Msg)
viewExpandedMenuItem isPaused menuItem children =
    let
        focus =
            menuItem |> Zipper.label
    in
    case focus.menuItemType of
        SimpleItem msg ->
            [ button
                [ onClick msg
                , focus.cypressHandle |> orNoAttribute
                ]
                [ text <| labelToString isPaused focus.name ++ " (simple)" ]
            ]

        ParentItem ->
            [ button
                [ onClick <| OpenMenuAt (menuItem |> Zipper.root)
                , classes.activeMenuItem |> HA.class
                , classes.parentButton.button |> HA.class
                , focus.cypressHandle |> orNoAttribute
                ]
                [ span
                    [ classes.parentButton.text |> HA.class ]
                    [ text (labelToString isPaused focus.name) ]
                , span
                    [ classes.parentButton.indicator |> HA.class ]
                    [ text "▶" ]
                ]
            , viewChildrenOfCrumb isPaused children
                |> div [ classes.pageGrid.subMenu |> HA.class ]
            ]


viewMenuItem : Bool -> Zipper (MenuItem Msg) -> List (Html Msg)
viewMenuItem isPaused item =
    let
        focus =
            item |> Zipper.label
    in
    case focus.menuItemType of
        SimpleItem msg ->
            [ Html.button
                [ onClick msg
                , focus.cypressHandle |> orNoAttribute
                ]
                [ text (labelToString isPaused focus.name) ]
            ]

        ParentItem ->
            if item |> Zipper.children |> List.length |> (<) 0 then
                [ button
                    [ onClick <| OpenMenuAt item
                    , classes.parentButton.button |> HA.class
                    , focus.cypressHandle |> orNoAttribute
                    ]
                    [ span
                        [ classes.parentButton.text |> HA.class ]
                        [ text (labelToString isPaused focus.name) ]
                    , span
                        [ classes.parentButton.indicator |> HA.class ]
                        [ text "▶" ]
                    ]
                ]

            else
                [ button
                    [ onClick <| OpenMenuAt item
                    , focus.cypressHandle |> orNoAttribute
                    ]
                    [ text (labelToString isPaused focus.name) ]
                ]


bb : BoundingBox2d Meters YDownCoords
bb =
    BoundingBox2d.fromExtrema
        { minX = Length.meters -300
        , maxX = Length.meters 300
        , minY = Length.meters -300
        , maxY = Length.meters 300
        }


render2dResponsive : BoundingBox2d Meters YDownCoords -> Svg msg -> Html msg
render2dResponsive boundingBox svgMsg =
    let
        { minX, maxY } =
            BoundingBox2d.extrema boundingBox

        topLeftFrame =
            -- this seems clunky... is there a neater way?
            Frame2d.atPoint
                (Point2d.fromMeters
                    { x = minX |> Length.inMeters, y = maxY |> Length.inMeters }
                )

        ( bbWidth, bbHeight ) =
            BoundingBox2d.dimensions boundingBox

        coords =
            [ 0
            , -(bbHeight |> Length.inMeters)
            , bbWidth |> Length.inMeters
            , bbHeight |> Length.inMeters
            ]
                |> List.map String.fromFloat
                |> String.join " "
    in
    Svg.svg
        [ Svg.Attributes.width (String.fromFloat <| Length.inMeters <| bbWidth)
        , Svg.Attributes.height (String.fromFloat <| Length.inMeters <| bbHeight)
        , viewBox coords
        ]
        [ Svg.relativeTo topLeftFrame svgMsg ]


mainMap : Model -> Html.Html Msg
mainMap model =
    div [ classes.fullSize |> HA.class, classes.zoomSvg |> HA.class ]
        [ render2dResponsive bb
            (g [ id "mainMap" ]
                [ borderIndicator (Pixels.pixels 200)
                , borderIndicator (Pixels.pixels 300)
                , g [ id "agents" ]
                    (List.map renderAgent model.agents)
                , g [ id "foods" ]
                    (List.map renderFood model.foods)
                , g [ id "fires" ]
                    (List.map renderFire model.fires)
                , g [ id "growables" ]
                    (List.map renderGrowable model.growables)
                , g [ id "extinguishers" ]
                    (List.map renderExtinguisher model.extinguishers)
                , g [ id "retardantProjectiles" ]
                    (List.map renderRetardantCloud model.retardants)
                ]
            )
        , viewHud model
        ]


logEntryIsAfter : Posix -> LogEntry -> Bool
logEntryIsAfter posix entry =
    posixToMillis entry.time > posixToMillis posix


{-| In milliseconds.

TODO: Replace with a Duration?

-}
secondInMillis : Int
secondInMillis =
    1000


maxHudLinesToShowAtOnce : Int
maxHudLinesToShowAtOnce =
    20


viewHud : Model -> Html.Html Msg
viewHud model =
    let
        -- How to keep this in sync with the timing in [main.css > `.log-hud__line`]?
        cutoff : Posix
        cutoff =
            model.time
                |> posixToMillis
                |> (\now -> now - (10 * secondInMillis))
                |> millisToPosix

        recentEntries =
            model.log
                |> take maxHudLinesToShowAtOnce
                |> takeWhile (logEntryIsAfter cutoff)
    in
    case recentEntries of
        [] ->
            text ""

        _ ->
            div [ classes.logHud |> HA.class ]
                (recentEntries |> List.map viewHudLine)


viewHudLine : LogEntry -> Html Msg
viewHudLine line =
    (case line.entry of
        Types.AgentEntry pastTense point2d ->
            [ text "an agent did something" ]

        Types.SceneLoaded name ->
            [ text "Loaded Scene: "
            , em [] [ text name ]
            ]

        Types.SceneSaved ->
            [ text "Scene saved" ]
    )
        |> div [ classes.logHudLine |> HA.class ]


borderIndicator : Quantity Float Pixels -> Svg Msg
borderIndicator radius =
    Svg.circle2d
        [ Svg.Attributes.fillOpacity "0"
        , Svg.Attributes.stroke "var(--color-bg--almost)"
        , Svg.Attributes.strokeWidth "1"
        ]
        (Circle2d.withRadius radius Point2d.origin)


agentsInfo : Posix -> List Agent -> Html.Html Msg
agentsInfo currentTime agents =
    div []
        [ h2 []
            [ text "Agents" ]
        , div
            []
            (List.map (renderAgentInfo currentTime) agents)
        ]


inPx : Float -> String
inPx number =
    String.fromFloat number ++ "px"


agentVelocityArrow : Agent -> Svg msg
agentVelocityArrow agent =
    let
        exaggerated : Vector2d.Vector2d Meters YDownCoords
        exaggerated =
            scaleBy 2 agent.physics.velocity

        exaggeratedLength =
            Vector2d.length exaggerated
    in
    --    todo: restore the "arrow" representation
    Svg.lineSegment2d
        [ Svg.Attributes.stroke "blue"
        , Svg.Attributes.strokeWidth "1"
        , Svg.Attributes.strokeDasharray "1 2"
        ]
        (LineSegment2d.fromEndpoints
            ( origin
            , origin |> Point2d.translateBy exaggerated
            )
        )


renderAgent : Agent -> Html Msg
renderAgent agent =
    let
        call =
            case agent.callingOut of
                Nothing ->
                    []

                Just calling ->
                    case calling.signal of
                        FeedMe ->
                            [ renderEmoji "😮" origin
                                |> Svg.scaleAbout origin 2
                            ]

                        GoAway ->
                            [ renderEmoji "😣" origin ]

                        Eating ->
                            [ renderEmoji "🍖" origin ]

                        Bored ->
                            [ renderEmoji "😑" origin
                                |> Svg.scaleAbout origin 0.7
                            ]

        bothHands =
            Point2d.fromMeters { x = 0, y = 6 }

        held =
            case agent.holding of
                EmptyHanded ->
                    []

                BothHands p ->
                    [ renderPortable p bothHands ]
    in
    g [ id <| "agent " ++ agent.name ]
        ([ Svg.circle2d [ Svg.Attributes.fill "var(--color-fg)" ] (Circle2d.withRadius (Length.meters 3) origin)
         , Svg.lineSegment2d []
            (LineSegment2d.fromEndpoints
                ( origin
                , origin
                    |> Point2d.translateBy
                        (Vector2d.withLength (Length.meters 1)
                            agent.physics.facing
                        )
                )
            )
         , agentVelocityArrow agent
         , renderName agent
            |> Svg.scaleAbout origin 0.6
         , renderHealthBar agent.hp
         , g [ svgClass.held ] held
         ]
            |> append call
        )
        |> Svg.translateBy (Vector2d.from Point2d.origin agent.physics.position)


renderPortable : Portable -> Point2d.Point2d Meters YDownCoords -> Svg Msg
renderPortable p pOffset =
    Svg.scaleAbout pOffset 0.6 <|
        case p of
            Edible _ ->
                renderEmoji "🍽" pOffset

            Extinguisher _ ->
                renderEmoji "🚒" pOffset


append : List a -> List a -> List a
append =
    \b a -> List.append a b


renderAgentInfo : Posix -> Agent -> Html Msg
renderAgentInfo currentTime agent =
    div []
        [ h3
            [ style "margin-bottom" "0.1em" ]
            [ text agent.name ]
        , agentStats agent
        , div indentWithLine
            (getActions agent
                |> List.map (renderAction agent currentTime)
            )
        ]


agentStats : Agent -> Html Msg
agentStats agent =
    let
        stats : List ( String, String )
        stats =
            [ ( "hunger", (agent.hunger |> rangeCurrentValue |> Round.round 1) ++ "%" )
            , ( "hp", hpPercentage agent.hp )
            , ( "holding", carryingAsString agent.holding )
            , ( "current action", agent.currentAction )
            ]

        cell elem =
            text >> List.singleton >> elem [ style "padding-right" "1em" ]
    in
    table [ style "font-family" "monospace" ]
        [ tr []
            (stats |> List.map (first >> cell th))
        , tr []
            (stats |> List.map (second >> cell td))
        ]


hpPercentage : Hitpoints -> String
hpPercentage (Hitpoints current max) =
    let
        pc : Float
        pc =
            current / max * 100
    in
    Round.round 1 pc ++ "%"


carryingAsString : Holding -> String
carryingAsString held =
    case held of
        EmptyHanded ->
            "nothing"

        BothHands p ->
            "both hands: " ++ portableAsString p


portableAsString : Portable -> String
portableAsString p =
    case p of
        Extinguisher ext ->
            "extinguisher @ " ++ Round.round 0 (ext.remaining / ext.capacity * 100) ++ "%"

        Edible food ->
            "food @ " ++ Round.round 0 (normaliseRange food.joules * 100) ++ "%"


indentWithLine : List (Attribute msg)
indentWithLine =
    [ style "margin-left" "0.2em"
    , style "padding-left" "1em"
    , style "border-left" "1px solid grey"
    ]


renderAction : Agent -> Posix -> Action -> Html Msg
renderAction agent currentTime action =
    let
        isExpanded =
            Dict.get action.name agent.visibleActions
                |> Maybe.withDefault False

        considerations =
            if isExpanded then
                [ div
                    [ style "display" "flex"
                    ]
                    (List.map (renderConsideration agent action currentTime) action.considerations)
                ]

            else
                []

        containerStyle =
            if isExpanded then
                [ style "background-color" "var(--color-bg--almost)"
                , style "padding" "0.6em"
                ]

            else
                [ style "padding" "0.6em" ]

        utility =
            computeUtility agent currentTime action
    in
    div containerStyle
        (List.append
            [ h4
                [ onClick <| ToggleConditionsVisibility agent.name action.name
                , style "cursor" "pointer"
                , style "margin" "0"
                , style "opacity" (utility ^ (1 / 1.5) + 0.3 |> String.fromFloat)
                ]
                [ text "("
                , prettyFloatHtml 2 utility
                , text ") "
                , text action.name
                ]
            ]
            considerations
        )


renderConsideration : Agent -> Action -> Posix -> Consideration -> Html Msg
renderConsideration agent action currentTime con =
    let
        considerationValue =
            computeConsideration agent currentTime Nothing action con

        rawValue =
            getConsiderationRawValue agent currentTime action con

        isExpanded =
            Dict.get con.name action.visibleConsiderations
                |> Maybe.withDefault False

        details =
            if isExpanded then
                [ ul []
                    [ li []
                        [ codeText <| "Input: " ++ renderCI currentTime agent action con.input
                        ]
                    , li []
                        [ codeText <| "Output:    " ++ Round.round 4 considerationValue
                        ]
                    , li []
                        [ codeText <| "Raw Value: " ++ Round.round 4 rawValue
                        ]
                    , li []
                        [ codeText <| "UF: " ++ renderUF con.function
                        ]
                    , li []
                        [ codeText <| "Min: " ++ (Round.round 4 <| con.inputMin) ++ ", Max: " ++ (Round.round 2 <| con.inputMax)
                        ]
                    , li []
                        [ codeText <| "Weighting: " ++ (Round.round 4 <| con.weighting)
                        ]
                    , li []
                        [ codeText <| "Offset:    " ++ (Round.round 4 <| con.offset)
                        ]
                    ]
                ]

            else
                []

        main =
            [ h5
                [ onClick <| ToggleConditionDetailsVisibility agent.name action.name con.name
                , style "cursor" "pointer"
                , style "margin" "0.5em 0"
                ]
                [ text "("
                , code [] [ text <| Round.round 2 considerationValue ]
                , text ")  "
                , text con.name
                ]
            , renderConsiderationChart agent currentTime action con
            ]
    in
    div [ style "flex-basis" "20em" ]
        (List.append main details)


renderConsiderationChart : Agent -> Posix -> Action -> Consideration -> Html Msg
renderConsiderationChart agent currentTime action con =
    let
        sampleCount : Int
        sampleCount =
            64

        chartBB : BoundingBox2d Meters YDownCoords
        chartBB =
            BoundingBox2d.fromExtrema
                { minX = Length.meters -20
                , maxX = Length.meters 120
                , minY = Length.meters -20
                , maxY = Length.meters 120
                }

        chartYMin : Float
        chartYMin =
            min 0 (con.weighting + con.offset)
                |> min con.offset

        chartYMax : Float
        chartYMax =
            max 0 (con.weighting + con.offset)
                |> max con.offset

        samplePoints =
            List.range 0 sampleCount
                |> List.map toFloat
                |> List.map
                    (\nthSample ->
                        let
                            x =
                                linearTransform 0 100 0 (toFloat sampleCount) nthSample

                            forcedValue =
                                nthSample
                                    |> linearTransform
                                        con.inputMin
                                        con.inputMax
                                        0
                                        (toFloat sampleCount)

                            y =
                                computeConsideration
                                    agent
                                    currentTime
                                    (Just forcedValue)
                                    action
                                    con
                                    |> linearTransform 0 100 chartYMin chartYMax
                                    |> (-) 100
                        in
                        ( x, y )
                    )

        samplePointsSvg : Svg Msg
        samplePointsSvg =
            samplePoints
                |> List.map
                    (\( x, y ) ->
                        Svg.circle
                            [ cx <| String.fromFloat x, cy <| String.fromFloat y, r "2", fill "var(--color-fg)" ]
                            []
                    )
                |> g []

        borders : Svg Msg
        borders =
            g [ svgClass.borders ]
                [ Svg.line [ x1 "0", x2 "100", y1 "100", y2 "100", stroke "var(--color-fg)" ] []
                , Svg.line [ x1 "0", x2 "0", y1 "0", y2 "100", stroke "var(--color-fg)" ] []
                ]

        xValRaw : Float
        xValRaw =
            getConsiderationRawValue agent currentTime action con
                |> clampTo con

        xValForChart : Float
        xValForChart =
            xValRaw
                |> linearTransform 0 100 con.inputMin con.inputMax

        yVal : Float
        yVal =
            computeConsideration agent currentTime (Just xValRaw) action con

        currentValue : Svg Msg
        currentValue =
            g [ svgClass.currentValue ]
                [ Svg.circle
                    [ cx <| String.fromFloat <| xValForChart
                    , cy <| String.fromFloat <| 100 - linearTransform 0 100 chartYMin chartYMax yVal
                    , r "5"
                    , fill "red"
                    ]
                    []
                ]

        ticks : Svg Msg
        ticks =
            g [ svgClass.ticks ]
                [ tickHelper -5 100 "end" chartYMin
                , tickHelper -5 0 "end" chartYMax
                , tickHelper 0 115 "start" con.inputMin
                , tickHelper 100 115 "end" con.inputMax
                ]
    in
    render2dResponsive
        chartBB
    <|
        g
            [ svgClass.considerationChart ]
            [ borders
            , samplePointsSvg
            , ticks
            , currentValue
            ]


tickHelper : Int -> Int -> String -> Float -> Svg Msg
tickHelper xVal yVal textAlign val =
    text_
        [ xVal |> String.fromInt |> x
        , yVal |> String.fromInt |> y
        , textAnchor textAlign
        , fontSize "0.8em"
        ]
        [ val |> String.fromFloat |> text ]


{-| Represent a "Utility Function" as a string.
-}
renderUF : InputFunction -> String
renderUF f =
    case f of
        Linear { slope, offset } ->
            "Linear (slope = " ++ String.fromFloat slope ++ ", offset = " ++ String.fromFloat offset ++ ")"

        Exponential { exponent } ->
            "Exponential (exponent = " ++ String.fromFloat exponent ++ ")"

        Sigmoid { bend, center } ->
            "Sigmoid (bend = " ++ String.fromFloat bend ++ ", center = " ++ String.fromFloat center ++ ")"

        Normal { tightness, center, squareness } ->
            let
                values =
                    [ "tightness = " ++ String.fromFloat tightness
                    , "center = " ++ String.fromFloat center
                    , "squareness = " ++ String.fromFloat squareness
                    ]
            in
            "Normal (" ++ String.join ", " values ++ ")"

        Asymmetric { centerA, bendA, offsetA, squarenessA, centerB, bendB, offsetB, squarenessB } ->
            let
                values =
                    [ "centerA=" ++ Round.round 1 centerA
                    , "bendA=" ++ Round.round 1 bendA
                    , "offsetA=" ++ Round.round 1 offsetA
                    , "squarenessA=" ++ Round.round 1 squarenessA
                    , "centerB=" ++ Round.round 1 centerB
                    , "bendB=" ++ Round.round 1 bendB
                    , "offsetB=" ++ Round.round 1 offsetB
                    , "squarenessB=" ++ Round.round 1 squarenessB
                    ]
            in
            "Asymmetric (" ++ String.join ", " values ++ ")"


renderCI : Posix -> Agent -> Action -> ConsiderationInput -> String
renderCI currentTime agent action ci =
    case ci of
        Hunger ->
            "Hunger"

        MetersToTargetPoint p ->
            "Distance to point " ++ prettyPoint2d p

        Constant p ->
            "Constant " ++ Round.round 2 p

        CurrentSpeedInMetersPerSecond ->
            "Current Speed "
                ++ (agent.physics.velocity
                        |> Vector2d.length
                        |> Length.inMeters
                        |> Round.round 2
                   )

        TimeSinceLastShoutedFeedMe ->
            let
                val =
                    case Dict.get "CallOut FeedMe" agent.topActionLastStartTimes of
                        Nothing ->
                            "Never"

                        Just t ->
                            differenceInMillis currentTime t |> String.fromInt
            in
            "Time since last shouted \"Feed Me!\" "
                ++ val

        CurrentlyCallingOut ->
            "Currently calling out "
                ++ (String.fromInt <|
                        case agent.callingOut of
                            Nothing ->
                                0

                            Just _ ->
                                1
                   )

        IsCurrentAction ->
            "Is action the current one? " ++ (action.name == agent.currentAction |> boolString)

        Held carryCheck ->
            "Am I carrying "
                ++ describeCarryCheck carryCheck
                ++ "? "
                ++ (isHolding carryCheck agent.holding |> boolString)

        IAmBeggingForFood ->
            "Am I begging for food? " ++ (agent.beggingForFood |> boolString)

        FoodWasGivenAway foodID ->
            "Did I give this food away already? (id#" ++ String.fromInt foodID ++ ")"


describeCarryCheck : CarryableCheck -> String
describeCarryCheck carryableCheck =
    case carryableCheck of
        IsAnything ->
            "anything"

        IsAFireExtinguisher ->
            "a fire extinguisher"

        IsFood ->
            "food"


prettyPoint2d : Point2d.Point2d Meters YDownCoords -> String
prettyPoint2d p =
    "("
        ++ (Round.round 1 <| Length.inMeters <| xCoordinate p)
        ++ ", "
        ++ (Round.round 1 <| Length.inMeters <| yCoordinate p)
        ++ ")"


prettyFloatHtml : Int -> Float -> Html Msg
prettyFloatHtml dp n =
    Round.round dp n
        |> codeText


codeText : String -> Html Msg
codeText s =
    code [ style "white-space" "pre-wrap" ] [ text s ]


renderEmoji : String -> Point2d.Point2d Meters YDownCoords -> Html Msg
renderEmoji emoji point =
    Svg.text_
        [ Svg.Attributes.textAnchor "middle"
        , Svg.Attributes.alignmentBaseline "middle"
        ]
        [ Svg.text emoji ]
        |> Svg.translateBy (Vector2d.from Point2d.origin point)


renderName : Agent -> Html Msg
renderName agent =
    Svg.text_
        [ Svg.Attributes.textAnchor "middle"
        , Svg.Attributes.alignmentBaseline "baseline"
        , layer Names
        , y "-10"
        ]
        [ Svg.text agent.name ]


layer : Layer -> Svg.Attribute Msg
layer l =
    case l of
        Names ->
            svgClass.layer.names

        StatusBars ->
            svgClass.layer.statusBars


renderFood : Food -> Svg Msg
renderFood food =
    renderEmoji "🍽" food.physics.position


{-| todo: replace 🚒 with the fire extinguisher symbol in Unicode 11
-}
renderExtinguisher : FireExtinguisher -> Svg Msg
renderExtinguisher extinguisher =
    renderEmoji "🚒" extinguisher.physics.position


renderRetardantCloud : Retardant -> Svg Msg
renderRetardantCloud retardant =
    renderEmoji "☁" retardant.physics.position


renderFire : Fire -> Svg Msg
renderFire fire =
    let
        gradient =
            Svg.radialGradient
                [ id "fireRednessGradient"
                , x1 "0"
                , x2 "100"
                , y1 "0"
                , y2 "100"
                ]
                [ stop
                    [ offset "0%"
                    , stopColor "#ff0000"
                    , stopOpacity "0.3"
                    ]
                    []
                , stop
                    [ offset "100%"
                    , stopColor "#ff0000"
                    , stopOpacity "0"
                    ]
                    []
                ]

        redness =
            Svg.circle
                [ cx "0"
                , cy "0"
                , r "50px"
                , fill "url(#fireRednessGradient)"
                ]
                []

        healthFactor =
            hpAsFloat fire.hp
    in
    g [ id <| "fire_" ++ String.fromInt fire.id ]
        [ renderEmoji "🔥" origin
        , gradient
        , redness
            |> Svg.scaleAbout origin healthFactor
        , renderHealthBar fire.hp
        ]
        |> Svg.translateBy (Vector2d.from origin fire.physics.position)


renderGrowable : Growable -> Svg Msg
renderGrowable growable =
    let
        emoji =
            case growable.state of
                FertileSoil _ ->
                    "🕳"

                GrowingPlant _ ->
                    "🌱"

                GrownPlant _ ->
                    "🌾"

                DeadPlant _ ->
                    "🍂"

        hp : Hitpoints
        hp =
            case growable.state of
                FertileSoil _ ->
                    Hitpoints 1 1

                GrowingPlant stats ->
                    stats.hp

                GrownPlant stats ->
                    stats.hp

                DeadPlant stats ->
                    stats.hp

        progress : Range
        progress =
            case growable.state of
                FertileSoil stats ->
                    stats.plantedProgress

                GrowingPlant stats ->
                    stats.growth

                GrownPlant _ ->
                    Range { min = 0, max = 1, value = 1 }

                DeadPlant _ ->
                    Range { min = 0, max = 1, value = 1 }
    in
    g [ id <| "growable_" ++ String.fromInt growable.id ]
        [ renderEmoji emoji origin
        , renderHealthBar hp
        , renderProgressBar progress
        ]
        |> Svg.translateBy (Vector2d.from origin growable.physics.position)


renderHealthBar : Hitpoints -> Svg Msg
renderHealthBar hp =
    let
        pixelWidth : Float
        pixelWidth =
            20

        pixelHeight : Float
        pixelHeight =
            5

        normalisedHP : Float
        normalisedHP =
            hpAsFloat hp

        yOffset : Float
        yOffset =
            5
    in
    g [ svgClass.healthBar ]
        (if normalisedHP == 1 then
            []

         else
            [ rect
                [ pixelWidth / -2 |> String.fromFloat |> x
                , pixelHeight + yOffset |> String.fromFloat |> y
                , pixelWidth |> String.fromFloat |> width
                , pixelHeight |> String.fromFloat |> height
                , fill "red"
                ]
                []
            , rect
                [ pixelWidth / -2 |> String.fromFloat |> x
                , pixelHeight + yOffset |> String.fromFloat |> y
                , pixelWidth * normalisedHP |> String.fromFloat |> width
                , pixelHeight |> String.fromFloat |> height
                , fill "green"
                ]
                []
            ]
        )


renderProgressBar : Range -> Svg Msg
renderProgressBar range =
    let
        pixelWidth : Float
        pixelWidth =
            20

        pixelHeight : Float
        pixelHeight =
            2

        normalised : Float
        normalised =
            normaliseRange range

        yOffset : Float
        yOffset =
            10
    in
    g [ svgClass.progressBar ]
        (if normalised == 1 || normalised == 0 then
            []

         else
            [ rect
                [ pixelWidth / -2 |> String.fromFloat |> x
                , yOffset |> String.fromFloat |> y
                , pixelWidth * normaliseRange range |> String.fromFloat |> width
                , pixelHeight |> String.fromFloat |> height
                , fill "blue"
                ]
                []
            ]
        )


origin : Point2d.Point2d Meters YDownCoords
origin =
    Point2d.origin


viewAboutPage : String -> Html Msg
viewAboutPage gitHash =
    div []
        [ p []
            [ text "\"Tulars\", an exploration of "
            , a [ href "http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf" ]
                [ text "Utility Theory" ]
            , text " applied to entities in game design."
            ]
        , p []
            [ text "Source available at "
            , a [ href "https://github.com/r-k-b/tulars" ] [ text "github.com" ]
            , text ", under the GNU Affero General Public Licence 3.0. "
            , text "This code built from "
            , a [ href <| "https://github.com/r-k-b/tulars/commit/" ++ gitHash ]
                [ text <| "commit "
                , code [] [ text (gitHash |> String.left 8) ]
                , text "."
                ]
            ]
        , p []
            [ text "Created by "
            , a [ href "https://github.com/r-k-b" ] [ text "Robert K. Bell" ]
            ]
        ]


viewVariantsPage : Html Msg
viewVariantsPage =
    div []
        [ ul []
            [ li [] [ a [ href "/index.html" ] [ text "Default" ] ]
            , li [] [ a [ href "/debug.html" ] [ text "Elm Debugger active" ] ]
            , li [] [ a [ href "/optimized.html" ] [ text "Optimized JS" ] ]
            ]
        ]


orNoAttribute : Maybe (Html.Attribute msg) -> Html.Attribute msg
orNoAttribute maybeAttr =
    maybeAttr |> Maybe.withDefault (HA.attribute "data-empty" "")


labelToString : Bool -> MenuItemLabel -> String
labelToString isPaused label =
    case label of
        TextLabel string ->
            string

        PauseLabel ->
            if isPaused then
                "Unpause"

            else
                "Pause"

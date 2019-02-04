module View exposing (view)

import BoundingBox2d as BoundingBox2d exposing (BoundingBox2d)
import Browser exposing (Document)
import Circle2d as Circle2d
import DefaultData exposing (hpMax)
import Dict
import Direction2d as Direction2d
import Frame2d as Frame2d
import Geometry.Svg as Svg
import Html exposing (Attribute, Html, code, div, h2, h3, h4, h5, li, table, td, text, th, tr, ul)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import LineSegment2d
import List.Extra
import Point2d as Point2d exposing (xCoordinate, yCoordinate)
import Round
import Svg exposing (Svg, g, stop, text_)
import Svg.Attributes exposing (cx, cy, dx, fill, fontSize, id, offset, r, stopColor, stopOpacity, stroke, textAnchor, viewBox, x, x1, x2, y, y1, y2)
import Time exposing (Posix)
import Tuple exposing (first, second)
import Types
    exposing
        ( Action
        , Agent
        , Consideration
        , ConsiderationInput(..)
        , Fire
        , FireExtinguisher
        , Food
        , Hitpoints(..)
        , Holding(..)
        , InputFunction(..)
        , Model
        , Msg(..)
        , Portable(..)
        , Retardant
        , Signal(..)
        )
import UtilityFunctions exposing (boolString, clampTo, computeConsideration, computeUtility, differenceInMillis, getActions, getConsiderationRawValue, isHolding, linearTransform, portableIsExtinguisher, portableIsFood)
import Vector2d as Vector2d exposing (scaleBy)


svgClass =
    Svg.Attributes.class


view : Model -> Document Msg
view model =
    let
        body =
            div pageGridContainerStyle
                [ div
                    (List.concat [ mapGridItemStyle, [ svgClass "zoom-svg" ] ])
                    [ mainMap model
                    ]
                , div
                    agentInfoGridItemStyle
                    [ renderTopButtons model
                    , agentsInfo model.time model.agents
                    ]
                ]
    in
    { title = "Tulars", body = [ body ] }


renderTopButtons : Model -> Html Msg
renderTopButtons model =
    div [ style "position" "sticky", style "top" "0" ]
        [ Html.button [ Html.Events.onClick TogglePaused ]
            [ text
                (if model.paused then
                    "Unpause"

                 else
                    "Pause"
                )
            ]
        , Html.button [ Html.Events.onClick Reset ]
            [ text "Reset" ]
        ]


bb : BoundingBox2d
bb =
    BoundingBox2d.fromExtrema
        { minX = -300
        , maxX = 300
        , minY = -300
        , maxY = 300
        }


render2dResponsive : BoundingBox2d -> Svg msg -> Html msg
render2dResponsive boundingBox svgMsg =
    let
        { minX, maxY } =
            BoundingBox2d.extrema boundingBox

        topLeftFrame =
            Frame2d.atPoint (Point2d.fromCoordinates ( minX, maxY ))

        ( bbWidth, bbHeight ) =
            BoundingBox2d.dimensions boundingBox

        coords =
            [ 0
            , -bbHeight
            , bbWidth
            , bbHeight
            ]
                |> List.map String.fromFloat
                |> String.join " "
    in
    Svg.svg
        [ Svg.Attributes.width (String.fromFloat bbWidth)
        , Svg.Attributes.height (String.fromFloat bbHeight)
        , viewBox coords
        ]
        [ Svg.relativeTo topLeftFrame svgMsg ]


mainMap : Model -> Html.Html Msg
mainMap model =
    render2dResponsive bb
        (g [ id "mainMap" ]
            [ borderIndicator 200
            , borderIndicator 300
            , g [ id "agents" ]
                (List.map renderAgent model.agents)
            , g [ id "foods" ]
                (List.map renderFood model.foods)
            , g [ id "fires" ]
                (List.map renderFire model.fires)
            , g [ id "extinguishers" ]
                (List.map renderExtinguisher model.extinguishers)
            , g [ id "retardantProjectiles" ]
                (List.map renderRetardantCloud model.retardants)
            ]
        )


borderIndicator : Float -> Svg Msg
borderIndicator radius =
    Svg.circle2d
        [ Svg.Attributes.fillOpacity "0"
        , Svg.Attributes.stroke "grey"
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


pageGridContainerStyle : List (Html.Attribute msg)
pageGridContainerStyle =
    [ style "display" "grid"
    , style "width" "calc(100vw)"
    , style "max-width" "calc(100vw)"
    , style "height" "calc(100vh)"
    , style "max-height" "calc(100vh)"
    , style "overflow" "hidden"
    , style "grid-template-columns" "repeat(2, 1fr)"
    , style "grid-template-rows" "1fr"
    ]


mapGridItemStyle : List (Html.Attribute msg)
mapGridItemStyle =
    [ style "grid-column" "1 / 2"
    , style "grid-row" "1 / 2"
    , style "overflow" "hidden"
    , style "margin" "0.5em"
    ]


agentInfoGridItemStyle : List (Html.Attribute msg)
agentInfoGridItemStyle =
    [ style "grid-column" "2 / 4"
    , style "grid-row" "1 / 3"
    , style "overflow" "auto"
    ]


inPx : Float -> String
inPx number =
    String.fromFloat number ++ "px"


agentPoint =
    { radius = 3
    , attributes =
        [ Svg.Attributes.stroke "blue"
        , Svg.Attributes.fill "orange"
        ]
    }


facingArrow =
    { length = 20
    , tipLength = 5
    , tipWidth = 5
    , stemAttributes = []
    , tipAttributes =
        [ Svg.Attributes.fill "orange" ]
    , groupAttributes =
        [ Svg.Attributes.stroke "blue" ]
    }


agentVelocityArrow : Agent -> Svg msg
agentVelocityArrow agent =
    let
        exaggerated : Vector2d.Vector2d
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
            ( agent.physics.position
            , agent.physics.position |> Point2d.translateBy exaggerated
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
                            [ renderEmoji "😮" agent.physics.position
                                |> Svg.scaleAbout agent.physics.position 2
                            ]

                        GoAway ->
                            [ renderEmoji "😣" agent.physics.position ]

                        Eating ->
                            [ renderEmoji "🍖" agent.physics.position ]

                        Bored ->
                            [ renderEmoji "😑" agent.physics.position
                                |> Svg.scaleAbout agent.physics.position 0.7
                            ]

        bothHands =
            Point2d.fromCoordinates ( 0, 12 )

        held =
            case agent.holding of
                EmptyHanded ->
                    []

                BothHands p ->
                    [ renderPortable p bothHands ]
    in
    g [ id <| "agent " ++ agent.name ]
        ([ Svg.circle2d [] (Circle2d.withRadius 3 agent.physics.position)
         , Svg.lineSegment2d [] (LineSegment2d.fromEndpoints ( agent.physics.position, agent.physics.position |> Point2d.translateBy (Direction2d.toVector agent.physics.facing) ))
         , agentVelocityArrow agent
         , renderName agent
            |> Svg.scaleAbout agent.physics.position 0.7
         , g [] held
            |> Svg.translateBy (Vector2d.from Point2d.origin agent.physics.position)
         ]
            |> append call
        )


renderPortable : Portable -> Point2d.Point2d -> Svg Msg
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
            [ ( "hunger", Round.round 1 agent.hunger ++ "%" )
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
            "food @ " ++ Round.round 0 (food.joules / food.freshJoules * 100) ++ "%"


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
            -- Don't commit this
            if not isExpanded then
                [ div
                    [ style "display" "flex"
                    ]
                    (List.map (renderConsideration agent action currentTime) action.considerations)
                ]

            else
                []

        containerStyle =
            if isExpanded then
                [ style "background-color" "#00000011"
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
        chartBB : BoundingBox2d
        chartBB =
            BoundingBox2d.fromExtrema
                { minX = -20
                , maxX = 120
                , minY = -20
                , maxY = 120
                }

        samplePoints =
            List.range 0 sampleCount
                |> List.map toFloat
                |> List.map
                    (\nthSample ->
                        ( linearTransform 0 100 0 (toFloat sampleCount) nthSample
                        , let
                            forcedValue =
                                linearTransform (min con.inputMin con.inputMax) (max con.inputMin con.inputMax) 0 (toFloat sampleCount) nthSample
                          in
                          computeConsideration
                            agent
                            currentTime
                            (Just forcedValue)
                            action
                            con
                            |> linearTransform 0 100 chartYMin chartYMax
                            |> (\y -> 100 - y)
                        )
                    )

        samplePointsSvg : Svg Msg
        samplePointsSvg =
            samplePoints
                |> List.map
                    (\( x, y ) ->
                        Svg.circle
                            [ cx <| String.fromFloat x, cy <| String.fromFloat y, r "2", fill "grey" ]
                            []
                    )
                |> g []

        chartYMin : Float
        chartYMin =
            min
                (min 0 (con.weighting + con.offset))
                (con.weighting + con.offset)

        chartYMax : Float
        chartYMax =
            max
                (min 0 (con.weighting + con.offset))
                (con.weighting + con.offset)

        borders : Svg Msg
        borders =
            g [ svgClass "borders" ]
                [ Svg.line [ x1 "0", x2 "100", y1 "100", y2 "100", stroke "black" ] []
                , Svg.line [ x1 "0", x2 "0", y1 "0", y2 "100", stroke "black" ] []
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

        sampleCount : Int
        sampleCount =
            64

        currentValue : Svg Msg
        currentValue =
            g [ svgClass "current-value" ]
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
            g [ svgClass "ticks" ]
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
            [ svgClass "consideration-chart" ]
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
        Linear m b ->
            "Linear (slope = " ++ String.fromFloat m ++ ", offset = " ++ String.fromFloat b ++ ")"

        Exponential exponent ->
            "Exponential (exponent = " ++ String.fromFloat exponent ++ ")"

        Sigmoid bend center ->
            "Sigmoid (bend = " ++ String.fromFloat bend ++ ", center = " ++ String.fromFloat center ++ ")"

        Normal tightness center squareness ->
            let
                vals =
                    [ "tightness = " ++ String.fromFloat tightness
                    , "center = " ++ String.fromFloat center
                    , "squareness = " ++ String.fromFloat squareness
                    ]
            in
            "Normal (" ++ String.join ", " vals ++ ")"

        Asymmetric centerA bendA offsetA squarenessA centerB bendB offsetB squarenessB ->
            let
                vals =
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
            "Asymmetric (" ++ String.join ", " vals ++ ")"


renderCI : Posix -> Agent -> Action -> ConsiderationInput -> String
renderCI currentTime agent action ci =
    case ci of
        Hunger ->
            "Hunger"

        DistanceToTargetPoint p ->
            "Distance to point " ++ prettyPoint2d p

        Constant p ->
            "Constant " ++ Round.round 2 p

        CurrentSpeed ->
            "Current Speed "
                ++ (agent.physics.velocity
                        |> Vector2d.length
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

        IsCarryingExtinguisher ->
            "Am I carrying a fire extinguisher? " ++ (isHolding portableIsExtinguisher agent.holding |> boolString)

        IsCarryingFood ->
            "Am I carrying some food? " ++ (isHolding portableIsFood agent.holding |> boolString)

        IAmBeggingForFood ->
            "Am I begging for food? " ++ (agent.beggingForFood |> boolString)

        FoodWasGivenAway foodID ->
            "Did I give this food away already? (id#" ++ String.fromInt foodID ++ ")"


prettyPoint2d : Point2d.Point2d -> String
prettyPoint2d p =
    "(" ++ (Round.round 1 <| xCoordinate p) ++ ", " ++ (Round.round 1 <| yCoordinate p) ++ ")"


prettyFloatHtml : Int -> Float -> Html Msg
prettyFloatHtml dp n =
    Round.round dp n
        |> codeText


codeText : String -> Html Msg
codeText s =
    code [ style "white-space" "pre-wrap" ] [ text s ]


renderEmoji : String -> Point2d.Point2d -> Html Msg
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
        , Svg.Attributes.alignmentBaseline "hanging"
        ]
        [ Svg.text agent.name ]
        |> Svg.translateBy (Vector2d.from Point2d.origin agent.physics.position)


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
                [ cx (fire.physics.position |> xCoordinate |> inPx)
                , cy (fire.physics.position |> yCoordinate |> inPx)
                , r "50px"
                , fill "url(#fireRednessGradient)"
                ]
                []

        healthFactor =
            fire.hp / hpMax.fire
    in
    g [ id <| "fire_" ++ String.fromInt fire.id ]
        [ renderEmoji "🔥" fire.physics.position
        , gradient
        , redness
        ]
        |> Svg.scaleAbout fire.physics.position healthFactor

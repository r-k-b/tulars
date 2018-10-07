module View exposing (view)

import DefaultData exposing (hpMax)
import Dict
import LineSegment2d
import List.Extra
import Html exposing (Html, code, div, h2, h3, h4, h5, li, table, td, text, th, tr, ul)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import BoundingBox2d as BoundingBox2d exposing (BoundingBox2d)
import Direction2d as Direction2d
import Circle2d as Circle2d
import Frame2d as Frame2d
import Point2d as Point2d exposing (xCoordinate, yCoordinate)
import Time exposing (Posix)
import Vector2d as Vector2d exposing (scaleBy)
import Round
import Svg exposing (Svg, g, stop)
import Svg.Attributes as Attributes
    exposing
        ( cx
        , cy
        , fill
        , id
        , offset
        , r
        , stopColor
        , stopOpacity
        , stroke
        , viewBox
        , x1
        , x2
        , y1
        , y2
        )
import Geometry.Svg as Svg
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
import UtilityFunctions
    exposing
        ( clampTo
        , computeConsideration
        , computeUtility
        , getActions
        , getConsiderationRawValue
        , isHolding
        , portableIsExtinguisher
        , portableIsFood
        )


view : Model -> Html Msg
view model =
    div [ pageGridContainerStyle ]
        [ div
            [ mapGridItemStyle, class "zoom-svg" ]
            [ mainMap model
            ]
        , div
            [ agentInfoGridItemStyle ]
            [ agentsInfo model.time model.agents
            ]
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
                |> Frame2d.reverseY

        ( bbWidth, bbHeight ) =
            BoundingBox2d.dimensions boundingBox

        coords : List Float
        coords =
            [ 0
            , 0
            , bbWidth
            , bbHeight
            ]
                |> List.map String.fromFloat
                |> String.join " "
    in
        Svg.svg
            [ Attributes.width (String.fromFloat bbWidth)
            , Attributes.height (String.fromFloat bbHeight)
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
    Svg.circle
        [ Attributes.fillOpacity "0"
        , Attributes.stroke "grey"
        , Attributes.strokeWidth "1"
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


tupleOf : a -> b -> ( a, b )
tupleOf =
    \a b -> ( a, b )


pageGridContainerStyle : Html.Attribute msg
pageGridContainerStyle =
    style
        [ tupleOf "display" "grid"
        , tupleOf "width" "calc(100vw)"
        , tupleOf "max-width" "calc(100vw)"
        , tupleOf "height" "calc(100vh)"
        , tupleOf "max-height" "calc(100vh)"
        , tupleOf "overflow" "hidden"
        , tupleOf "grid-template-columns" "repeat(3, 1fr)"
        , tupleOf "grid-template-rows" "2fr 1fr"
        ]


mapGridItemStyle : Html.Attribute msg
mapGridItemStyle =
    style
        [ tupleOf "grid-column" "1 / 2"
        , tupleOf "grid-row" "1 / 2"
        , tupleOf "overflow" "hidden"
        , tupleOf "margin" "0.5em"
        ]


agentInfoGridItemStyle : Html.Attribute msg
agentInfoGridItemStyle =
    style
        [ tupleOf "grid-column" "2 / 4"
        , tupleOf "grid-row" "1 / 3"
        , tupleOf "overflow" "auto"
        ]


inPx : Float -> String
inPx number =
    String.fromFloat number ++ "px"


agentPoint =
    { radius = 3
    , attributes =
        [ Attributes.stroke "blue"
        , Attributes.fill "orange"
        ]
    }


facingArrow =
    { length = 20
    , tipLength = 5
    , tipWidth = 5
    , stemAttributes = []
    , tipAttributes =
        [ Attributes.fill "orange" ]
    , groupAttributes =
        [ Attributes.stroke "blue" ]
    }


agentVelocityArrow : Agent -> Svg msg
agentVelocityArrow agent =
    let
        exaggerated =
            scaleBy 2 agent.physics.velocity

        exaggeratedLength =
            Vector2d.length exaggerated
    in
        --    todo: restore the "arrow" representation
        Svg.lineSegment2d
            [ Attributes.stroke "blue"
            , Attributes.strokeWidth "1"
            , Attributes.strokeDasharray "1 2"
            ]
            (LineSegment2d.fromEndpoints
                agent.physics.position
                exaggerated
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
            ([ Svg.circle2d [] agent.physics.position
             , Svg.lineSegment2d facingArrow agent.physics.position agent.physics.facing
             , agentVelocityArrow agent
             , renderName agent
                |> Svg.scaleAbout agent.physics.position 0.7
             , g [] held
                |> Svg.translateBy (Vector2d.from Point2d.origin agent.physics.position)
                |> Svg.rotateAround agent.physics.position (Direction2d.angleFrom agent.physics.facing - pi / 2)
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
            [ (\( a, b ) -> style a b) ( "margin-bottom", "0.1em" ) ]
            [ text agent.name ]
        , agentStats agent
        , div [ style indentWithLine ]
            (getActions agent
                |> List.map (renderAction agent currentTime)
            )
        ]


agentStats : Agent -> Html Msg
agentStats agent =
    let
        stats : List ( String, String )
        stats =
            [ ( "hunger", (Round.round 1 agent.hunger ++ "%") )
            , ( "hp", hpPercentage agent.hp )
            , ( "holding", carryingAsString agent.holding )
            , ( "current action", agent.currentAction )
            ]

        cell elem =
            text >> List.singleton >> elem [ (\( a, b ) -> style a b) ( "padding-right", "1em" ) ]
    in
        table [ (\( a, b ) -> style a b) ( "font-family", "monospace" ) ]
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
            "extinguisher @ " ++ prettyFloat 0 (ext.remaining / ext.capacity * 100) ++ "%"

        Edible food ->
            "food @ " ++ prettyFloat 0 (food.joules / food.freshJoules * 100) ++ "%"


indentWithLine : List ( String, String )
indentWithLine =
    [ ( "margin-left", "0.2em" )
    , ( "padding-left", "1em" )
    , ( "border-left", "1px solid grey" )
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
                    [ (\( a, b ) -> style a b) ( "display", "flex" )
                    ]
                    (List.map (renderConsideration agent action currentTime) action.considerations)
                ]
            else
                []

        containerStyle =
            if isExpanded then
                style
                    [ ( "background-color", "#00000011" )
                    , ( "padding", "0.6em" )
                    ]
            else
                style [ ( "padding", "0.6em" ) ]

        utility =
            computeUtility agent currentTime action
    in
        div [ containerStyle ]
            (List.append
                [ h4
                    [ onClick <| ToggleConditionsVisibility agent.name action.name
                    , (\( a, b ) -> style a b) ( "cursor", "pointer" )
                    , (\( a, b ) -> style a b) ( "margin", "0" )
                    , (\( a, b ) -> style a b) ( "opacity", (utility ^ (1 / 1.5) + 0.3 |> String.fromFloat) )
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
                        [ codeText <| "Output:    " ++ prettyFloat 4 considerationValue
                        ]
                    , li []
                        [ codeText <| "Raw Value: " ++ prettyFloat 4 rawValue
                        ]
                    , li []
                        [ codeText <| "Min: " ++ (prettyFloat 4 <| con.inputMin) ++ ", Max: " ++ (prettyFloat 2 <| con.inputMax)
                        ]
                    , li []
                        [ codeText <| "Weighting: " ++ (prettyFloat 4 <| con.weighting)
                        ]
                    , li []
                        [ codeText <| "Offset:    " ++ (prettyFloat 4 <| con.offset)
                        ]
                    ]
                ]
            else
                []

        main =
            [ h5
                [ onClick <| ToggleConditionDetailsVisibility agent.name action.name con.name
                , (\( a, b ) -> style a b) ( "cursor", "pointer" )
                , (\( a, b ) -> style a b) ( "margin", "0.5em 0" )
                ]
                [ text "("
                , code [] [ text <| prettyFloat 2 considerationValue ]
                , text ")  "
                , text con.name
                ]
            , renderConsiderationChart agent currentTime action con
            ]
    in
        div [ (\( a, b ) -> style a b) ( "flex-basis", "20em" ) ]
            (List.append main details)


renderConsiderationChart : Agent -> Posix -> Action -> Consideration -> Html Msg
renderConsiderationChart agent currentTime action con =
    let
        inputMin =
            min con.inputMin con.inputMax

        inputMax =
            max con.inputMin con.inputMax

        step =
            (inputMax - inputMin) / 64

        stepwise : Float -> Maybe ( ( Float, Float ), Float )
        stepwise previous =
            if previous > inputMax then
                Nothing
            else
                let
                    datapoint =
                        ( previous, computeConsideration agent currentTime (Just previous) action con )

                    newStep =
                        previous + step
                in
                    Just ( datapoint, newStep )

        horizontalStep =
            (inputMax - inputMin) / 4

        stepwiseHorizontalTicksHelp : Float -> Maybe ( Float, Float )
        stepwiseHorizontalTicksHelp previous =
            if previous > inputMax then
                Nothing
            else
                Just ( previous, previous + horizontalStep )

        stepwiseHorizontalTicks : List Float
        stepwiseHorizontalTicks =
            List.Extra.unfoldr stepwiseHorizontalTicksHelp inputMin

        --        customLineToDataPoints : Float -> List (Plot.DataPoint msg)
        --        customLineToDataPoints data =
        --            ListE.unfoldr stepwise data
        --                |> List.map (\( xVal, yVal ) -> Plot.clear xVal yVal)
        --        customLine : Plot.Series Float msg
        --        customLine =
        --            { axis = verticalAxis
        --            , interpolation = Plot.Monotone Nothing [ Attributes.stroke "#ff9edf", Attributes.strokeWidth "3" ]
        --            , toDataPoints = customLineToDataPoints
        --            }
        --        currentValPointToDataPoints : Float -> List (Plot.DataPoint msg)
        --        currentValPointToDataPoints _ =
        --            let
        --                xVal =
        --                    getConsiderationRawValue agent currentTime action con
        --                        |> clampTo con
        --
        --                yVal =
        --                    computeConsideration agent currentTime (Just xVal) action con
        --            in
        --                [ blueCircle ( xVal, yVal ) ]
        --        blueCircle : ( Float, Float ) -> Plot.DataPoint msg
        --        blueCircle ( xVal, yVal ) =
        --            Plot.dot (Plot.viewCircle 10 "#ff0000") xVal yVal
        --        currentValPoint : Plot.Series Float msg
        --        currentValPoint =
        --            { axis = verticalAxis
        --            , interpolation = Plot.None
        --            , toDataPoints = currentValPointToDataPoints
        --            }
        --        verticalAxis : Plot.Axis
        --        verticalAxis =
        --            Plot.customAxis <|
        --                \summary ->
        --                    let
        --                        roundedMax =
        --                            summary.dataMax |> ceiling |> toFloat
        --
        --                        roundedMin =
        --                            summary.dataMin |> floor |> toFloat
        --
        --                        decentInterval =
        --                            (roundedMax - roundedMin) / 8
        --                    in
        --                        { position = Basics.min
        --                        , axisLine = Just (dataLine summary)
        --                        , ticks = List.map Plot.simpleTick (Plot.interval 0 decentInterval summary)
        --                        , labels = List.map Plot.simpleLabel (Plot.interval 0 decentInterval summary)
        --                        , flipAnchor = False
        --                        }
        --        horizontalAxis : Plot.Axis
        --        horizontalAxis =
        --            Plot.customAxis <|
        --                \summary ->
        --                    { position = Basics.min
        --                    , axisLine = Just (dataLine summary)
        --                    , ticks = List.map Plot.simpleTick stepwiseHorizontalTicks
        --                    , labels = List.map Plot.simpleLabel stepwiseHorizontalTicks
        --                    , flipAnchor = False
        --                    }
        --        dataLine : Plot.AxisSummary -> Plot.LineCustomizations
        --        dataLine summary =
        --            { attributes = [ stroke "grey" ]
        --            , start = summary.dataMin |> floor |> toFloat
        --            , end = summary.dataMax |> ceiling |> toFloat
        --            }
        --        title : Svg msg
        --        title =
        --            Plot.viewLabel
        --                [ fill "#afafaf"
        --                , (\( a, b ) -> style a b) ("text-anchor", "end")
        --                , (\( a, b ) -> style a b) ("font-style", "italic")
        --                ]
        --                (renderUF con.function)
        --        defaultSeriesPlotCustomizations =
        --            Plot.defaultSeriesPlotCustomizations
        --        view : Svg.Svg a
        --        view =
        --            Plot.viewSeriesCustom
        --                { defaultSeriesPlotCustomizations
        --                    | horizontalAxis = horizontalAxis
        --                    , junk = \summary -> [ Plot.junk title summary.x.dataMax summary.y.max ]
        --                    , toDomainLowest = \y -> y
        --                    , toRangeLowest = \y -> y
        --                    , width = 400
        --                    , height = 320
        --                }
        --                [ customLine, currentValPoint ]
        --                inputMin
    in
        div [] [ text "fixme" ]


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
                    [ "centerA=" ++ prettyFloat 1 centerA
                    , "bendA=" ++ prettyFloat 1 bendA
                    , "offsetA=" ++ prettyFloat 1 offsetA
                    , "squarenessA=" ++ prettyFloat 1 squarenessA
                    , "centerB=" ++ prettyFloat 1 centerB
                    , "bendB=" ++ prettyFloat 1 bendB
                    , "offsetB=" ++ prettyFloat 1 offsetB
                    , "squarenessB=" ++ prettyFloat 1 squarenessB
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
            "Constant " ++ prettyFloat 2 p

        CurrentSpeed ->
            "Current Speed "
                ++ (agent.physics.velocity
                        |> Vector2d.length
                        |> prettyFloat 2
                   )

        TimeSinceLastShoutedFeedMe ->
            let
                val =
                    case Dict.get "CallOut FeedMe" agent.topActionLastStartTimes of
                        Nothing ->
                            "Never"

                        Just t ->
                            (currentTime - t)
                                |> prettyFloat 2
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
    "(" ++ (prettyFloat 1 <| xCoordinate p) ++ ", " ++ (prettyFloat 1 <| yCoordinate p) ++ ")"


prettyFloatHtml : Int -> Float -> Html Msg
prettyFloatHtml dp n =
    prettyFloat dp n
        |> codeText


codeText : String -> Html Msg
codeText s =
    code [ (\( a, b ) -> style a b) ( "white-space", "pre-wrap" ) ] [ text s ]



-- fixme: restore the "pretty" part of the formatting


prettyFloat : Int -> Float -> String
prettyFloat dp n =
    String.fromFloat n


renderEmoji : String -> Point2d.Point2d -> Html Msg
renderEmoji emoji point =
    Svg.text_
        [ Attributes.textAnchor "middle"
        , Attributes.alignmentBaseline "middle"
        ]
        point
        emoji


renderName : Agent -> Html Msg
renderName agent =
    Svg.text_
        [ Attributes.textAnchor "middle"
        , Attributes.alignmentBaseline "hanging"
        ]
        (Point2d.translateBy
            (Vector2d.fromComponents ( 0, -10 ))
            agent.physics.position
        )
        agent.name


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


boolString : Bool -> String
boolString b =
    if b then
        "true"
    else
        "false"

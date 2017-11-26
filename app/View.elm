module View exposing (view)

import Dict
import Html exposing (Attribute, Html, code, div, h2, h3, h4, h5, li, text, ul)
import Html.Attributes exposing (class, style)
import Html.Events exposing (on, onClick)
import Json.Decode as Decode
import List.Extra as ListE
import Mouse exposing (Position)
import OpenSolid.BoundingBox2d as BoundingBox2d exposing (BoundingBox2d)
import OpenSolid.Point2d as Point2d exposing (xCoordinate, yCoordinate)
import OpenSolid.Svg as Svg exposing (render2d, relativeTo)
import OpenSolid.Vector2d as Vector2d exposing (Vector2d, scaleBy, sum)
import OpenSolid.Circle2d as Circle2d
import OpenSolid.Frame2d as Frame2d
import Svg exposing (Svg, g, rect, stop, svg)
import Svg.Attributes as Attributes
    exposing
        ( cx
        , cy
        , fill
        , height
        , id
        , offset
        , r
        , rx
        , ry
        , stopColor
        , stopOpacity
        , stroke
        , transform
        , viewBox
        , width
        , x
        , x1
        , x2
        , y
        , y1
        , y2
        )
import Time exposing (Time)
import Types
    exposing
        ( Action
        , Agent
        , Consideration
        , ConsiderationInput
            ( Constant
            , CurrentSpeed
            , CurrentlyCallingOut
            , DistanceToTargetPoint
            , Hunger
            , IsCurrentAction
            , TimeSinceLastShoutedFeedMe
            )
        , CurrentSignal
        , Fire
        , FireExtinguisher
        , Food
        , InputFunction(Asymmetric, Exponential, Linear, Normal, Sigmoid)
        , Model
        , Msg(ToggleConditionDetailsVisibility, ToggleConditionsVisibility)
        , Signal(Eating, FeedMe, GoAway)
        )
import Util exposing (mousePosToVec2)
import Formatting exposing (roundTo, padLeft, print, (<>))
import UtilityFunctions
    exposing
        ( clampTo
        , getActions
        , computeConsideration
        , computeUtility
        , getConsiderationRawValue
        )
import Plot


view : Model -> Html Msg
view model =
    div [ pageGridContainerStyle ]
        [ div
            [ mapGridItemStyle, class "zoom-svg" ]
            [ mainMap model
            ]
        , div
            [ agentInfoGridItemStyle ]
            [ agentsInfo model model.time model.agents
            ]
        ]


bb : BoundingBox2d
bb =
    BoundingBox2d.with
        { minX = -300
        , maxX = 300
        , minY = -300
        , maxY = 300
        }


render2dResponsive : BoundingBox2d -> Svg msg -> Html msg
render2dResponsive boundingBox svg =
    let
        { minX, maxY } =
            BoundingBox2d.extrema boundingBox

        topLeftFrame =
            Frame2d.atPoint (Point2d.fromCoordinates ( minX, maxY ))
                |> Frame2d.flipY

        ( width, height ) =
            BoundingBox2d.dimensions boundingBox

        coords =
            [ 0
            , 0
            , width
            , height
            ]
                |> List.map toString
                |> String.join " "
    in
        Svg.svg
            [ Attributes.width (toString width)
            , Attributes.height (toString height)
            , viewBox coords
            ]
            [ relativeTo topLeftFrame svg ]


mainMap : Model -> Html.Html Msg
mainMap model =
    render2dResponsive bb
        (g [ id "mainMap" ]
            [ g [ id "agents" ]
                (List.map renderAgent model.agents)
            , g [ id "foods" ]
                (List.map renderFood model.foods)
            , g [ id "fires" ]
                (List.map renderFire model.fires)
            , g [ id "extinguishers" ]
                (List.map renderExtinguisher model.extinguishers)
            , borderIndicator 200
            , borderIndicator 300
            ]
        )


borderIndicator : Float -> Svg Msg
borderIndicator r =
    Svg.circle2d
        [ Attributes.fillOpacity "0"
        , Attributes.stroke "grey"
        , Attributes.strokeWidth "1"
        ]
        (Circle2d.with
            { centerPoint = Point2d.origin
            , radius = r
            }
        )


agentsInfo : Model -> Time -> List Agent -> Html.Html Msg
agentsInfo model currentTime agents =
    div []
        [ h2 []
            [ text "Agents" ]
        , div
            []
            (List.map (renderAgentInfo model currentTime) agents)
        ]


(=>) =
    (,)


pageGridContainerStyle =
    style
        [ "display" => "grid"
        , "width" => "calc(100vw)"
        , "max-width" => "calc(100vw)"
        , "height" => "calc(100vh)"
        , "max-height" => "calc(100vh)"
        , "overflow" => "hidden"
        , "grid-template-columns" => "repeat(3, 1fr)"
        , "grid-template-rows" => "2fr 1fr"
        ]


mapGridItemStyle =
    style
        [ "grid-column" => "1 / 2"
        , "grid-row" => "1 / 2"
        , "overflow" => "hidden"
        , "margin" => "0.5em"
        ]


agentInfoGridItemStyle =
    style
        [ "grid-column" => "2 / 4"
        , "grid-row" => "1 / 3"
        , "overflow" => "auto"
        ]


px : Int -> String
px number =
    toString number ++ "px"


inPx : Float -> String
inPx number =
    toString number ++ "px"


agentPoint : Svg.PointOptions msg
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
        Svg.vector2d
            { tipLength = exaggeratedLength * 0.1
            , tipWidth = exaggeratedLength * 0.05
            , tipAttributes =
                [ Attributes.fill "orange"
                , Attributes.stroke "blue"
                , Attributes.strokeWidth "1"
                ]
            , stemAttributes =
                [ Attributes.stroke "blue"
                , Attributes.strokeWidth "1"
                , Attributes.strokeDasharray "1 2"
                ]
            , groupAttributes = []
            }
            agent.physics.position
            exaggerated


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
    in
        g [ id <| "agent " ++ agent.name ]
            (List.append
                [ Svg.point2d agentPoint agent.physics.position
                , Svg.direction2d facingArrow agent.physics.position agent.physics.facing
                , agentVelocityArrow agent
                , renderName agent
                    |> Svg.scaleAbout agent.physics.position 0.7
                ]
                call
            )


renderAgentInfo : Model -> Time -> Agent -> Html Msg
renderAgentInfo model currentTime agent =
    div []
        [ h3
            [ style [ "margin-bottom" => "0.1em" ] ]
            [ text agent.name ]
        , div [ style indentWithLine ]
            (getActions agent
                |> List.map (renderAction agent currentTime)
            )
        ]


renderCalling : Maybe CurrentSignal -> Html Msg
renderCalling currentSignal =
    case currentSignal of
        Nothing ->
            text "Nothing"

        Just calling ->
            case calling.signal of
                FeedMe ->
                    text "Feed Me!"

                GoAway ->
                    text "Go away"

                Eating ->
                    text "nom nom nom"


indentWithLine =
    [ "margin-left" => "0.2em"
    , "padding-left" => "1em"
    , "border-left" => "1px solid grey"
    ]


renderAction : Agent -> Time -> Action -> Html Msg
renderAction agent currentTime action =
    let
        isExpanded =
            Dict.get action.name agent.visibleActions
                |> Maybe.withDefault False

        considerations =
            if isExpanded then
                [ div
                    [ style
                        [ "display" => "flex"
                        ]
                    ]
                    (List.map (renderConsideration agent action currentTime) action.considerations)
                ]
            else
                []

        containerStyle =
            if isExpanded then
                style
                    [ "background-color" => "#00000011"
                    , "padding" => "0.6em"
                    ]
            else
                style [ "padding" => "0.6em" ]

        utility =
            computeUtility agent currentTime action
    in
        div [ containerStyle ]
            (List.append
                [ h4
                    [ onClick <| ToggleConditionsVisibility agent.name action.name
                    , style
                        [ "cursor" => "pointer"
                        , "margin" => "0"
                        , "opacity" => (utility ^ (1 / 1.5) + 0.3 |> toString)
                        ]
                    ]
                    [ text "("
                    , prettyFloatHtml 2 utility
                    , text ") "
                    , text action.name
                    ]
                ]
                considerations
            )


renderConsideration : Agent -> Action -> Time -> Consideration -> Html Msg
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
                        [ codeText <| "Input: " ++ (renderCI currentTime agent action con.input)
                        ]
                    , li []
                        [ codeText <| "Output:    " ++ (prettyFloat 4 considerationValue)
                        ]
                    , li []
                        [ codeText <| "Raw Value: " ++ (prettyFloat 4 rawValue)
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
                , style
                    [ "cursor" => "pointer"
                    , "margin" => "0.5em 0"
                    ]
                ]
                [ text "("
                , code [] [ text <| prettyFloat 2 considerationValue ]
                , text ")  "
                , text con.name
                ]
            , renderConsiderationChart agent currentTime action con
            ]
    in
        div [ style [ "flex-basis" => "20em" ] ]
            (List.append main details)


renderConsiderationChart : Agent -> Time -> Action -> Consideration -> Html Msg
renderConsiderationChart agent currentTime action con =
    let
        data =
            inputMin

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
            ListE.unfoldr stepwiseHorizontalTicksHelp inputMin

        customLineToDataPoints : Float -> List (Plot.DataPoint msg)
        customLineToDataPoints data =
            ListE.unfoldr stepwise data
                |> List.map (\( x, y ) -> Plot.clear x y)

        customLine : Plot.Series Float msg
        customLine =
            { axis = verticalAxis
            , interpolation = Plot.Monotone Nothing [ Attributes.stroke "#ff9edf", Attributes.strokeWidth "3" ]
            , toDataPoints = customLineToDataPoints
            }

        currentValPointToDataPoints : Float -> List (Plot.DataPoint msg)
        currentValPointToDataPoints data =
            let
                x =
                    getConsiderationRawValue agent currentTime action con
                        |> clampTo con

                y =
                    computeConsideration agent currentTime (Just x) action con
            in
                [ blueCircle ( x, y ) ]

        blueCircle : ( Float, Float ) -> Plot.DataPoint msg
        blueCircle ( x, y ) =
            Plot.dot (Plot.viewCircle 10 "#ff0000") x y

        currentValPoint : Plot.Series Float msg
        currentValPoint =
            { axis = verticalAxis
            , interpolation = Plot.None
            , toDataPoints = currentValPointToDataPoints
            }

        verticalAxis : Plot.Axis
        verticalAxis =
            Plot.customAxis <|
                \summary ->
                    let
                        roundedMax =
                            summary.dataMax |> ceiling |> toFloat

                        roundedMin =
                            summary.dataMin |> floor |> toFloat

                        decentInterval =
                            (roundedMax - roundedMin) / 8
                    in
                        { position = Basics.min
                        , axisLine = Just (dataLine summary)
                        , ticks = List.map Plot.simpleTick (Plot.interval 0 decentInterval summary)
                        , labels = List.map Plot.simpleLabel (Plot.interval 0 decentInterval summary)
                        , flipAnchor = False
                        }

        horizontalAxis : Plot.Axis
        horizontalAxis =
            Plot.customAxis <|
                \summary ->
                    { position = Basics.min
                    , axisLine = Just (dataLine summary)
                    , ticks = List.map Plot.simpleTick stepwiseHorizontalTicks
                    , labels = List.map Plot.simpleLabel stepwiseHorizontalTicks
                    , flipAnchor = False
                    }

        dataLine : Plot.AxisSummary -> Plot.LineCustomizations
        dataLine summary =
            { attributes = [ stroke "grey" ]
            , start = summary.dataMin |> floor |> toFloat
            , end = summary.dataMax |> ceiling |> toFloat
            }

        title : Svg msg
        title =
            Plot.viewLabel
                [ fill "#afafaf"
                , style [ "text-anchor" => "end", "font-style" => "italic" ]
                ]
                (renderUF con.function)

        defaultSeriesPlotCustomizations =
            Plot.defaultSeriesPlotCustomizations

        view : Svg.Svg a
        view =
            Plot.viewSeriesCustom
                { defaultSeriesPlotCustomizations
                    | horizontalAxis = horizontalAxis
                    , junk = \summary -> [ Plot.junk title summary.x.dataMax summary.y.max ]
                    , toDomainLowest = \y -> y
                    , toRangeLowest = \y -> y
                    , width = 400
                    , height = 320
                }
                [ customLine, currentValPoint ]
                inputMin
    in
        view


renderUF : InputFunction -> String
renderUF f =
    case f of
        Linear m b ->
            "Linear (slope = " ++ (toString m) ++ ", offset = " ++ (toString b) ++ ")"

        Exponential exponent ->
            "Exponential (exponent = " ++ (toString exponent) ++ ")"

        Sigmoid bend center ->
            "Sigmoid (bend = " ++ (toString bend) ++ ", center = " ++ (toString center) ++ ")"

        Normal tightness center squareness ->
            let
                vals =
                    [ "tightness = " ++ (toString tightness)
                    , "center = " ++ (toString center)
                    , "squareness = " ++ (toString squareness)
                    ]
            in
                "Normal (" ++ String.join ", " vals ++ ")"

        Asymmetric centerA bendA offsetA squarenessA centerB bendB offsetB squarenessB ->
            let
                vals =
                    [ "centerA=" ++ (prettyFloat 1 centerA)
                    , "bendA=" ++ (prettyFloat 1 bendA)
                    , "offsetA=" ++ (prettyFloat 1 offsetA)
                    , "squarenessA=" ++ (prettyFloat 1 squarenessA)
                    , "centerB=" ++ (prettyFloat 1 centerB)
                    , "bendB=" ++ (prettyFloat 1 bendB)
                    , "offsetB=" ++ (prettyFloat 1 offsetB)
                    , "squarenessB=" ++ (prettyFloat 1 squarenessB)
                    ]
            in
                "Asymmetric (" ++ String.join ", " vals ++ ")"


renderCI : Time -> Agent -> Action -> ConsiderationInput -> String
renderCI currentTime agent action ci =
    case ci of
        Hunger ->
            "Hunger"

        DistanceToTargetPoint p ->
            "Distance to point " ++ (prettyPoint2d p)

        Constant p ->
            "Constant " ++ (prettyFloat 2 p)

        CurrentSpeed ->
            "Current Speed "
                ++ (agent.physics.velocity
                        |> Vector2d.length
                        |> prettyFloat 2
                   )

        TimeSinceLastShoutedFeedMe ->
            let
                val =
                    case agent.timeLastShoutedFeedMe of
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
                ++ (toString <|
                        case agent.callingOut of
                            Nothing ->
                                0

                            Just _ ->
                                1
                   )

        IsCurrentAction ->
            "Is action the current one? " ++ (toString <| action.name == agent.currentAction)


vectorAngleDegrees : Vector2d.Vector2d -> Float
vectorAngleDegrees vec =
    let
        ( length, polarAngle ) =
            Vector2d.polarComponents vec
    in
        polarAngle / (turns 1) * 360


prettyPoint2dHtml : Point2d.Point2d -> Html Msg
prettyPoint2dHtml p =
    prettyPoint2d p
        |> codeText


prettyPoint2d : Point2d.Point2d -> String
prettyPoint2d p =
    "(" ++ (prettyFloat 1 <| xCoordinate p) ++ ", " ++ (prettyFloat 1 <| yCoordinate p) ++ ")"


prettyFloatHtml : Int -> Float -> Html Msg
prettyFloatHtml dp n =
    prettyFloat dp n
        |> codeText


codeText : String -> Html Msg
codeText s =
    code [ style [ "white-space" => "pre-wrap" ] ] [ text s ]


prettyFloat : Int -> Float -> String
prettyFloat dp n =
    print (Formatting.roundTo dp |> Formatting.padLeft 6 ' ') n


renderArrowToAgent : Agent -> Svg msg
renderArrowToAgent agent =
    Svg.vector2d
        { tipLength = 30
        , tipWidth = 15
        , tipAttributes =
            [ Attributes.fill "orange"
            , Attributes.stroke "blue"
            , Attributes.strokeWidth "2"
            ]
        , stemAttributes =
            [ Attributes.stroke "blue"
            , Attributes.strokeWidth "3"
            , Attributes.strokeDasharray "3 3"
            ]
        , groupAttributes = []
        }
        Point2d.origin
        (Vector2d.from Point2d.origin agent.physics.position)


renderEmoji : String -> Point2d.Point2d -> Html Msg
renderEmoji emoji point =
    Svg.text2d
        [ Attributes.textAnchor "middle"
        , Attributes.alignmentBaseline "middle"
        ]
        point
        emoji


renderName : Agent -> Html Msg
renderName agent =
    Svg.text2d
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


renderExtinguisher : FireExtinguisher -> Svg Msg
renderExtinguisher extinguisher =
    -- todo: replace 🚒 with the fire extinguisher symbol in Unicode 11
    renderEmoji "🚒" extinguisher.physics.position


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
    in
        g [ id <| "fire_" ++ (toString fire.id) ]
            [ renderEmoji "🔥" fire.physics.position
            , gradient
            , redness
            ]

module View exposing (view)

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
import Svg exposing (Svg, g, rect, svg)
import Svg.Attributes as Attributes exposing (fill, height, rx, ry, stroke, transform, viewBox, width, x, y)
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
            , TimeSinceLastShoutedFeedMe
            )
        , CurrentSignal
        , Fire
        , Food
        , InputFunction(Exponential, InverseNormal, Linear, Normal, Sigmoid)
        , Model
        , Msg(ToggleConditionDetailsVisibility, ToggleConditionsVisibility)
        , Signal(Eating, FeedMe, GoAway)
        )
import Util exposing (mousePosToVec2)
import Formatting exposing (roundTo, padLeft, print, (<>))
import UtilityFunctions exposing (clampTo, computeConsideration, computeUtility, getConsiderationRawValue)
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
            [ agentsInfo model.time model.agents
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
        (g []
            [ g []
                (List.map renderAgent model.agents)
            , g []
                (List.map renderFood model.foods)
            , g []
                (List.map renderFire model.fires)
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


agentsInfo : Time -> List Agent -> Html.Html Msg
agentsInfo currentTime agents =
    div []
        [ h2 []
            [ text "Agents" ]
        , div
            []
            (List.map (renderAgentInfo currentTime) agents)
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
            scaleBy 2 agent.velocity

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
            agent.position
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
                            [ renderEmoji "😮" agent.position
                                |> Svg.scaleAbout agent.position 2
                            ]

                        GoAway ->
                            [ renderEmoji "😣" agent.position ]

                        Eating ->
                            [ renderEmoji "🍖" agent.position ]
    in
        g []
            (List.append
                [ Svg.point2d agentPoint agent.position
                , Svg.direction2d facingArrow agent.position agent.facing
                , agentVelocityArrow agent
                ]
                call
            )


renderAgentInfo : Time -> Agent -> Html Msg
renderAgentInfo currentTime agent =
    div []
        [ h3 [] [ text agent.name ]
        , ul []
            [ li [] [ text "Position: ", prettyPoint2dHtml agent.position ]
            , li [] [ text "Speed: ", prettyFloatHtml 2 <| Vector2d.length agent.velocity ]
            , li [] [ text "Heading: ", prettyFloatHtml 2 <| vectorAngleDegrees agent.velocity ]
            , li [] [ text "Calling: ", renderCalling agent.callingOut ]
            ]
        , text "Actions:"
        , div [ style indentWithLine ]
            (List.map (renderAction agent currentTime)
                agent.actions
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
        considerations =
            if action.considerationsVisible then
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
            if action.considerationsVisible then
                style
                    [ "background-color" => "#00000011"
                    , "padding" => "0.6em"
                    ]
            else
                style [ "padding" => "0.6em" ]
    in
        div [ containerStyle ]
            (List.append
                [ h4
                    [ onClick <| ToggleConditionsVisibility agent.name action.name
                    , style
                        [ "cursor" => "pointer"
                        , "margin" => "0"
                        ]
                    ]
                    [ text "("
                    , prettyFloatHtml 2 <| computeUtility agent currentTime action
                    , text ") "
                    , text action.name
                    ]
                ]
                considerations
            )


renderConsideration : Agent -> Action -> Time -> Consideration -> Html Msg
renderConsideration agent action currentTime con =
    let
        details =
            if con.detailsVisible then
                [ renderConsiderationChart agent currentTime con
                ]
            else
                []

        heading =
            [ h5
                [ onClick <| ToggleConditionDetailsVisibility agent.name action.name con.name
                , style
                    [ "cursor" => "pointer"
                    , "margin" => "0.5em 0"
                    ]
                ]
                [ text "("
                , code [] [ text <| prettyFloat 2 <| computeConsideration agent currentTime Nothing con ]
                , text ")  "
                , text con.name
                ]
            ]
    in
        div [ style [ "flex-basis" => "20em" ] ]
            (List.append heading details)


renderConsiderationChart : Agent -> Time -> Consideration -> Html Msg
renderConsiderationChart agent currentTime con =
    let
        data =
            inputMin

        inputMin =
            min con.inputMin con.inputMax

        inputMax =
            max con.inputMin con.inputMax

        step =
            (inputMax - inputMin) / 16

        stepwise : Float -> Maybe ( ( Float, Float ), Float )
        stepwise previous =
            if previous > inputMax then
                Nothing
            else
                let
                    datapoint =
                        ( previous, computeConsideration agent currentTime (Just previous) con )

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
                    getConsiderationRawValue agent currentTime con
                        |> clampTo con

                y =
                    computeConsideration agent currentTime (Just x) con
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

        Normal tightness center ->
            "Normal (tightness = " ++ (toString tightness) ++ ", center = " ++ (toString center) ++ ")"

        InverseNormal tightness center ->
            "InverseNormal (tightness = " ++ (toString tightness) ++ ", center = " ++ (toString center) ++ ")"


renderCI : Time -> Agent -> ConsiderationInput -> String
renderCI currentTime agent ci =
    case ci of
        Hunger ->
            "Hunger"

        DistanceToTargetPoint p ->
            "Distance to point " ++ (prettyPoint2d p)

        Constant p ->
            "Constant " ++ (prettyFloat 2 p)

        CurrentSpeed ->
            "Current Speed "
                ++ (agent.velocity
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
            "Currently calling out"
                ++ (toString <|
                        case agent.callingOut of
                            Nothing ->
                                0

                            Just _ ->
                                1
                   )


vectorAngleDegrees : Vector2d.Vector2d -> Float
vectorAngleDegrees vec =
    let
        ( length, polarAngle ) =
            Vector2d.polarComponents vec
    in
        polarAngle / (turns 1) * 360


prettyPoint2dHtml : Point2d.Point2d -> Html Msg
prettyPoint2dHtml p =
    code [ style [ "white-space" => "pre-wrap" ] ]
        [ text <| prettyPoint2d p ]


prettyPoint2d : Point2d.Point2d -> String
prettyPoint2d p =
    "(" ++ (prettyFloat 1 <| xCoordinate p) ++ ", " ++ (prettyFloat 1 <| yCoordinate p) ++ ")"


prettyFloatHtml : Int -> Float -> Html Msg
prettyFloatHtml dp n =
    code [ style [ "white-space" => "pre-wrap" ] ] [ text <| prettyFloat dp n ]


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
        (Vector2d.from Point2d.origin agent.position)


renderEmoji : String -> Point2d.Point2d -> Html Msg
renderEmoji emoji point =
    Svg.text2d
        [ Attributes.textAnchor "middle"
        , Attributes.alignmentBaseline "middle"
        ]
        point
        emoji


renderFood : Food -> Html Msg
renderFood food =
    renderEmoji "🍽" food.position


renderFire : Fire -> Html Msg
renderFire fire =
    renderEmoji "🔥" fire.position

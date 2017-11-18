module View exposing (view)

import Html exposing (Attribute, Html, code, div, h2, h3, h4, h5, li, text, ul)
import Html.Attributes exposing (class, style)
import Html.Events exposing (on, onClick)
import Json.Decode as Decode
import Mouse exposing (Position)
import OpenSolid.BoundingBox2d as BoundingBox2d exposing (BoundingBox2d)
import OpenSolid.Point2d as Point2d exposing (xCoordinate, yCoordinate)
import OpenSolid.Svg as Svg exposing (render2d)
import OpenSolid.Vector2d as Vector2d exposing (Vector2d, scaleBy, sum)
import Svg exposing (Svg, g, rect, svg)
import Svg.Attributes as Attributes exposing (height, rx, ry, transform, viewBox, width, x, y)
import Time exposing (Time)
import Types
    exposing
        ( Action
        , Agent
        , Consideration
        , ConsiderationInput(DistanceToTargetPoint, Hunger)
        , InputFunction(Exponential, InverseNormal, Linear, Normal, Sigmoid)
        , Model
        , Msg(ToggleConditionsVisibility)
        )
import Util exposing (mousePosToVec2)
import Formatting exposing (roundTo, padLeft, print, (<>))
import UtilityFunctions exposing (computeConsideration, computeUtility, getConsiderationRawValue)


view : Model -> Html Msg
view model =
    div [ pageGridContainerStyle ]
        [ div
            [ mapGridItemStyle, class "zoom-svg" ]
            [ (mainMap model.agents)
            ]
        , div
            [ agentInfoGridItemStyle ]
            [ (agentsInfo model.agents)
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


mainMap : List Agent -> Html.Html Msg
mainMap agents =
    render2d bb
        (g []
            [ g []
                (List.map renderAgent agents)
            , g []
                (List.map renderArrowToAgent agents)
            ]
        )


agentsInfo : List Agent -> Html.Html Msg
agentsInfo agents =
    div []
        [ h2 []
            [ text "Agents" ]
        , div
            []
            (List.map renderAgentInfo agents)
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
        [ "grid-column" => "2 / 3"
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
                , Attributes.strokeWidth "2"
                ]
            , stemAttributes =
                [ Attributes.stroke "blue"
                , Attributes.strokeWidth "3"
                , Attributes.strokeDasharray "3 3"
                ]
            , groupAttributes = []
            }
            agent.position
            exaggerated


renderAgent : Agent -> Html Msg
renderAgent agent =
    g []
        [ Svg.point2d agentPoint agent.position
        , Svg.direction2d facingArrow agent.position agent.facing
        , agentVelocityArrow agent
        ]


renderAgentInfo : Agent -> Html Msg
renderAgentInfo agent =
    div []
        [ h3 [] [ text agent.name ]
        , ul []
            [ li [] [ text "Position: ", prettyPoint2dHtml agent.position ]
            , li [] [ text "Speed: ", prettyFloatHtml 2 <| Vector2d.length agent.velocity ]
            , li [] [ text "Heading: ", prettyFloatHtml 2 <| vectorAngleDegrees agent.velocity ]
            ]
        , text "Actions:"
        , div [ style indentWithLine ]
            (List.map (renderAction agent) <|
                List.reverse <|
                    List.sortBy (computeUtility agent) agent.actions
            )
        ]


indentWithLine =
    [ "margin-left" => "0.2em"
    , "padding-left" => "1em"
    , "border-left" => "1px solid grey"
    ]


renderAction : Agent -> Action -> Html Msg
renderAction agent action =
    let
        considerations =
            if action.considerationsVisible then
                [ text "Considerations:"
                , div [ style indentWithLine ]
                    (List.map (renderConsideration agent) <|
                        List.reverse <|
                            List.sortBy (computeConsideration agent Nothing) action.considerations
                    )
                ]
            else
                []
    in
        div []
            (List.append
                [ h4
                    [ onClick <| ToggleConditionsVisibility agent.name action.name
                    , style [ "cursor" => "pointer" ]
                    ]
                    [ text "("
                    , prettyFloatHtml 2 <| computeUtility agent action
                    , text ") "
                    , text action.name
                    ]
                ]
                considerations
            )


renderConsideration : Agent -> Consideration -> Html Msg
renderConsideration agent con =
    div []
        [ h5 [] [ text con.name ]
        , ul []
            [ li [] [ text <| "Utility Function: " ++ (renderUF con.function) ]
            , li [] [ text <| "Consideration Input: " ++ (renderCI con.input) ]
            , li [] [ text <| "Consideration Raw Value: " ++ (prettyFloat 2 <| getConsiderationRawValue agent con) ]
            , li [] [ text <| "Consideration Min & Max: " ++ (prettyFloat 2 <| con.inputMin) ++ ", " ++ (prettyFloat 2 <| con.inputMax) ]
            , li [] [ text <| "Consideration Output: " ++ (prettyFloat 2 <| computeConsideration agent Nothing con) ]
            ]
        ]


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


renderCI : ConsiderationInput -> String
renderCI ci =
    case ci of
        Hunger ->
            "Hunger"

        DistanceToTargetPoint p ->
            "Distance to point " ++ (prettyPoint2d p)


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

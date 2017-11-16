module View exposing (view)

import Html exposing (Attribute, Html, div, text)
import Html.Attributes exposing (class, style)
import Html.Events exposing (on)
import Json.Decode as Decode
import Mouse exposing (Position)
import OpenSolid.BoundingBox2d as BoundingBox2d exposing (BoundingBox2d)
import OpenSolid.Point2d as Point2d
import OpenSolid.Svg as Svg exposing (render2d)
import OpenSolid.Vector2d as Vector2d exposing (Vector2d, scaleBy, sum)
import Svg exposing (Svg, g, rect, svg)
import Svg.Attributes as Attributes exposing (height, rx, ry, transform, viewBox, width, x, y)
import Time exposing (Time)
import Types exposing (Agent, Model, Msg)
import Util exposing (mousePosToVec2)


(=>) =
    (,)


bb : BoundingBox2d
bb =
    BoundingBox2d.with
        { minX = -300
        , maxX = 300
        , minY = -300
        , maxY = 300
        }


mainMap : List Agent -> Html.Html msg
mainMap agents =
    render2d bb
        (g []
            [ g []
                (List.map renderAgent agents)
            , g []
                (List.map renderArrowToAgent agents)
            ]
        )


view : Model -> Html Msg
view model =
    div [ pageGridContainerStyle ]
        [ div
            [ mapGridItemStyle, class "zoom-svg" ]
            [ (mainMap model.agents)
            ]
        ]


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


renderAgent : Agent -> Html msg
renderAgent agent =
    g []
        [ Svg.point2d agentPoint agent.position
        , Svg.direction2d facingArrow agent.position agent.facing
        , agentVelocityArrow agent
        ]


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

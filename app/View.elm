module View exposing (view)

import Html exposing (Attribute, Html, div, text)
import Html.Attributes exposing (style)
import Html.Events exposing (on)
import Json.Decode as Decode
import Math.Vector2 exposing (Vec2, add, getX, getY, sub, vec2)
import Mouse exposing (Position)
import Svg exposing (rect, svg)
import Svg.Attributes exposing (height, rx, ry, viewBox, width, x, y)
import Time exposing (Time)
import Types exposing (Model, Msg(DragStart))
import Util exposing (getPosition, mousePosToVec2)


(=>) =
    (,)


roundRect : Html.Html msg
roundRect =
    svg
        [ width "120", height "120", viewBox "0 0 120 120" ]
        [ rect [ x "10", y "10", width "100", height "100", rx "15", ry "15" ] [] ]


view : Model -> Html Msg
view model =
    let
        realPosition =
            add (getPosition model) (wiggler model.time)
    in
        div []
            [ roundRect
            , div
                [ onMouseDown
                , style
                    [ "background-color" => "#3C8D2F"
                    , "cursor" => "move"
                    , "width" => "100px"
                    , "height" => "100px"
                    , "border-radius" => "4px"
                    , "position" => "absolute"
                    , "left" => (getX realPosition |> round |> px)
                    , "top" => (getY realPosition |> round |> px)
                    , "color" => "white"
                    , "display" => "flex"
                    , "align-items" => "center"
                    , "justify-content" => "center"
                    , "user-select" => "none"
                    ]
                ]
                [ text "Drag Me!"
                ]
            ]


px : Int -> String
px number =
    toString number ++ "px"


onMouseDown : Attribute Msg
onMouseDown =
    on "mousedown" (Decode.map (mousePosToVec2 >> DragStart) Mouse.position)


wiggler : Time -> Vec2
wiggler t =
    let
        x =
            cos (t / 100) * 20

        y =
            sin (t / 100) * 20
    in
        vec2 x y

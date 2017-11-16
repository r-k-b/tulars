module View exposing (view)

import Html exposing (Attribute, Html, div, text)
import Html.Attributes exposing (style)
import Html.Events exposing (on)
import Json.Decode as Decode
import Mouse exposing (Position)
import Svg exposing (rect, svg)
import Svg.Attributes exposing (height, rx, ry, viewBox, width, x, y)
import Time exposing (Time)
import Types exposing (Model, Msg(DragStart))


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
            getPosition model |> wigglePosition model.time
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
                    , "left" => px realPosition.x
                    , "top" => px realPosition.y
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
    on "mousedown" (Decode.map DragStart Mouse.position)


getPosition : Model -> Position
getPosition { position, drag } =
    case drag of
        Nothing ->
            position

        Just { start, current } ->
            Position
                (position.x + current.x - start.x)
                (position.y + current.y - start.y)


wigglePosition : Time -> Position -> Position
wigglePosition t p =
    let
        x2 =
            p.x + floor (cos (t / 100) * 20)

        y2 =
            p.y + floor (sin (t / 100) * 20)
    in
        Position x2 y2

module Main exposing (main)

import Html exposing (Attribute, Html, div, text)
import Html.Attributes exposing (style)
import Html.Events exposing (on)
import Json.Decode as Decode
import Mouse exposing (Position)
import Svg exposing (rect, svg)
import Svg.Attributes exposing (height, rx, ry, viewBox, width, x, y)
import Types exposing (Drag, Model, Msg(DragAt, DragEnd, DragStart, RAFtick))
import View exposing (view)
import AnimationFrame exposing (times)
import Math.Vector2 exposing (Vec2, add, sub, vec2)
import Util exposing (getPosition, mousePosToVec2)


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


init : ( Model, Cmd Msg )
init =
    ( Model (vec2 200 200) Nothing 0, Cmd.none )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg ({ position, drag, time } as model) =
    case msg of
        DragStart xy ->
            Model position (Just (Drag xy xy)) time

        DragAt xy ->
            Model position (Maybe.map (\{ start } -> Drag start xy) drag) time

        DragEnd _ ->
            Model (getPosition model) Nothing time

        RAFtick t ->
            Model position drag t



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        drags =
            case model.drag of
                Nothing ->
                    Sub.none

                Just _ ->
                    Sub.batch [ Mouse.moves (mousePosToVec2 >> DragAt), Mouse.ups (mousePosToVec2 >> DragEnd) ]
    in
        Sub.batch [ drags, times RAFtick ]

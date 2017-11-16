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
    ( Model (Position 200 200) Nothing 0, Cmd.none )



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
                    Sub.batch [ Mouse.moves DragAt, Mouse.ups DragEnd ]
    in
        Sub.batch [ drags, times RAFtick ]


getPosition : Model -> Position
getPosition { position, drag } =
    case drag of
        Nothing ->
            position

        Just { start, current } ->
            Position
                (position.x + current.x - start.x)
                (position.y + current.y - start.y)

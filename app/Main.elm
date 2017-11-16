module Main exposing (main)

import Html exposing (Html)
import Json.Decode as Decode
import Mouse exposing (Position)
import OpenSolid.Direction2d exposing (fromAngle)
import Types exposing (Agent, Drag, Model, Msg(DragAt, DragEnd, DragStart, RAFtick))
import View exposing (view)
import AnimationFrame exposing (times)
import Util exposing (getPosition, mousePosToVec2)
import OpenSolid.Vector2d as Vector2d exposing (Vector2d)
import OpenSolid.Point2d as Point2d


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
    ( Model (Vector2d.fromComponents ( 200, 200 )) Nothing 0 [ defaultAgent ], Cmd.none )


defaultAgent : Agent
defaultAgent =
    { facing = fromAngle (degrees 70)
    , position = Point2d.fromCoordinates ( 200, 150 )
    , velocity = Vector2d.fromComponents ( 1, 1 )
    }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg ({ position, drag, time, agents } as model) =
    case msg of
        DragStart xy ->
            Model position (Just (Drag xy xy)) time agents

        DragAt xy ->
            Model position (Maybe.map (\{ start } -> Drag start xy) drag) time agents

        DragEnd _ ->
            Model (getPosition model) Nothing time agents

        RAFtick t ->
            Model position drag t agents



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

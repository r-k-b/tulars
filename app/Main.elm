module Main exposing (main)

import Html exposing (Html)
import Json.Decode as Decode
import Mouse exposing (Position)
import OpenSolid.Direction2d as Direction2d
import Task exposing (perform)
import Types exposing (Agent, Drag, Model, Msg(DragAt, DragEnd, DragStart, InitTime, RAFtick))
import View exposing (view)
import AnimationFrame exposing (times)
import Util exposing (getPosition, mousePosToVec2)
import OpenSolid.Vector2d as Vector2d exposing (Vector2d)
import OpenSolid.Point2d as Point2d
import Time exposing (Time)


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
    ( Model (Vector2d.fromComponents ( 200, 200 )) Nothing 0 defaultAgents, perform InitTime Time.now )


defaultAgents : List Agent
defaultAgents =
    [ { facing = Direction2d.fromAngle (degrees 70)
      , position = Point2d.fromCoordinates ( 200, 150 )
      , velocity = Vector2d.fromComponents ( -1, -10 )
      }
    , { facing = Direction2d.fromAngle (degrees 200)
      , position = Point2d.fromCoordinates ( 100, 250 )
      , velocity = Vector2d.fromComponents ( -10, -20 )
      }
    ]



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

        RAFtick newT ->
            let
                dMove =
                    moveAgent <| newT - time
            in
                Model position drag newT (List.map dMove agents)

        InitTime t ->
            Model position drag t agents


moveAgent : Time -> Agent -> Agent
moveAgent dT agent =
    let
        dV =
            Vector2d.scaleBy (dT / 1000) agent.velocity

        newPosition =
            Point2d.translateBy dV agent.position
    in
        { agent | position = newPosition }



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

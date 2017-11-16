module Main exposing (main)

import Html exposing (Html)
import Json.Decode as Decode
import Mouse exposing (Position)
import OpenSolid.Direction2d as Direction2d
import Task exposing (perform)
import Types exposing (Action, Agent, Consideration, ConsiderationInput(DistanceToTargetPoint, Hunger), InputFunction(Exponential, Linear, Normal, Sigmoid), Model, Msg(InitTime, RAFtick))
import View exposing (view)
import AnimationFrame exposing (times)
import Util exposing (mousePosToVec2)
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
    ( Model 0 defaultAgents
    , perform InitTime Time.now
    )


defaultAgents : List Agent
defaultAgents =
    [ { facing = Direction2d.fromAngle (degrees 70)
      , position = Point2d.fromCoordinates ( 200, 150 )
      , velocity = Vector2d.fromComponents ( -1, -10 )
      , acceleration = Vector2d.zero
      , actions =
            [ Action
                "stay near the origin"
                [ { name = "distance from origin"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint Point2d.origin
                  , inputMin = 0
                  , inputMax = 400
                  , weighting = 1
                  , offset = 0
                  }
                ]
            ]
      }
    , { facing = Direction2d.fromAngle (degrees 200)
      , position = Point2d.fromCoordinates ( 100, 250 )
      , velocity = Vector2d.fromComponents ( -10, -20 )
      , acceleration = Vector2d.fromComponents ( -2, -1 )
      , actions =
            [ Action
                "stay near the origin"
                [ { name = "distance from origin"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint Point2d.origin
                  , inputMin = 0
                  , inputMax = 400
                  , weighting = 1
                  , offset = 0
                  }
                ]
            ]
      }
    ]



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg ({ time, agents } as model) =
    case msg of
        RAFtick newT ->
            let
                dMove =
                    moveAgent <| newT - time
            in
                Model newT (List.map dMove agents)

        InitTime t ->
            Model t agents


moveAgent : Time -> Agent -> Agent
moveAgent dT agent =
    let
        dV =
            Vector2d.scaleBy (dT / 1000) agent.velocity

        newPosition =
            Point2d.translateBy dV agent.position

        friction =
            -- how do we adjust for large/small dT?
            -- how do we increase friction nonlinearly?
            Vector2d.scaleBy (-0.001) agent.velocity

        dA =
            Vector2d.scaleBy (dT / 1000) agent.acceleration

        newVelocity =
            List.foldl Vector2d.sum
                Vector2d.zero
                [ agent.velocity, dA, friction ]
    in
        { agent | position = newPosition, velocity = newVelocity }


computeUtility : Agent -> Action -> Float
computeUtility agent action =
    List.map (computeConsideration agent) action.considerations
        |> List.foldl (+) 0


computeConsideration : Agent -> Consideration -> Float
computeConsideration agent consideration =
    let
        inputVal =
            case consideration.input of
                Hunger ->
                    0.5

                DistanceToTargetPoint point ->
                    point |> Point2d.distanceFrom agent.position

        normalizedInput =
            normalize 0 1 consideration.inputMin consideration.inputMax inputVal

        output =
            case consideration.function of
                Linear m b ->
                    Debug.crash "todo"

                Exponential exponent ->
                    Debug.crash "todo"

                Sigmoid ->
                    Debug.crash "todo"

                Normal ->
                    Debug.crash "todo"
    in
        output |> clamp 0 1


clamp : Float -> Float -> Float -> Float
clamp min max x =
    if (x < min) then
        min
    else if (x > max) then
        max
    else
        x


normalize : Float -> Float -> Float -> Float -> Float -> Float
normalize bMin bMax aMin aMax x =
    Debug.crash "todo"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ times RAFtick ]

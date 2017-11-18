module Main exposing (main)

import Html exposing (Html)
import Json.Decode as Decode
import Maybe exposing (withDefault)
import Mouse exposing (Position)
import OpenSolid.Direction2d as Direction2d
import Task exposing (perform)
import Types
    exposing
        ( Action
        , ActionOutcome(ArrestMomentum, DoNothing, MoveAwayFrom, MoveTo)
        , Agent
        , Consideration
        , ConsiderationInput(Constant, CurrentSpeed, DistanceToTargetPoint, Hunger)
        , Fire
        , InputFunction(Exponential, InverseNormal, Linear, Normal, Sigmoid)
        , Model
        , Msg(InitTime, RAFtick, ToggleConditionDetailsVisibility, ToggleConditionsVisibility)
        )
import View exposing (view)
import AnimationFrame exposing (times)
import Util exposing (mousePosToVec2)
import OpenSolid.Vector2d as Vector2d exposing (Vector2d)
import OpenSolid.Point2d as Point2d
import Time exposing (Time)
import UtilityFunctions exposing (computeUtility)


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
    ( Model 0 defaultAgents defaultFoods defaultFires
    , perform InitTime Time.now
    )


defaultFoods =
    [ { position = Point2d.fromCoordinates ( 100, 100 ) }
    ]


defaultFires =
    let
        p =
            Point2d.fromCoordinates ( -100, 100 )
    in
        [ { position = p, originalPosition = p }
        ]


defaultAgents : List Agent
defaultAgents =
    [ { name = "alf"
      , facing = Direction2d.fromAngle (degrees 70)
      , position = Point2d.fromCoordinates ( 200, 150 )
      , velocity = Vector2d.fromComponents ( -1, -10 )
      , acceleration = Vector2d.zero
      , actions =
            [ stayNearOrigin
            , moveToFood
            , justChill
            , stopAtFood
            ]
      , hunger = 0.1
      }
    , { name = "bob"
      , facing = Direction2d.fromAngle (degrees 200)
      , position = Point2d.fromCoordinates ( 100, 250 )
      , velocity = Vector2d.fromComponents ( -10, -20 )
      , acceleration = Vector2d.fromComponents ( -2, -1 )
      , actions =
            [ stayNearOrigin
            , moveToFood
            , stopAtFood
            ]
      , hunger = 0.3
      }
    ]


justChill =
    Action
        "just chill"
        DoNothing
        [ { name = "always 0.02"
          , function = Linear 1 0
          , input = Constant 0.02
          , inputMin = 0
          , inputMax = 1
          , weighting = 1
          , offset = 0
          , detailsVisible = False
          }
        ]
        False


stayNearOrigin =
    Action
        "stay within 200 or 300 units of the origin"
        (MoveTo Point2d.origin)
        [ { name = "distance from origin"
          , function = Linear 1 0
          , input = DistanceToTargetPoint Point2d.origin
          , inputMin = 200
          , inputMax = 300
          , weighting = 1
          , offset = 0
          , detailsVisible = False
          }
        ]
        False


moveToFood =
    let
        foodPoint =
            Point2d.fromCoordinates ( 100, 100 )
    in
        Action
            "move toward edible food"
            (MoveTo foodPoint)
            [ { name = "hunger"
              , function = Linear 1 0
              , input = Hunger
              , inputMin = 0
              , inputMax = 1
              , weighting = 3
              , offset = 0
              , detailsVisible = False
              }
            , { name = "too far from food item"
              , function = Exponential 4.4
              , input = DistanceToTargetPoint foodPoint
              , inputMin = 300
              , inputMax = 20
              , weighting = 0.5
              , offset = 0
              , detailsVisible = False
              }
            , { name = "in range of food item"
              , function = Exponential 0.01
              , input = DistanceToTargetPoint foodPoint
              , inputMin = 20
              , inputMax = 25
              , weighting = 1
              , offset = 0
              , detailsVisible = False
              }
            ]
            False


stopAtFood =
    let
        foodPoint =
            Point2d.fromCoordinates ( 100, 100 )
    in
        Action
            "stop when in range of edible food"
            (ArrestMomentum)
            [ { name = "in range of food item"
              , function = Exponential 0.01
              , input = DistanceToTargetPoint foodPoint
              , inputMin = 25
              , inputMax = 20
              , weighting = 1
              , offset = 0
              , detailsVisible = False
              }
            , { name = "still moving"
              , function = Linear 1 0
              , input = CurrentSpeed
              , inputMin = 0.1
              , inputMax = 0.2
              , weighting = 1
              , offset = 0
              , detailsVisible = False
              }
            ]
            False



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg ({ time, agents, foods, fires } as model) =
    case msg of
        RAFtick newT ->
            let
                dMove =
                    moveAgent <| newT - time
            in
                Model newT (List.map dMove agents) foods (List.map (moveFire newT) fires)

        InitTime t ->
            Model t agents foods fires

        ToggleConditionsVisibility agentName actionName ->
            let
                updateAgentActions actions =
                    List.map
                        (\action ->
                            if action.name == actionName then
                                { action | considerationsVisible = not action.considerationsVisible }
                            else
                                action
                        )
                        actions

                newAgents =
                    List.map
                        (\agent ->
                            if agent.name == agentName then
                                { agent | actions = updateAgentActions agent.actions }
                            else
                                agent
                        )
                        model.agents
            in
                Model time newAgents foods fires

        ToggleConditionDetailsVisibility agentName actionName considerationName ->
            let
                updateActionConsiderations =
                    List.map
                        (\consideration ->
                            if consideration.name == considerationName then
                                { consideration | detailsVisible = not consideration.detailsVisible }
                            else
                                consideration
                        )

                updateAgentActions =
                    List.map
                        (\action ->
                            if action.name == actionName then
                                { action | considerations = updateActionConsiderations action.considerations }
                            else
                                action
                        )

                newAgents =
                    List.map
                        (\agent ->
                            if agent.name == agentName then
                                { agent | actions = updateAgentActions agent.actions }
                            else
                                agent
                        )
                        model.agents
            in
                Model time newAgents foods fires


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

        movementVectors =
            List.filterMap (getMovementVector agent) agent.actions

        newAcceleration =
            List.foldl Vector2d.sum Vector2d.zero movementVectors
                |> Vector2d.normalize
                |> Vector2d.scaleBy 4

        newFacing =
            Vector2d.direction newAcceleration
                |> withDefault agent.facing
    in
        { agent
            | position = newPosition
            , velocity = newVelocity
            , acceleration = newAcceleration
            , facing = newFacing
        }


getMovementVector : Agent -> Action -> Maybe Vector2d
getMovementVector agent action =
    case action.outcome of
        MoveTo point ->
            let
                rawVector =
                    Vector2d.from agent.position point

                normalized =
                    Vector2d.normalize rawVector

                weighting =
                    computeUtility agent action

                weighted =
                    Vector2d.scaleBy weighting normalized
            in
                Just weighted

        MoveAwayFrom point ->
            let
                weighted =
                    Vector2d.from point agent.position
                        |> Vector2d.normalize
                        |> Vector2d.scaleBy weighting

                weighting =
                    computeUtility agent action
            in
                Just weighted

        ArrestMomentum ->
            let
                weighting =
                    computeUtility agent action
            in
                Just
                    (agent.velocity
                        |> Vector2d.flip
                        |> Vector2d.normalize
                        |> Vector2d.scaleBy weighting
                    )

        DoNothing ->
            Nothing


moveFire : Time -> Fire -> Fire
moveFire t fire =
    let
        newPosition =
            fire.originalPosition
                |> Point2d.rotateAround Point2d.origin (t / 3000)
    in
        { fire | position = newPosition }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ times RAFtick ]

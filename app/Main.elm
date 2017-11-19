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
        , ActionOutcome(ArrestMomentum, CallOut, DoNothing, MoveAwayFrom, MoveTo)
        , Agent
        , Consideration
        , ConsiderationInput(Constant, CurrentSpeed, CurrentlyCallingOut, DistanceToTargetPoint, Hunger, TimeSinceLastShoutedFeedMe)
        , CurrentSignal
        , Fire
        , InputFunction(Exponential, InverseNormal, Linear, Normal, Sigmoid)
        , Model
        , Msg(InitTime, RAFtick, ToggleConditionDetailsVisibility, ToggleConditionsVisibility)
        , Signal(FeedMe)
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
    [ { name = "Alf"
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
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      }
    , { name = "Bob"
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
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      }
    , { name = "Charlie"
      , facing = Direction2d.fromAngle (degrees 150)
      , position = Point2d.fromCoordinates ( -50, -50 )
      , velocity = Vector2d.fromComponents ( 0, 0 )
      , acceleration = Vector2d.fromComponents ( 0, 0 )
      , actions =
            [ justChill
            , stayNearOrigin
            , stopAtFood
            , shoutFeedMe
            ]
      , hunger = 0.8
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
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
          , detailsVisible = True
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
          , detailsVisible = True
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
              , detailsVisible = True
              }
            , { name = "too far from food item"
              , function = Exponential 4.4
              , input = DistanceToTargetPoint foodPoint
              , inputMin = 300
              , inputMax = 20
              , weighting = 0.5
              , offset = 0
              , detailsVisible = True
              }
            , { name = "in range of food item"
              , function = Exponential 0.01
              , input = DistanceToTargetPoint foodPoint
              , inputMin = 20
              , inputMax = 25
              , weighting = 1
              , offset = 0
              , detailsVisible = True
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
            ArrestMomentum
            [ { name = "in range of food item"
              , function = Exponential 0.01
              , input = DistanceToTargetPoint foodPoint
              , inputMin = 25
              , inputMax = 20
              , weighting = 1
              , offset = 0
              , detailsVisible = True
              }
            , { name = "still moving"
              , function = Linear 1 0
              , input = CurrentSpeed
              , inputMin = 0.1
              , inputMax = 0.2
              , weighting = 1
              , offset = 0
              , detailsVisible = True
              }
            ]
            False


shoutFeedMe =
    Action
        "shout \"feed me!\" "
        (CallOut FeedMe 1.0)
        [ { name = "hunger"
          , function = Sigmoid 15 0.5
          , input = Hunger
          , inputMin = 0
          , inputMax = 1
          , weighting = 1
          , offset = 0
          , detailsVisible = True
          }
        , { name = "haven't finished shouting"
          , function = Sigmoid 11 0.5
          , input = TimeSinceLastShoutedFeedMe
          , inputMin = 3000
          , inputMax = 0
          , weighting = 1
          , offset = 0.01
          , detailsVisible = True
          }
        , { name = "haven't called for food in a while"
          , function = Linear 1 0
          , input = TimeSinceLastShoutedFeedMe
          , inputMin = 6000
          , inputMax = 10000
          , weighting = 1
          , offset = 0.01
          , detailsVisible = True
          }
        ]
        True



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
                    moveAgent newT <| newT - time
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


moveAgent : Time -> Time -> Agent -> Agent
moveAgent currentTime dT agent =
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
            List.filterMap (getMovementVector currentTime agent) agent.actions

        newAcceleration =
            List.foldl Vector2d.sum Vector2d.zero movementVectors
                |> Vector2d.normalize
                |> Vector2d.scaleBy 4

        newFacing =
            Vector2d.direction newAcceleration
                |> withDefault agent.facing

        topAction =
            agent.actions
                |> List.sortBy (computeUtility agent currentTime)
                |> List.reverse
                |> List.head

        ( newFeedMeTime, newCall ) =
            Maybe.map
                (\topAct ->
                    case topAct.outcome of
                        CallOut signal intensity ->
                            case agent.callingOut of
                                Nothing ->
                                    ( Just currentTime, Just <| CurrentSignal signal currentTime )

                                Just _ ->
                                    ( agent.timeLastShoutedFeedMe, Just <| CurrentSignal signal currentTime )

                        _ ->
                            ( agent.timeLastShoutedFeedMe, Nothing )
                )
                topAction
                |> Maybe.withDefault
                    ( agent.timeLastShoutedFeedMe, Nothing )
    in
        { agent
            | position = newPosition
            , velocity = newVelocity
            , acceleration = newAcceleration
            , facing = newFacing
            , timeLastShoutedFeedMe = newFeedMeTime
            , callingOut = newCall
        }


getMovementVector : Time -> Agent -> Action -> Maybe Vector2d
getMovementVector currentTime agent action =
    case action.outcome of
        MoveTo point ->
            let
                weighted =
                    Vector2d.from agent.position point
                        |> Vector2d.normalize
                        |> Vector2d.scaleBy weighting

                weighting =
                    computeUtility agent currentTime action
            in
                Just weighted

        MoveAwayFrom point ->
            let
                weighted =
                    Vector2d.from point agent.position
                        |> Vector2d.normalize
                        |> Vector2d.scaleBy weighting

                weighting =
                    computeUtility agent currentTime action
            in
                Just weighted

        ArrestMomentum ->
            let
                weighting =
                    computeUtility agent currentTime action
            in
                Just
                    (agent.velocity
                        |> Vector2d.flip
                        |> Vector2d.normalize
                        |> Vector2d.scaleBy weighting
                    )

        DoNothing ->
            Nothing

        CallOut signal intensity ->
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

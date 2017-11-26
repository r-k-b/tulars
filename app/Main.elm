module Main exposing (main)

import Dict
import Html exposing (Html)
import Json.Decode as Decode
import Maybe exposing (withDefault)
import Mouse exposing (Position)
import OpenSolid.Direction2d as Direction2d
import Task exposing (perform)
import Types
    exposing
        ( Action
        , ActionGenerator(ActionGenerator)
        , ActionOutcome
            ( ArrestMomentum
            , CallOut
            , DoNothing
            , EatFood
            , MoveAwayFrom
            , MoveTo
            , Wander
            )
        , Agent
        , Consideration
        , ConsiderationInput
            ( Constant
            , CurrentSpeed
            , CurrentlyCallingOut
            , DistanceToTargetPoint
            , Hunger
            , TimeSinceLastShoutedFeedMe
            )
        , CurrentSignal
        , Fire
        , FireExtinguisher
        , Food
        , Holding(BothHands, EachHand, EmptyHanded, OnlyLeftHand, OnlyRightHand)
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
import UtilityFunctions exposing (computeUtility, computeVariableActions, getActions)


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
    ( Model 0 defaultAgents defaultFoods defaultFires defaultExtinguishers
    , perform InitTime Time.now
    )


defaultFoods : List Food
defaultFoods =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( -100, 100 )
            , velocity = Vector2d.zero
            , acceleration = Vector2d.zero
            }
      , joules = 3000000000
      }
    ]


defaultFires : List Fire
defaultFires =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( 100, -100 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
            , acceleration = Vector2d.zero
            }
      }
    ]


defaultExtinguishers : List FireExtinguisher
defaultExtinguishers =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( -20, -20 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
            , acceleration = Vector2d.zero
            }
      , capacity = 100
      , remaining = 100
      }
    ]


defaultAgents : List Agent
defaultAgents =
    [ { name = "Alf"
      , physics =
            { facing = Direction2d.fromAngle (degrees 70)
            , position = Point2d.fromCoordinates ( 200, 150 )
            , velocity = Vector2d.fromComponents ( -1, -10 )
            , acceleration = Vector2d.zero
            }
      , actionGenerators =
            [ moveToFood
            , stopAtFood
            , eatFood
            , avoidFire
            , maintainPersonalSpace
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ stayNearOrigin
            , justChill
            ]
      , hunger = 0.8
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      , holding = EmptyHanded
      }
    , { name = "Bob"
      , physics =
            { facing = Direction2d.fromAngle (degrees 200)
            , position = Point2d.fromCoordinates ( 100, 250 )
            , velocity = Vector2d.fromComponents ( -10, -20 )
            , acceleration = Vector2d.fromComponents ( -2, -1 )
            }
      , actionGenerators =
            [ moveToFood
            , stopAtFood
            , eatFood
            , avoidFire
            , maintainPersonalSpace
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ stayNearOrigin
            , wander
            ]
      , hunger = 0.0
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      , holding = EmptyHanded
      }
    , { name = "Charlie"
      , physics =
            { facing = Direction2d.fromAngle (degrees 150)
            , position = Point2d.fromCoordinates ( -120, -120 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
            , acceleration = Vector2d.fromComponents ( 0, 0 )
            }
      , actionGenerators =
            [ stopAtFood
            , eatFood
            , avoidFire
            , maintainPersonalSpace
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ justChill
            , stayNearOrigin
            , shoutFeedMe
            ]
      , hunger = 0.8
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      , holding = EmptyHanded
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
          }
        ]
        Dict.empty


wander =
    Action
        "wander"
        Wander
        [ { name = "always 0.04"
          , function = Linear 1 0
          , input = Constant 0.02
          , inputMin = 0
          , inputMax = 1
          , weighting = 1
          , offset = 0
          }
        ]
        Dict.empty


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
          }
        ]
        Dict.empty


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
          }
        , { name = "haven't finished shouting"
          , function = Sigmoid 11 0.5
          , input = TimeSinceLastShoutedFeedMe
          , inputMin = 3000
          , inputMax = 0
          , weighting = 1
          , offset = 0.01
          }
        , { name = "haven't called for food in a while"
          , function = Linear 1 0
          , input = TimeSinceLastShoutedFeedMe
          , inputMin = 6000
          , inputMax = 10000
          , weighting = 1
          , offset = 0.01
          }
        ]
        Dict.empty


moveToFood : ActionGenerator
moveToFood =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            List.map goalPerItem model.foods

        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("move toward edible food" |> withSuffix food.id)
                (MoveTo food.physics.position)
                [ { name = "hunger"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "too far from food item"
                  , function = Exponential 2
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 3000
                  , inputMax = 20
                  , weighting = 0.5
                  , offset = 0
                  }
                , { name = "in range of food item"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 20
                  , inputMax = 25
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "stop at food" generator


stopAtFood : ActionGenerator
stopAtFood =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            List.map goalPerItem model.foods

        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("stop when in range of edible food" |> withSuffix food.id)
                ArrestMomentum
                [ { name = "in range of food item"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 25
                  , inputMax = 20
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "still moving"
                  , function = Sigmoid 10 0.5
                  , input = CurrentSpeed
                  , inputMin = 3
                  , inputMax = 6
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "stop at food" generator


eatFood : ActionGenerator
eatFood =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            List.map goalPerItem model.foods

        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("eat meal" |> withSuffix food.id)
                (EatFood food.id)
                [ { name = "in range of meal"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 20
                  , inputMax = 19
                  , weighting = 0.8
                  , offset = -0.01
                  }
                ]
                Dict.empty
    in
        ActionGenerator "stop at food" generator


avoidFire : ActionGenerator
avoidFire =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            List.map goalPerItem model.fires

        goalPerItem : Fire -> Action
        goalPerItem fire =
            Action
                ("get away from the fire" |> withSuffix fire.id)
                (MoveAwayFrom fire.physics.position)
                [ { name = "too close to fire"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint fire.physics.position
                  , inputMin = 100
                  , inputMax = 10
                  , weighting = 3
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "avoid fire" generator


maintainPersonalSpace : ActionGenerator
maintainPersonalSpace =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            model.agents
                |> List.filter (\other -> other.name /= agent.name)
                |> List.map (goalPerItem agent)

        goalPerItem : Agent -> Agent -> Action
        goalPerItem agent otherAgent =
            Action
                ("maintain personal space from " ++ otherAgent.name)
                (MoveAwayFrom otherAgent.physics.position)
                [ { name = "space invaded"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint otherAgent.physics.position
                  , inputMin = 15
                  , inputMax = 5
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "avoid fire" generator



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg model =
    let
        { time, agents, foods, fires } =
            model
    in
        case msg of
            RAFtick newT ->
                moveWorld newT model

            InitTime t ->
                { model | time = t }

            ToggleConditionsVisibility agentName actionName ->
                let
                    updateActionVisibility viz =
                        let
                            prior =
                                Dict.get actionName viz
                                    |> Maybe.withDefault False
                        in
                            Dict.insert actionName (not prior) viz

                    newAgents =
                        List.map
                            (\agent ->
                                if agent.name == agentName then
                                    { agent | visibleActions = updateActionVisibility agent.visibleActions }
                                else
                                    agent
                            )
                            model.agents
                in
                    { model | agents = newAgents }

            ToggleConditionDetailsVisibility agentName actionName considerationName ->
                let
                    updateConsiderationVisibility viz =
                        let
                            prior =
                                Dict.get considerationName viz
                                    |> Maybe.withDefault False
                        in
                            Dict.insert considerationName (not prior) viz

                    updateAgentActions : List Action -> List Action
                    updateAgentActions list =
                        List.map
                            (\action ->
                                if action.name == actionName then
                                    { action | visibleConsiderations = updateConsiderationVisibility action.visibleConsiderations }
                                else
                                    action
                            )
                            list

                    newAgents =
                        List.map
                            (\agent ->
                                if agent.name == agentName then
                                    { agent
                                        | constantActions = updateAgentActions agent.constantActions
                                        , variableActions = updateAgentActions agent.variableActions
                                    }
                                else
                                    agent
                            )
                            model.agents
                in
                    { model | agents = newAgents }


moveAgent : Model -> Time -> Time -> Agent -> Agent
moveAgent model currentTime dT agent =
    let
        dV =
            Vector2d.scaleBy (dT / 1000) agent.physics.velocity

        newPosition =
            Point2d.translateBy dV agent.physics.position

        newVelocity =
            -- how do we adjust for large/small dT?
            agent.physics.velocity
                |> applyFriction
                |> Vector2d.sum deltaAcceleration

        deltaAcceleration =
            Vector2d.scaleBy (dT / 1000) agent.physics.acceleration

        topMovementActionIsArrestMomentum =
            getActions agent
                |> List.filter isMovementAction
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head
                |> Maybe.andThen onlyArrestMomentum

        movementVectors =
            case topMovementActionIsArrestMomentum of
                Just arrestMomentumAction ->
                    getMovementVector currentTime dT agent arrestMomentumAction
                        |> Maybe.map List.singleton
                        |> Maybe.withDefault []

                Nothing ->
                    List.filterMap (getMovementVector currentTime dT agent) (getActions agent)

        newAcceleration =
            List.foldl Vector2d.sum Vector2d.zero movementVectors
                |> Vector2d.normalize
                |> Vector2d.scaleBy 64

        newFacing =
            Vector2d.direction newAcceleration
                |> withDefault agent.physics.facing

        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
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

        newHunger =
            agent.hunger
                + 0.000003
                * dT
                |> clamp 0 1

        newPhysics =
            let
                p =
                    agent.physics
            in
                { p
                    | position = newPosition
                    , velocity = newVelocity
                    , acceleration = newAcceleration
                    , facing = newFacing
                }
    in
        { agent
            | physics = newPhysics
            , timeLastShoutedFeedMe = newFeedMeTime
            , callingOut = newCall
            , hunger = newHunger
        }


getMovementVector : Time -> Time -> Agent -> Action -> Maybe Vector2d
getMovementVector currentTime deltaTime agent action =
    case action.outcome of
        MoveTo point ->
            let
                weighted =
                    Vector2d.from agent.physics.position point
                        |> Vector2d.normalize
                        |> Vector2d.scaleBy weighting

                weighting =
                    computeUtility agent currentTime action
            in
                Just weighted

        MoveAwayFrom point ->
            let
                weighted =
                    Vector2d.from point agent.physics.position
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
                case weighting < 0.1 of
                    True ->
                        Nothing

                    False ->
                        Just
                            (agent.physics.velocity
                                |> Vector2d.flip
                                |> Vector2d.normalize
                                |> Vector2d.scaleBy weighting
                            )

        Wander ->
            let
                weighting =
                    computeUtility agent currentTime action
            in
                agent.physics.facing
                    |> Direction2d.toVector
                    |> Vector2d.rotateBy (degrees 10 * (deltaTime / 1000))
                    |> Just

        DoNothing ->
            Nothing

        CallOut signal intensity ->
            Nothing

        EatFood _ ->
            Nothing


isMovementAction : Action -> Bool
isMovementAction action =
    case action.outcome of
        ArrestMomentum ->
            True

        MoveTo _ ->
            True

        MoveAwayFrom _ ->
            True

        Wander ->
            True

        DoNothing ->
            False

        CallOut _ _ ->
            False

        EatFood _ ->
            False


onlyArrestMomentum : Action -> Maybe Action
onlyArrestMomentum action =
    case action.outcome of
        ArrestMomentum ->
            Just action

        _ ->
            Nothing


{-| Scales a vector, representing how much speed is lost to friction.
-}
applyFriction : Vector2d -> Vector2d
applyFriction velocity =
    let
        speed =
            Vector2d.length velocity

        t =
            1.1

        u =
            0.088

        n =
            30

        k =
            0.26

        -- \frac{1}{e^{k\left(x-n\right)}+t}+u\ \left\{0\le x\right\}
        -- see https://www.desmos.com/calculator/7i2gwxpej1
        factor =
            (1 / (e ^ (k * (speed - n)) + t) + u)
    in
        case speed < 0.1 of
            True ->
                Vector2d.zero

            False ->
                velocity |> Vector2d.scaleBy factor


recomputeActions : Model -> Agent -> Agent
recomputeActions model agent =
    let
        newActions =
            computeVariableActions model agent
                |> List.map preserveProperties

        preservableProperties : Dict.Dict String (Dict.Dict String Bool)
        preservableProperties =
            agent.variableActions
                |> List.map (\action -> ( action.name, action.visibleConsiderations ))
                |> Dict.fromList

        preserveProperties : Action -> Action
        preserveProperties action =
            let
                oldVCs =
                    Dict.get action.name preservableProperties
                        |> Maybe.withDefault Dict.empty
            in
                { action | visibleConsiderations = oldVCs }
    in
        { agent | variableActions = newActions }


withSuffix : Int -> String -> String
withSuffix id s =
    s ++ " (#" ++ toString id ++ ")"


moveWorld : Time -> Model -> Model
moveWorld newTime model =
    let
        deltaT =
            newTime - model.time

        newAgents =
            let
                dMove =
                    (moveAgent model newTime deltaT)
                        >> (recomputeActions model)
            in
                List.map dMove model.agents

        afterEating : Model
        afterEating =
            model.agents
                |> List.filterMap (isEating model.time)
                |> List.foldl eat model

        newFoods =
            afterEating.foods
                |> List.filterMap (rotFood deltaT)
    in
        { model
            | time = newTime
            , foods = newFoods
            , agents = newAgents
        }


isEating : Time -> Agent -> Maybe ( String, Int )
isEating currentTime agent =
    let
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head
                |> Maybe.map .outcome
    in
        case topAction of
            Just (EatFood foodID) ->
                Just ( agent.name, foodID )

            _ ->
                Nothing


eat : ( String, Int ) -> Model -> Model
eat ( agentName, foodID ) model =
    let
        isTargeted =
            .id >> (==) foodID

        foodAvailable : Bool
        foodAvailable =
            List.any isTargeted model.foods

        isAvailable =
            .name >> (==) agentName

        agentAvailable : Bool
        agentAvailable =
            List.any isAvailable model.agents

        bite : Food -> Food
        bite food =
            if (food |> isTargeted) && agentAvailable then
                { food | joules = food.joules - 20000000 }
            else
                food

        swallow : Agent -> Agent
        swallow agent =
            if (agent |> isAvailable) && foodAvailable then
                { agent | hunger = agent.hunger - 0.2 |> clamp 0 1 }
            else
                agent

        newFoods =
            model.foods
                |> List.map bite

        newAgents =
            model.agents
                |> List.map swallow
    in
        { model | foods = newFoods, agents = newAgents }


rotFood : Time -> Food -> Maybe Food
rotFood deltaT food =
    let
        newJoules =
            food.joules - deltaT * 20000
    in
        if newJoules <= 0 then
            Nothing
        else
            Just { food | joules = newJoules }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ times RAFtick ]

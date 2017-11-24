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
        , ActionGenerator
        , ActionGeneratorList(ActionGeneratorList)
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
        , Food
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
    ( Model 0 defaultAgents defaultFoods defaultFires
    , perform InitTime Time.now
    )


defaultFoods =
    [ { id = 1
      , position = Point2d.fromCoordinates ( -100, 100 )
      , joules = 3000000000
      }
    ]


defaultFires =
    let
        p =
            Point2d.fromCoordinates ( -100, 100 )

        p2 =
            Point2d.fromCoordinates ( -100, -100 )
    in
        [ { id = 1, position = p, originalPosition = p }
        , { id = 2, position = p2, originalPosition = p2 }
        ]


defaultAgents : List Agent
defaultAgents =
    [ { name = "Alf"
      , facing = Direction2d.fromAngle (degrees 70)
      , position = Point2d.fromCoordinates ( 200, 150 )
      , velocity = Vector2d.fromComponents ( -1, -10 )
      , acceleration = Vector2d.zero
      , actionGenerators =
            ActionGeneratorList
                [ moveToFood
                , stopAtFood
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
      }
    , { name = "Bob"
      , facing = Direction2d.fromAngle (degrees 200)
      , position = Point2d.fromCoordinates ( 100, 250 )
      , velocity = Vector2d.fromComponents ( -10, -20 )
      , acceleration = Vector2d.fromComponents ( -2, -1 )
      , actionGenerators =
            ActionGeneratorList
                [ moveToFood
                , stopAtFood
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
      }
    , { name = "Charlie"
      , facing = Direction2d.fromAngle (degrees 150)
      , position = Point2d.fromCoordinates ( -120, -120 )
      , velocity = Vector2d.fromComponents ( 0, 0 )
      , acceleration = Vector2d.fromComponents ( 0, 0 )
      , actionGenerators =
            ActionGeneratorList
                [ stopAtFood
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
    let
        foodPoint =
            Point2d.fromCoordinates ( 100, 100 )
    in
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
            , { name = "in range of food item"
              , function = Exponential 0.01
              , input = DistanceToTargetPoint foodPoint
              , inputMin = 24
              , inputMax = 25
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
                (MoveTo food.position)
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
                  , input = DistanceToTargetPoint food.position
                  , inputMin = 3000
                  , inputMax = 20
                  , weighting = 0.5
                  , offset = 0
                  }
                , { name = "in range of food item"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint food.position
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
                  , input = DistanceToTargetPoint food.position
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
                  , input = DistanceToTargetPoint food.position
                  , inputMin = 19
                  , inputMax = 20
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
                (MoveAwayFrom fire.position)
                [ { name = "too close to fire"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint fire.position
                  , inputMin = 200
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
                (MoveAwayFrom otherAgent.position)
                [ { name = "space invaded"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint otherAgent.position
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
                let
                    dMove =
                        (moveAgent model newT <| newT - time)
                            >> (recomputeActions model)
                in
                    Model time (List.map dMove agents) foods (List.map (moveFire newT) fires)
                        |> moveWorld newT

            InitTime t ->
                Model t agents foods fires

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
                    Model time newAgents foods fires

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
                    Model time newAgents foods fires


moveAgent : Model -> Time -> Time -> Agent -> Agent
moveAgent model currentTime dT agent =
    let
        dV =
            Vector2d.scaleBy (dT / 1000) agent.velocity

        newPosition =
            Point2d.translateBy dV agent.position

        newVelocity =
            -- how do we adjust for large/small dT?
            agent.velocity
                |> applyFriction
                |> Vector2d.sum deltaAcceleration

        deltaAcceleration =
            Vector2d.scaleBy (dT / 1000) agent.acceleration

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
                |> withDefault agent.facing

        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
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

        newHunger =
            agent.hunger
                + 0.000003
                * dT
                |> clamp 0 1
    in
        { agent
            | position = newPosition
            , velocity = newVelocity
            , acceleration = newAcceleration
            , facing = newFacing
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
                case weighting < 0.1 of
                    True ->
                        Nothing

                    False ->
                        Just
                            (agent.velocity
                                |> Vector2d.flip
                                |> Vector2d.normalize
                                |> Vector2d.scaleBy weighting
                            )

        Wander ->
            let
                weighting =
                    computeUtility agent currentTime action
            in
                agent.facing
                    |> Direction2d.toVector
                    |> Vector2d.rotateBy (degrees 10 * (deltaTime / 1000))
                    |> Just

        DoNothing ->
            Nothing

        CallOut signal intensity ->
            Nothing

        EatFood _ ->
            Nothing


moveFire : Time -> Fire -> Fire
moveFire t fire =
    let
        newPosition =
            fire.originalPosition
                |> Point2d.rotateAround Point2d.origin (t / 3000)
    in
        { fire | position = newPosition }


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

        newFoods =
            model.foods
                |> List.filterMap (rotFood deltaT)
    in
        { model
            | time = newTime
            , foods = newFoods
        }


rotFood : Time -> Food -> Maybe Food
rotFood deltaT food =
    let
        newJoules =
            food.joules - deltaT * 200000
    in
        if newJoules <= 0 then
            Nothing
        else
            Just { food | joules = newJoules }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ times RAFtick ]

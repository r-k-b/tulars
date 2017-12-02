module Main exposing (main)

import Dict exposing (Dict)
import Html
import Maybe exposing (withDefault)
import Task exposing (perform)
import Types
    exposing
        ( Action
        , ActionOutcome
            ( ArrestMomentum
            , BeggingForFood
            , CallOut
            , DoNothing
            , DropHeldFood
            , EatHeldFood
            , MoveAwayFrom
            , MoveTo
            , PickUpFood
            , Wander
            )
        , Agent
        , CurrentSignal
        , Food
        , Holding(BothHands, EachHand, EmptyHanded, OnlyLeftHand, OnlyRightHand)
        , Model
        , Msg(InitTime, RAFtick, ToggleConditionDetailsVisibility, ToggleConditionsVisibility)
        , Portable(Edible)
        , Signal(Bored, Eating, FeedMe, GoAway)
        )
import View exposing (view)
import AnimationFrame exposing (times)
import OpenSolid.Direction2d as Direction2d
import OpenSolid.Point2d as Point2d
import OpenSolid.Vector2d as Vector2d exposing (Vector2d)
import Time exposing (Time)
import UtilityFunctions
    exposing
        ( computeUtility
        , computeVariableActions
        , getActions
        , isBeggingRelated
        , isMovementAction
        , onlyArrestMomentum
        , signalsDesireToEat
        )
import DefaultData


main : Program Never Model Msg
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
    ( Model (0 / 0) DefaultData.agents DefaultData.foods DefaultData.fires DefaultData.extinguishers
    , perform InitTime Time.now
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg model =
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
                                |> withDefault False
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
                                |> withDefault False
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


moveAgent : Time -> Time -> Agent -> Agent
moveAgent currentTime dT agent =
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
                        |> withDefault []

                Nothing ->
                    List.filterMap (getMovementVector currentTime dT agent) (getActions agent)

        newAcceleration =
            List.foldl Vector2d.sum Vector2d.zero movementVectors
                |> deadzone
                |> Vector2d.normalize
                |> Vector2d.scaleBy 64

        newFacing =
            Vector2d.direction newAcceleration
                |> withDefault agent.physics.facing

        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head

        newOutcome =
            topAction
                |> Maybe.map .outcome
                |> Maybe.map outcomeToString
                |> withDefault "none"

        newtopActionLastStartTimes : Dict String Time
        newtopActionLastStartTimes =
            if newOutcome == agent.currentOutcome then
                agent.topActionLastStartTimes
            else
                agent.topActionLastStartTimes
                    |> Dict.insert newOutcome currentTime

        newCall : Maybe CurrentSignal
        newCall =
            topAction
                |> Maybe.andThen extractCallouts
                |> updateCurrentSignal currentTime agent.callingOut

        increasedHunger =
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

        desireToEat =
            topAction
                |> Maybe.map signalsDesireToEat
                |> withDefault False

        beggingForFood =
            topAction
                |> Maybe.andThen isBeggingRelated
                |> withDefault agent.beggingForFood

        ( newHunger, newHolding ) =
            if desireToEat then
                agent |> eat
            else
                ( increasedHunger, agent.holding )
    in
        { agent
            | physics = newPhysics
            , topActionLastStartTimes = newtopActionLastStartTimes
            , callingOut = newCall
            , hunger = newHunger
            , currentAction = topAction |> Maybe.map .name |> withDefault "none"
            , currentOutcome = newOutcome
            , desireToEat = desireToEat
            , holding = newHolding
            , beggingForFood = beggingForFood
        }


extractCallouts : Action -> Maybe Signal
extractCallouts action =
    case action.outcome of
        CallOut x _ ->
            Just x

        _ ->
            Nothing


{-| If the signal type is unchanged, preserve the original time.
-}
updateCurrentSignal : Time -> Maybe CurrentSignal -> Maybe Signal -> Maybe CurrentSignal
updateCurrentSignal time currentSignal maybeNewSignal =
    case maybeNewSignal of
        Nothing ->
            Nothing

        Just newSignal ->
            case currentSignal of
                Nothing ->
                    Just { signal = newSignal, started = time }

                Just priorSignal ->
                    if priorSignal.signal == newSignal then
                        Just priorSignal
                    else
                        Just { signal = newSignal, started = time }


deadzone : Vector2d -> Vector2d
deadzone v =
    if Vector2d.length v > 0.005 then
        v
    else
        Vector2d.zero


getMovementVector : Time -> Time -> Agent -> Action -> Maybe Vector2d
getMovementVector currentTime deltaTime agent action =
    case action.outcome of
        MoveTo _ point ->
            let
                weighted =
                    Vector2d.from agent.physics.position point
                        |> Vector2d.normalize
                        |> Vector2d.scaleBy weighting

                weighting =
                    computeUtility agent currentTime action
            in
                Just weighted

        MoveAwayFrom _ point ->
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
            agent.physics.facing
                |> Direction2d.toVector
                |> Vector2d.rotateBy (degrees 10 * (deltaTime / 1000))
                |> Just

        DoNothing ->
            Nothing

        CallOut _ _ ->
            Nothing

        PickUpFood _ ->
            Nothing

        EatHeldFood ->
            Nothing

        DropHeldFood ->
            Nothing

        BeggingForFood _ ->
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
            1 / (e ^ (k * (speed - n)) + t) + u
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
                        |> withDefault Dict.empty
            in
                { action | visibleConsiderations = oldVCs }
    in
        { agent | variableActions = newActions }


moveWorld : Time -> Model -> Model
moveWorld newTime model =
    let
        deltaT =
            newTime - model.time

        newAgents =
            let
                dMove =
                    moveAgent newTime deltaT
                        >> recomputeActions model
            in
                List.map dMove model.agents

        foodsAfterDecay =
            model.foods
                |> List.filterMap (rotFood deltaT)

        ( agentsAfterPickingUpFood, pickedFood ) =
            List.foldr
                (foldOverPickedFood newTime)
                ( [], foodsAfterDecay )
                newAgents
    in
        { model
            | time = newTime
            , foods = pickedFood
            , agents = agentsAfterPickingUpFood
        }


foldOverPickedFood : Time -> Agent -> ( List Agent, List Food ) -> ( List Agent, List Food )
foldOverPickedFood currentTime agent ( agentAcc, foodAcc ) =
    let
        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head

        ( updatedAgent, updatedFoods ) =
            case topAction of
                Nothing ->
                    ( agent, foodAcc )

                Just action ->
                    case action.outcome of
                        PickUpFood foodID ->
                            pickUpFood agent foodID foodAcc

                        _ ->
                            ( agent, foodAcc )
    in
        ( updatedAgent :: agentAcc, updatedFoods )


pickUpFood : Agent -> Int -> List Food -> ( Agent, List Food )
pickUpFood agent foodID foods =
    let
        foodIsAvailable : Food -> Bool
        foodIsAvailable food =
            food.id == foodID

        foodAvailable : Bool
        foodAvailable =
            foods |> List.any foodIsAvailable

        agentIsAvailable : Bool
        agentIsAvailable =
            case agent.holding of
                EmptyHanded ->
                    True

                OnlyLeftHand _ ->
                    False

                OnlyRightHand _ ->
                    False

                EachHand _ _ ->
                    False

                BothHands _ ->
                    False

        pickup : Food -> Maybe Food
        pickup food =
            if (food |> foodIsAvailable) && agentIsAvailable then
                Nothing
            else
                Just food

        newFoods =
            foods |> List.filterMap pickup

        carry : Agent
        carry =
            if agentIsAvailable && foodAvailable then
                case foods |> List.head of
                    Nothing ->
                        agent

                    Just food ->
                        { agent | holding = OnlyRightHand (Edible food) }
            else
                agent
    in
        ( carry, newFoods )


eat : Agent -> ( Float, Holding )
eat agent =
    let
        someFood : Portable -> Bool
        someFood p =
            case p of
                Edible _ ->
                    True

                _ ->
                    False
    in
        if agent |> isHolding someFood then
            ( agent.hunger - 1 |> clamp 0 1
            , agent.holding |> mapHeld biteFood
            )
        else
            ( agent.hunger, agent.holding )


biteFood : Portable -> Maybe Portable
biteFood p =
    case p of
        Edible food ->
            let
                newJoules =
                    food.joules - 1000
            in
                if newJoules <= 0 then
                    Nothing
                else
                    Just <| Edible { food | joules = newJoules }

        _ ->
            Just p


isHolding : (Portable -> Bool) -> Agent -> Bool
isHolding f agent =
    case agent.holding of
        EmptyHanded ->
            False

        OnlyLeftHand p ->
            f p

        OnlyRightHand p ->
            f p

        EachHand pL pR ->
            f pL || f pR

        BothHands p ->
            f p


mapHeld : (Portable -> Maybe Portable) -> Holding -> Holding
mapHeld f held =
    case held of
        EmptyHanded ->
            EmptyHanded

        OnlyLeftHand p ->
            f p
                |> Maybe.map OnlyLeftHand
                |> withDefault EmptyHanded

        OnlyRightHand p ->
            f p
                |> Maybe.map OnlyLeftHand
                |> withDefault EmptyHanded

        EachHand pL pR ->
            let
                left =
                    f pL

                right =
                    f pR
            in
                case ( left, right ) of
                    ( Nothing, Nothing ) ->
                        EmptyHanded

                    ( Just newPL, Nothing ) ->
                        OnlyLeftHand newPL

                    ( Nothing, Just newPR ) ->
                        OnlyRightHand newPR

                    ( Just newPL, Just newPR ) ->
                        EachHand newPL newPR

        BothHands p ->
            f p
                |> Maybe.map BothHands
                |> withDefault EmptyHanded


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


outcomeToString : ActionOutcome -> String
outcomeToString outcome =
    case outcome of
        DoNothing ->
            "DoNothing"

        MoveTo desc _ ->
            "MoveTo(" ++ desc ++ ")"

        MoveAwayFrom desc _ ->
            "MoveAwayFrom(" ++ desc ++ ")"

        ArrestMomentum ->
            "ArrestMomentum"

        CallOut signal _ ->
            "CallOut(" ++ signalToString signal ++ ")"

        Wander ->
            "Wander"

        PickUpFood id ->
            "PickUpFood(id#" ++ toString id ++ ")"

        EatHeldFood ->
            "EatHeldFood"

        DropHeldFood ->
            "DropHeldFood"

        BeggingForFood bool ->
            "BeggingForFood(" ++ toString bool ++ ")"


signalToString : Signal -> String
signalToString signal =
    case signal of
        FeedMe ->
            "FeedMe"

        GoAway ->
            "GoAway"

        Eating ->
            "Eating"

        Bored ->
            "Bored"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [ times RAFtick ]

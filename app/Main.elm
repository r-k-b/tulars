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
            , PickUp
            , ShootExtinguisher
            , Wander
            )
        , Agent
        , Collision
        , CurrentSignal
        , Fire
        , FireExtinguisher
        , Food
        , Hitpoints(Hitpoints)
        , Holding(BothHands, EmptyHanded)
        , Model
        , Msg(InitTime, RAFtick, ToggleConditionDetailsVisibility, ToggleConditionsVisibility)
        , Physical
        , PhysicalProperties
        , Portable(Edible, Extinguisher)
        , ReferenceToPortable(EdibleID, ExtinguisherID)
        , Retardant
        , Signal(Bored, Eating, FeedMe, GoAway)
        )
import View exposing (view)
import AnimationFrame exposing (times)
import OpenSolid.Direction2d as Direction2d
import OpenSolid.Point2d as Point2d
import OpenSolid.Vector2d as Vector2d exposing (Vector2d)
import Time exposing (Time, inMilliseconds, second)
import UtilityFunctions
    exposing
        ( computeUtility
        , computeVariableActions
        , getActions
        , isBeggingRelated
        , isMovementAction
        , onlyArrestMomentum
        )
import DefaultData as DD exposing (retardantRadius)
import MapAccumulate exposing (mapAccumL)
import Maybe.Extra
import Physics exposing (collide)
import List exposing (map)
import Set exposing (insert)


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
    ( Model (0 / 0) DD.agents DD.foods DD.fires DD.extinguishers []
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
                    map
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
                    map
                        (\action ->
                            if action.name == actionName then
                                { action
                                    | visibleConsiderations =
                                        updateConsiderationVisibility action.visibleConsiderations
                                }
                            else
                                action
                        )
                        list

                newAgents =
                    map
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


moveProjectiles : Time -> List (Physical a) -> List (Physical a)
moveProjectiles dTime projectiles =
    map (doPhysics dTime) projectiles


{-| todo: use verlet integration?
-}
doPhysics : Time -> Physical a -> Physical a
doPhysics deltaTime x =
    let
        p =
            x.physics

        dV =
            Vector2d.scaleBy (deltaTime / 1000) p.velocity

        newPosition =
            Point2d.translateBy dV p.position

        newVelocity =
            Vector2d.sum p.velocity p.acceleration

        updatedPhysics =
            { position = newPosition
            , facing = p.facing
            , velocity = newVelocity
            , acceleration = p.acceleration
            , radius = p.radius
            }
    in
        { x | physics = updatedPhysics }


moveAgent : Time -> Time -> Agent -> Agent
moveAgent currentTime dT agent =
    let
        dV =
            Vector2d.scaleBy ((dT |> min 1000) / 1000) agent.physics.velocity

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

        hitpointsAfterStarvation =
            case agent.hp of
                Hitpoints current max ->
                    if agent.hunger > 0.5 then
                        Hitpoints ((current - 0.001 * dT) |> clamp 0 max) max
                    else
                        Hitpoints current max

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

        beggingForFood =
            topAction
                |> Maybe.andThen isBeggingRelated
                |> withDefault agent.beggingForFood

        ( newHunger, newHolding ) =
            if
                topAction
                    |> Maybe.map (.outcome >> (==) EatHeldFood)
                    |> withDefault False
            then
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
            , holding = newHolding
            , beggingForFood = beggingForFood
            , hp = hitpointsAfterStarvation
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

        PickUp _ ->
            Nothing

        EatHeldFood ->
            Nothing

        DropHeldFood ->
            Nothing

        BeggingForFood _ ->
            Nothing

        ShootExtinguisher _ ->
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


regenerateVariableActions : Model -> Agent -> Agent
regenerateVariableActions model agent =
    let
        newActions =
            computeVariableActions model agent
                |> map preserveProperties

        preservableProperties : Dict.Dict String (Dict.Dict String Bool)
        preservableProperties =
            agent.variableActions
                |> map (\action -> ( action.name, action.visibleConsiderations ))
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

        movedAgents =
            model.agents
                |> map (moveAgent newTime deltaT >> regenerateVariableActions model)

        newRetardants : List Retardant
        newRetardants =
            List.foldr
                (createRetardantProjectiles newTime)
                []
                movedAgents

        retardantsWithDecay : List Retardant
        retardantsWithDecay =
            model.retardants
                |> moveProjectiles deltaT
                |> List.filterMap (decayRetardant newTime)
                |> (++) newRetardants

        ( retardantsAfterCollisionWithFire, firesAfterCollisionWithRetardants ) =
            List.foldr
                collideRetardantsAndFires
                ( [], model.fires )
                retardantsWithDecay

        foodsAfterDecay =
            model.foods
                |> List.filterMap (rotFood deltaT)

        ( agentsAfterPickingUpFood, pickedFood, pickedExtinguishers ) =
            List.foldr
                (foldOverPickedItems newTime)
                ( [], foodsAfterDecay, model.extinguishers )
                movedAgents

        ( agentsAfterDroppingFood, includingDroppedFood ) =
            List.foldr
                (foldOverDroppedFood newTime)
                ( [], pickedFood )
                agentsAfterPickingUpFood
    in
        { model
            | time = newTime
            , foods = includingDroppedFood
            , agents = agentsAfterDroppingFood
            , extinguishers = pickedExtinguishers
            , retardants = retardantsAfterCollisionWithFire
            , fires = firesAfterCollisionWithRetardants
        }


createRetardantProjectiles : Time -> Agent -> List Retardant -> List Retardant
createRetardantProjectiles currentTime agent acc =
    let
        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head
    in
        case topAction of
            Nothing ->
                acc

            Just action ->
                case action.outcome of
                    ShootExtinguisher direction ->
                        { expiry = currentTime + 1 * second
                        , physics =
                            { facing = direction
                            , position = agent.physics.position
                            , velocity =
                                direction
                                    |> Direction2d.toVector
                                    |> Vector2d.scaleBy 100
                                    |> Vector2d.rotateBy (currentTime |> angleFuzz 0.8)
                            , acceleration = Vector2d.zero
                            , radius = retardantRadius
                            }
                        }
                            :: acc

                    _ ->
                        acc


foldOverPickedItems :
    Time
    -> Agent
    -> ( List Agent, List Food, List FireExtinguisher )
    -> ( List Agent, List Food, List FireExtinguisher )
foldOverPickedItems currentTime agent ( agentAcc, foodAcc, extinguisherAcc ) =
    let
        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head

        ( updatedAgent, updatedFoods, updatedExtinguishers ) =
            let
                noChange =
                    ( agent, foodAcc, extinguisherAcc )
            in
                case topAction of
                    Nothing ->
                        noChange

                    Just action ->
                        case action.outcome of
                            PickUp (EdibleID foodID) ->
                                let
                                    ( a, f ) =
                                        pickUpFood agent foodID foodAcc
                                in
                                    ( a, f, extinguisherAcc )

                            PickUp (ExtinguisherID fextID) ->
                                let
                                    ( a, e ) =
                                        pickUpExtinguisher agent fextID extinguisherAcc
                                in
                                    ( a, foodAcc, e )

                            DoNothing ->
                                noChange

                            MoveTo _ _ ->
                                noChange

                            MoveAwayFrom _ _ ->
                                noChange

                            ArrestMomentum ->
                                noChange

                            CallOut _ _ ->
                                noChange

                            Wander ->
                                noChange

                            EatHeldFood ->
                                noChange

                            DropHeldFood ->
                                noChange

                            BeggingForFood _ ->
                                noChange

                            ShootExtinguisher _ ->
                                noChange
    in
        ( updatedAgent :: agentAcc, updatedFoods, updatedExtinguishers )


foldOverDroppedFood : Time -> Agent -> ( List Agent, List Food ) -> ( List Agent, List Food )
foldOverDroppedFood currentTime agent ( agentAcc, foodAcc ) =
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
                        DropHeldFood ->
                            dropFood agent foodAcc

                        _ ->
                            ( agent, foodAcc )
    in
        ( updatedAgent :: agentAcc, updatedFoods )


pickUpFood : Agent -> Int -> List Food -> ( Agent, List Food )
pickUpFood agent foodID foods =
    let
        targetIsAvailable : Food -> Bool
        targetIsAvailable food =
            food.id == foodID

        foodAvailable : Bool
        foodAvailable =
            foods |> List.any targetIsAvailable

        agentIsAvailable : Bool
        agentIsAvailable =
            case agent.holding of
                EmptyHanded ->
                    True

                BothHands _ ->
                    False

        pickup : Food -> Maybe Food
        pickup food =
            if (food |> targetIsAvailable) && agentIsAvailable then
                Nothing
            else
                Just food

        newFoods =
            List.filterMap pickup foods

        carry : Agent
        carry =
            if agentIsAvailable && foodAvailable then
                case foods |> List.head of
                    Nothing ->
                        agent

                    Just food ->
                        { agent | holding = BothHands (Edible food) }
            else
                agent
    in
        ( carry, newFoods )


{-| -- todo: implement hitpoints
-}
collideRetardantAndFire : Fire -> Maybe Retardant -> ( Maybe Fire, Maybe Retardant )
collideRetardantAndFire fire mretardant =
    let
        noChange =
            ( Just fire, mretardant )
    in
        case mretardant of
            Nothing ->
                noChange

            Just retardant ->
                let
                    collisionResult : Collision
                    collisionResult =
                        collide retardant fire
                in
                    if collisionResult.penetration > 0 then
                        let
                            updatedHP =
                                fire.hp - 0.3

                            updatedFire =
                                if updatedHP < 0 then
                                    Nothing
                                else
                                    Just { fire | hp = updatedHP }
                        in
                            ( updatedFire
                            , Nothing
                            )
                    else
                        noChange


collideRetardantAndFires : Retardant -> List Fire -> ( List Fire, Maybe Retardant )
collideRetardantAndFires ret fires =
    mapAccumL collideRetardantAndFire (Just ret) fires
        |> justSomethings


collideRetardantsAndFires :
    Retardant
    -> ( List Retardant, List Fire )
    -> ( List Retardant, List Fire )
collideRetardantsAndFires retardant ( retardantAcc, fires ) =
    let
        ( updatedFires, updatedRetardant ) =
            collideRetardantAndFires retardant fires
    in
        case updatedRetardant of
            Just ret ->
                ( ret :: retardantAcc, updatedFires )

            Nothing ->
                ( retardantAcc, updatedFires )


pickUpExtinguisher : Agent -> Int -> List FireExtinguisher -> ( Agent, List FireExtinguisher )
pickUpExtinguisher agent fextID extinguishers =
    let
        targetIsAvailable : FireExtinguisher -> Bool
        targetIsAvailable fext =
            fext.id == fextID

        targetAvailable : Bool
        targetAvailable =
            extinguishers |> List.any targetIsAvailable

        agentIsAvailable : Bool
        agentIsAvailable =
            case agent.holding of
                EmptyHanded ->
                    True

                BothHands _ ->
                    False

        pickup : FireExtinguisher -> Maybe FireExtinguisher
        pickup fext =
            if (fext |> targetIsAvailable) && agentIsAvailable then
                Nothing
            else
                Just fext

        newTargets =
            List.filterMap pickup extinguishers

        carry : Agent
        carry =
            if agentIsAvailable && targetAvailable then
                case extinguishers |> List.head of
                    Nothing ->
                        agent

                    Just fext ->
                        { agent | holding = BothHands (Extinguisher fext) }
            else
                agent
    in
        ( carry, newTargets )


dropFood : Agent -> List Food -> ( Agent, List Food )
dropFood agent extantFoods =
    let
        droppedFoods : List Food
        droppedFoods =
            map (usePhysics agent.physics) <|
                case agent.holding of
                    EmptyHanded ->
                        []

                    BothHands (Edible x) ->
                        [ x ]

                    BothHands _ ->
                        []

        foodsGivenAway =
            case droppedFoods of
                [ food ] ->
                    agent.foodsGivenAway |> insert food.id

                _ ->
                    -- this won't be correct if we can drop multiple foods
                    agent.foodsGivenAway

        sansFood : Holding
        sansFood =
            mapHeld unhandHeldFood agent.holding
    in
        ( { agent
            | holding = sansFood
            , foodsGivenAway = foodsGivenAway
          }
        , List.append extantFoods droppedFoods
        )


unhandHeldFood : Portable -> Maybe Portable
unhandHeldFood portable =
    case portable of
        Edible _ ->
            Nothing

        _ ->
            Just portable


usePhysics : PhysicalProperties -> Physical a -> Physical a
usePhysics newPhysics target =
    { target | physics = newPhysics }


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

        BothHands p ->
            f p


mapHeld : (Portable -> Maybe Portable) -> Holding -> Holding
mapHeld f held =
    case held of
        EmptyHanded ->
            EmptyHanded

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

        PickUp (ExtinguisherID id) ->
            "PickUpExtinguisher(id#" ++ toString id ++ ")"

        PickUp (EdibleID id) ->
            "PickUpFood(id#" ++ toString id ++ ")"

        EatHeldFood ->
            "EatHeldFood"

        DropHeldFood ->
            "DropHeldFood"

        BeggingForFood bool ->
            "BeggingForFood(" ++ toString bool ++ ")"

        ShootExtinguisher direction ->
            "ShootExtinguisher(" ++ toString direction ++ ")"


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


decayRetardant : Time -> Retardant -> Maybe Retardant
decayRetardant currentTime ret =
    if currentTime > ret.expiry then
        Nothing
    else
        Just ret


angleFuzz : Float -> Time -> Float
angleFuzz spread timeFloat =
    let
        time =
            timeFloat |> inMilliseconds |> floor
    in
        ((time * 43993 % 4919 |> toFloat) / 4919 - 0.5) * spread


justSomethings : ( List (Maybe a), b ) -> ( List a, b )
justSomethings =
    \( list, b ) -> ( list |> Maybe.Extra.values, b )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [ times RAFtick ]

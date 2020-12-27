module UtilityFunctions exposing
    ( boolString
    , clampTo
    , computeConsideration
    , computeUtility
    , computeVariableActions
    , differenceInMillis
    , getActions
    , getConsiderationRawValue
    , hpAsFloat
    , hpRawValue
    , isBeggingRelated
    , isHolding
    , isMovementAction
    , isReadyToPlant
    , linearTransform
    , log
    , mapRange
    , normaliseRange
    , onlyArrestMomentum
    , rangeCurrentValue
    , setHitpoints
    , updateRange
    )

import Angle
import DefaultData exposing (armsReach, defaultHysteresis, withSuffix)
import Dict
import Direction2d
import Length
import Maybe exposing (withDefault)
import Point2d as Point2d
import Quantity as Q
import Set exposing (member)
import Time exposing (Posix, posixToMillis)
import Types
    exposing
        ( Action
        , ActionGenerator
        , ActionOutcome(..)
        , Agent
        , CarryableCheck(..)
        , Consideration
        , ConsiderationInput(..)
        , EntryKind
        , Fire
        , FireExtinguisher
        , Food
        , GeneratorType(..)
        , Growable
        , GrowableState(..)
        , Hitpoints(..)
        , Holding(..)
        , InputFunction(..)
        , LogEntry
        , Model
        , Portable(..)
        , Range(..)
        , ReferenceToPortable(..)
        )
import Vector2d as Vector2d


computeUtility : Agent -> Posix -> Action -> Float
computeUtility agent currentTime action =
    let
        tiny =
            List.map (computeConsideration agent currentTime Nothing action) action.considerations
                |> List.foldl (*) 1

        undoTiny =
            List.length action.considerations
                |> toFloat
                |> min 1
    in
    -- What's the name for this operation?
    tiny ^ (1 / undoTiny)


{-| Provide a "forced" value to override the consideration's
regular input value. Useful for graphing.

Note that the output will always be between (consideration.offset) and (consideration.weighting + consideration.offset).

-}
computeConsideration : Agent -> Posix -> Maybe Float -> Action -> Consideration -> Float
computeConsideration agent currentTime forced action consideration =
    let
        inputOrForced =
            case forced of
                Nothing ->
                    getConsiderationRawValue agent currentTime action consideration
                        |> clampTo consideration

                Just x ->
                    x

        mappedInput =
            linearTransform 0 1 consideration.inputMin consideration.inputMax inputOrForced

        output =
            -- see also: https://www.desmos.com/calculator/ubiswoml1r
            case consideration.function of
                Linear { slope, offset } ->
                    slope * mappedInput + offset

                Exponential { exponent } ->
                    mappedInput ^ exponent

                Sigmoid { bend, center } ->
                    1 / (1 + e ^ (-bend * (mappedInput - center)))

                Normal { tightness, center, squareness } ->
                    e ^ (-(tightness ^ squareness) * abs (mappedInput - center) ^ squareness)

                Asymmetric { centerA, bendA, offsetA, squarenessA, centerB, bendB, offsetB, squarenessB } ->
                    let
                        f ctr bend offset squareness x =
                            atan (bend * (x - ctr)) / (squareness * pi) + offset

                        a =
                            f centerA bendA offsetA squarenessA mappedInput

                        b =
                            f centerB bendB offsetB squarenessB mappedInput
                    in
                    a * b

        normalizedOutput =
            output |> nansToZero |> clamp 0 1
    in
    normalizedOutput * consideration.weighting + consideration.offset


nansToZero : Float -> Float
nansToZero n =
    if isNaN n then
        0

    else
        n


{-| Take x and map it from the `x1` - `x2` range into the `y1` - `y2` range.
-}
linearTransform : Float -> Float -> Float -> Float -> Float -> Float
linearTransform y1 y2 x1 x2 x =
    let
        scale =
            (y2 - y1) / (x2 - x1)

        offset =
            y1 - (scale * x1)
    in
    scale * x + offset


getConsiderationRawValue : Agent -> Posix -> Action -> Consideration -> Float
getConsiderationRawValue agent currentTime action consideration =
    case consideration.input of
        Hunger ->
            agent.hunger |> rangeCurrentValue

        MetersToTargetPoint point ->
            point
                |> Point2d.distanceFrom agent.physics.position
                |> Length.inMeters

        Constant f ->
            f

        CurrentSpeedInMetersPerSecond ->
            -- does this seem right?
            agent.physics.velocity
                |> Vector2d.length
                |> Length.inMeters

        TimeSinceLastShoutedFeedMe ->
            case Dict.get "CallOut(FeedMe)" agent.topActionLastStartTimes of
                Nothing ->
                    1 / 0

                Just time ->
                    posixToMillis currentTime - posixToMillis time |> toFloat

        CurrentlyCallingOut ->
            case agent.callingOut of
                Nothing ->
                    0

                Just _ ->
                    1

        IsCurrentAction ->
            agent.currentAction
                == action.name
                |> true1false0

        Held somePortable ->
            isHolding somePortable agent.holding
                |> true1false0

        IAmBeggingForFood ->
            agent.beggingForFood
                |> true1false0

        FoodWasGivenAway foodID ->
            agent.foodsGivenAway
                |> member foodID
                |> true1false0


true1false0 : Bool -> Float
true1false0 b =
    if b then
        1

    else
        0


isHolding : CarryableCheck -> Holding -> Bool
isHolding check held =
    case held of
        EmptyHanded ->
            False

        BothHands p ->
            case check of
                IsAnything ->
                    True

                IsAFireExtinguisher ->
                    case p of
                        Extinguisher _ ->
                            True

                        Edible _ ->
                            False

                IsFood ->
                    case p of
                        Extinguisher _ ->
                            False

                        Edible _ ->
                            True


clampTo : Consideration -> Float -> Float
clampTo con x =
    let
        inputMin =
            min con.inputMin con.inputMax

        inputMax =
            max con.inputMin con.inputMax
    in
    clamp inputMin inputMax x


{-| Convenience method for combining the Variable and Constant action lists.
-}
getActions : Agent -> List Action
getActions agent =
    List.append agent.constantActions agent.variableActions


computeVariableActions : Model -> Agent -> List Action
computeVariableActions model agent =
    agent.actionGenerators
        |> applyList model agent
        |> List.concat


applyList : Model -> Agent -> List GeneratorType -> List (List Action)
applyList model agent generators =
    case generators of
        [] ->
            []

        genType :: rest ->
            forGenerator genType model agent :: applyList model agent rest


isMovementAction : Action -> Bool
isMovementAction action =
    case action.outcome of
        ArrestMomentum ->
            True

        MoveTo _ _ ->
            True

        MoveAwayFrom _ _ ->
            True

        Wander ->
            True

        DoNothing ->
            False

        CallOut _ _ ->
            False

        PickUp _ ->
            False

        EatHeldFood ->
            False

        DropHeldFood ->
            False

        DropHeldThing ->
            False

        BeggingForFood _ ->
            False

        ShootExtinguisher _ ->
            False

        PlantSeed _ ->
            False


isBeggingRelated : Action -> Maybe Bool
isBeggingRelated action =
    case action.outcome of
        BeggingForFood bool ->
            Just bool

        _ ->
            Nothing


onlyArrestMomentum : Action -> Maybe Action
onlyArrestMomentum action =
    case action.outcome of
        ArrestMomentum ->
            Just action

        _ ->
            Nothing


boolString : Bool -> String
boolString b =
    if b then
        "true"

    else
        "false"


{-| Returns a positive int if a is later than b.
-}
differenceInMillis : Posix -> Posix -> Int
differenceInMillis a b =
    Time.posixToMillis a - Time.posixToMillis b


rangeCurrentValue : Range -> Float
rangeCurrentValue range =
    case range of
        Range r ->
            r.value
                |> clamp r.min r.max


normaliseRange : Range -> Float
normaliseRange range =
    case range of
        Range r ->
            r.value
                |> linearTransform 0 1 r.min r.max


{-| Set the current value of a range, clamped to the min and max.
-}
updateRange : Range -> Float -> Range
updateRange original newVal =
    case original of
        Range r ->
            Range { r | value = newVal }


mapRange : (Float -> Float) -> Range -> Range
mapRange func original =
    case original of
        Range r ->
            r.value
                |> func
                |> clamp r.min r.max
                |> (\newValue -> Range { r | value = newValue })


{-| Turns a Hitpoints type into a normalised float, between 0 (dead) and 1 (full hp).
-}
hpAsFloat : Hitpoints -> Float
hpAsFloat hp =
    case hp of
        Hitpoints current max ->
            current
                / max
                |> clamp 0 1


hpRawValue : Hitpoints -> Float
hpRawValue hp =
    case hp of
        Hitpoints current _ ->
            current


setHitpoints : Hitpoints -> Float -> Hitpoints
setHitpoints oldHP new =
    case oldHP of
        Hitpoints _ max ->
            Hitpoints (new |> clamp 0 max) max


isReadyToPlant : Growable -> Bool
isReadyToPlant growable =
    case growable.state of
        FertileSoil _ ->
            True

        GrowingPlant _ ->
            False

        GrownPlant _ ->
            False

        DeadPlant _ ->
            False


forGenerator : GeneratorType -> ActionGenerator
forGenerator genType =
    case genType of
        AvoidFire ->
            avoidFire

        DropFoodForBeggars ->
            dropFoodForBeggar

        EatCarriedFood ->
            eatCarriedFood

        FightFires ->
            fightFires

        HoverNear name ->
            hoverNear name

        MaintainPersonalSpace ->
            maintainPersonalSpace

        MoveToFood ->
            moveToFood

        MoveToGiveFoodToBeggars ->
            moveToGiveFoodToBeggar

        PickUpFoodToEat ->
            pickUpFoodToEat

        PlantThingsToEatLater ->
            plantGrowables

        SetBeggingState ->
            setBeggingState

        StopAtFood ->
            stopAtFood


avoidFire : ActionGenerator
avoidFire model _ =
    let
        goalPerItem : Fire -> Action
        goalPerItem fire =
            Action
                ("get away from the fire" |> withSuffix fire.id)
                (MoveAwayFrom ("fire" |> withSuffix fire.id) fire.physics.position)
                [ { name = "too close to fire"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint fire.physics.position
                  , inputMin = 100
                  , inputMax = 10
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "unless I've got an extinguisher"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsAFireExtinguisher
                  , inputMin = 1
                  , inputMax = 0
                  , weighting = 0.9
                  , offset = 0.1
                  }
                ]
                Dict.empty
    in
    List.map goalPerItem model.fires


dropFoodForBeggar : ActionGenerator
dropFoodForBeggar model agent_ =
    let
        goalPerItem : Agent -> Action
        goalPerItem agent =
            Action
                ("drop food for beggar (" ++ agent.name ++ ")")
                DropHeldFood
                [ { name = "I am carrying some food"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsFood
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "beggar is nearby"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint agent.physics.position
                  , inputMin = 40
                  , inputMax = 10
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "I don't want to eat the food"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Hunger
                  , inputMin = 1
                  , inputMax = 0.5
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
    if isHolding IsFood agent_.holding then
        model.agents
            |> List.filter (\other -> other.name /= agent_.name)
            |> List.filter .beggingForFood
            |> List.map goalPerItem

    else
        []


eatCarriedFood : ActionGenerator
eatCarriedFood _ agent =
    let
        goalPerItem : Maybe Action
        goalPerItem =
            Action
                "eat carried meal"
                EatHeldFood
                [ { name = "currently carrying food"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsFood
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "hunger"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Hunger
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 3
                  , offset = 0
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
                |> Just
    in
    List.filterMap identity <|
        case agent.holding of
            EmptyHanded ->
                []

            BothHands (Edible _) ->
                [ goalPerItem ]

            BothHands _ ->
                []


fightFires : ActionGenerator
fightFires model agent_ =
    let
        shootExtinguisher : Agent -> Fire -> Action
        shootExtinguisher agent fire =
            let
                direction =
                    Direction2d.from agent.physics.position fire.physics.position
                        |> withDefault (Direction2d.fromAngle <| Angle.degrees 0)
            in
            Action
                ("use extinguisher on fire" |> withSuffix fire.id)
                (ShootExtinguisher direction)
                [ { name = "within range"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint fire.physics.position
                  , inputMin = 60
                  , inputMax = 55
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "carrying an extinguisher"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsAFireExtinguisher
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty

        getWithinFightingRange : Fire -> Action
        getWithinFightingRange fire =
            Action
                ("get within range" |> withSuffix fire.id)
                (MoveTo ("fire" |> withSuffix fire.id) fire.physics.position)
                [ { name = "close enough"
                  , function =
                        Asymmetric
                            { centerA = 0.3
                            , bendA = 10
                            , offsetA = 0.5
                            , squarenessA = 0.8
                            , centerB = 0.97
                            , bendB = -1000
                            , offsetB = 0.5
                            , squarenessB = 1
                            }
                  , input = MetersToTargetPoint fire.physics.position
                  , inputMin = 400
                  , inputMax = 30
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "carrying an extinguisher"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsAFireExtinguisher
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty

        pickupNearbyExtinguishers : FireExtinguisher -> Action
        pickupNearbyExtinguishers extinguisher =
            Action
                ("pick up a nearby fire extinguisher" |> withSuffix extinguisher.id)
                (PickUp <| ExtinguisherID extinguisher.id)
                [ { name = "in pickup range"
                  , function = Exponential { exponent = 0.01 }
                  , input = MetersToTargetPoint extinguisher.physics.position
                  , inputMin = 26
                  , inputMax = 25
                  , weighting = 2
                  , offset = 0
                  }
                ]
                Dict.empty

        moveToGetExtinguishers : FireExtinguisher -> Action
        moveToGetExtinguishers extinguisher =
            Action
                ("move to get an extinguisher" |> withSuffix extinguisher.id)
                (MoveTo ("fire extinguisher" |> withSuffix extinguisher.id) extinguisher.physics.position)
                [ { name = "get close enough to pick it up"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint extinguisher.physics.position
                  , inputMin = 10
                  , inputMax = 20
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "not already carrying an extinguisher"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsAFireExtinguisher
                  , inputMin = 1
                  , inputMax = 0
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
    if List.length model.fires > 0 then
        List.map (shootExtinguisher agent_) model.fires
            ++ List.map getWithinFightingRange model.fires
            ++ List.map pickupNearbyExtinguishers model.extinguishers
            ++ List.map moveToGetExtinguishers model.extinguishers

    else
        []


hoverNear : String -> ActionGenerator
hoverNear targetAgentName model _ =
    let
        goalPerItem : Agent -> Action
        goalPerItem otherAgent =
            Action
                ("hang around " ++ targetAgentName)
                (MoveTo otherAgent.name otherAgent.physics.position)
                [ { name = "close, but not close enough"
                  , function = Normal { tightness = 2.6, center = 0.5, squareness = 10 }
                  , input = MetersToTargetPoint otherAgent.physics.position
                  , inputMin = armsReach |> Length.inMeters
                  , inputMax = armsReach |> Q.multiplyBy 3 |> Length.inMeters
                  , weighting = 0.6
                  , offset = 0
                  }
                ]
                Dict.empty
    in
    model.agents
        |> List.filter (\other -> other.name == targetAgentName)
        |> List.map goalPerItem


maintainPersonalSpace : ActionGenerator
maintainPersonalSpace model agent =
    let
        goalPerItem : Agent -> Action
        goalPerItem otherAgent =
            Action
                ("maintain personal space from " ++ otherAgent.name)
                (MoveAwayFrom otherAgent.name otherAgent.physics.position)
                [ { name = "space invaded"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint otherAgent.physics.position
                  , inputMin = 15
                  , inputMax = 5
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
    model.agents
        |> List.filter (\other -> other.name /= agent.name)
        |> List.map goalPerItem


moveToFood : ActionGenerator
moveToFood model _ =
    let
        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("move toward edible food" |> withSuffix food.id)
                (MoveTo ("food" |> withSuffix food.id) food.physics.position)
                [ { name = "hunger"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Hunger
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "too far from food item"
                  , function = Exponential { exponent = 2 }
                  , input = MetersToTargetPoint food.physics.position
                  , inputMin = 3000
                  , inputMax = armsReach |> Length.inMeters
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "in range of food item"
                  , function = Exponential { exponent = 0.01 }
                  , input = MetersToTargetPoint food.physics.position
                  , inputMin = armsReach |> Q.multiplyBy 0.9 |> Length.inMeters
                  , inputMax = armsReach |> Length.inMeters
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "not already carrying food"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsFood
                  , inputMin = 1
                  , inputMax = 0
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "haven't given this away before"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = FoodWasGivenAway food.id
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = -1
                  , offset = 1
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
    in
    List.map goalPerItem model.foods


moveToGiveFoodToBeggar : ActionGenerator
moveToGiveFoodToBeggar model _ =
    let
        goalPerItem : Agent -> Action
        goalPerItem agent =
            Action
                ("move to give food to beggar (" ++ agent.name ++ ")")
                (MoveTo ("giveFoodTo(" ++ agent.name ++ ")") agent.physics.position)
                [ { name = "I am carrying some food"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Held IsFood
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "beggar is reasonably close"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint agent.physics.position
                  , inputMin = 500
                  , inputMax = 0
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "I don't want to eat the food"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Hunger
                  , inputMin = 1
                  , inputMax = 0.5
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
    model.agents
        |> List.filter .beggingForFood
        |> List.map goalPerItem


pickUpFoodToEat : ActionGenerator
pickUpFoodToEat model _ =
    let
        goalsPerItem : Food -> List Action
        goalsPerItem food =
            let
                inPickupRange : Consideration
                inPickupRange =
                    { name = "in pickup range"
                    , function = Exponential { exponent = 0.01 }
                    , input = MetersToTargetPoint food.physics.position
                    , inputMin = armsReach |> Length.inMeters
                    , inputMax = armsReach |> Q.multiplyBy 0.9 |> Length.inMeters
                    , weighting = 2
                    , offset = 0
                    }

                hungry : Consideration
                hungry =
                    { name = "hungry"
                    , function = Linear { slope = 1, offset = 0 }
                    , input = Hunger
                    , inputMin = 0
                    , inputMax = 1
                    , weighting = 3
                    , offset = 0
                    }

                haventGivenAwayBefore : Consideration
                haventGivenAwayBefore =
                    { name = "haven't given this away before"
                    , function = Linear { slope = 1, offset = 0 }
                    , input = FoodWasGivenAway food.id
                    , inputMin = 0
                    , inputMax = 1
                    , weighting = -2
                    , offset = 1
                    }

                handsAreFree : Consideration
                handsAreFree =
                    { name = "hands are free"
                    , function = Linear { slope = 1, offset = 0 }
                    , input = Held IsAnything
                    , inputMin = 1
                    , inputMax = 0
                    , weighting = 1
                    , offset = 0
                    }

                handsAreFull : Consideration
                handsAreFull =
                    { handsAreFree | inputMin = 0, inputMax = 1 }
            in
            [ Action
                ("pick up food to eat" |> withSuffix food.id)
                (PickUp <| EdibleID food.id)
                [ inPickupRange
                , hungry
                , haventGivenAwayBefore
                , handsAreFree
                , defaultHysteresis 0.1
                ]
                Dict.empty
            , Action
                ("drop held thing to grab" |> withSuffix food.id)
                DropHeldThing
                [ inPickupRange
                , hungry
                , haventGivenAwayBefore
                , handsAreFull
                ]
                Dict.empty
            ]
    in
    List.concatMap goalsPerItem model.foods


plantGrowables : ActionGenerator
plantGrowables model agent =
    let
        getInSeedPlantingRange : Growable -> Action
        getInSeedPlantingRange growable =
            Action
                ("get in seed planting range of closest growable" |> withSuffix growable.id)
                (MoveTo ("growable" |> withSuffix growable.id) growable.physics.position)
                [ { name = "distance to fertile soil"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint growable.physics.position
                  , inputMin = armsReach |> Q.multiplyBy 0.9 |> Length.inMeters
                  , inputMax = armsReach |> Length.inMeters
                  , weighting = 0.2
                  , offset = 0
                  }
                ]
                Dict.empty

        plantSeed : Growable -> Action
        plantSeed growable =
            Action
                ("plant seed in growable" |> withSuffix growable.id)
                (PlantSeed growable.id)
                [ { name = "close enough to plant the seed"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint growable.physics.position
                  , inputMin = armsReach |> Length.inMeters
                  , inputMax = armsReach |> Q.multiplyBy 0.9 |> Length.inMeters
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty

        stopMovingWhenPlantingSeeds : Growable -> Action
        stopMovingWhenPlantingSeeds growable =
            Action
                ("stop when in range of fertile growable" |> withSuffix growable.id)
                ArrestMomentum
                [ { name = "in range of fertile growable"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = MetersToTargetPoint growable.physics.position
                  , inputMin = armsReach |> Length.inMeters
                  , inputMax = armsReach |> Q.multiplyBy 0.9 |> Length.inMeters
                  , weighting = 0.4
                  , offset = 0
                  }
                ]
                Dict.empty
    in
    let
        targets : List Growable
        targets =
            model.growables
                |> List.filter isReadyToPlant
                -- Does this do unnecessary work? What about mapping to distances, then LE.minimumBy?
                |> List.sortBy (.physics >> .position >> Point2d.distanceFrom agent.physics.position >> Length.inMeters)
                |> List.take 1
    in
    (targets |> List.map getInSeedPlantingRange)
        ++ (targets |> List.map plantSeed)
        ++ (targets |> List.map stopMovingWhenPlantingSeeds)


setBeggingState : ActionGenerator
setBeggingState _ agent =
    let
        ceaseBegging : Action
        ceaseBegging =
            Action
                "quit begging"
                (BeggingForFood False)
                [ { name = "I'm no longer hungry"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Hunger
                  , inputMin = 0.4
                  , inputMax = 0.3
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty

        beginBegging : Action
        beginBegging =
            Action
                "start begging"
                (BeggingForFood True)
                [ { name = "I'm hungry"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = Hunger
                  , inputMin = 0.7
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
    if agent.beggingForFood then
        [ ceaseBegging ]

    else
        [ beginBegging ]


stopAtFood : ActionGenerator
stopAtFood model _ =
    let
        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("stop when in range of edible food" |> withSuffix food.id)
                ArrestMomentum
                [ { name = "in range of food item"
                  , function = Exponential { exponent = 0.01 }
                  , input = MetersToTargetPoint food.physics.position
                  , inputMin = armsReach |> Length.inMeters
                  , inputMax = armsReach |> Q.multiplyBy 0.9 |> Length.inMeters
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "still moving"
                  , function = Sigmoid { bend = 10, center = 0.5 }
                  , input = CurrentSpeedInMetersPerSecond
                  , inputMin = 3
                  , inputMax = 6
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "haven't given this away before"
                  , function = Linear { slope = 1, offset = 0 }
                  , input = FoodWasGivenAway food.id
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = -2
                  , offset = 1
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
    in
    List.map goalPerItem model.foods


log : EntryKind -> Model -> Model
log entry model =
    let
        newEntry : LogEntry
        newEntry =
            { entry = entry
            , time = model.time
            }
    in
    { model | log = newEntry :: model.log }

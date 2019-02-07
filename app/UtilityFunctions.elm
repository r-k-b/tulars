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
    , linearTransform
    , mapRange
    , normaliseRange
    , onlyArrestMomentum
    , portableIsExtinguisher
    , portableIsFood
    , rangeCurrentValue
    , setHitpoints
    , updateRange
    )

import Dict
import Point2d as Point2d
import Set exposing (member)
import Time exposing (Posix, posixToMillis)
import Types exposing (Action, ActionGenerator(..), ActionOutcome(..), Agent, Consideration, ConsiderationInput(..), Hitpoints(..), Holding(..), InputFunction(..), Model, Portable(..), Range(..))
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
                Linear m b ->
                    m * mappedInput + b

                Exponential exponent ->
                    mappedInput ^ exponent

                Sigmoid bend center ->
                    1 / (1 + e ^ (-bend * (mappedInput - center)))

                Normal tightness center squareness ->
                    e ^ (-(tightness ^ squareness) * abs (mappedInput - center) ^ squareness)

                Asymmetric centerA bendA offsetA squarenessA centerB bendB offsetB squarenessB ->
                    let
                        f ctr bend offset sqns x =
                            atan (bend * (x - ctr)) / (sqns * pi) + offset

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
    case isNaN n of
        True ->
            0

        False ->
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

        DistanceToTargetPoint point ->
            point |> Point2d.distanceFrom agent.physics.position

        Constant f ->
            f

        CurrentSpeed ->
            agent.physics.velocity
                |> Vector2d.length

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

        IsCarryingExtinguisher ->
            isHolding portableIsExtinguisher agent.holding
                |> true1false0

        IsCarryingFood ->
            isHolding portableIsFood agent.holding
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


portableIsExtinguisher : Portable -> Bool
portableIsExtinguisher p =
    case p of
        Extinguisher _ ->
            True

        _ ->
            False


portableIsFood : Portable -> Bool
portableIsFood p =
    case p of
        Edible _ ->
            True

        _ ->
            False


isHolding : (Portable -> Bool) -> Holding -> Bool
isHolding f held =
    case held of
        EmptyHanded ->
            False

        BothHands p ->
            f p


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


applyList : Model -> Agent -> List ActionGenerator -> List (List Action)
applyList model agent generators =
    case generators of
        [] ->
            []

        (ActionGenerator _ gen) :: rest ->
            gen model agent :: applyList model agent rest


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

        BeggingForFood _ ->
            False

        ShootExtinguisher _ ->
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
            r.currentValue |> clamp r.min r.max


normaliseRange : Range -> Float
normaliseRange range =
    case range of
        Range r ->
            r.currentValue
                |> linearTransform 0 1 r.min r.max


{-| Set the current value of a range, clamped to the min and max.
-}
updateRange : Range -> Float -> Range
updateRange original newVal =
    case original of
        Range r ->
            Range { r | currentValue = newVal }


mapRange : (Float -> Float) -> Range -> Range
mapRange func original =
    case original of
        Range r ->
            r.currentValue
                |> func
                |> clamp r.min r.max
                |> (\newValue -> Range { r | currentValue = newValue })


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
        Hitpoints current max ->
            current


setHitpoints : Hitpoints -> Float -> Hitpoints
setHitpoints oldHP new =
    case oldHP of
        Hitpoints _ max ->
            new
                |> clamp 0 max
                |> Hitpoints max

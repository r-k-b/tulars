module UtilityFunctions exposing (..)

import Time exposing (Time)
import Types
    exposing
        ( Action
        , ActionGenerator(ActionGenerator)
        , Agent
        , Consideration
        , ConsiderationInput
            ( Constant
            , CurrentSpeed
            , CurrentlyCallingOut
            , DistanceToTargetPoint
            , Hunger
            , IsCurrentAction
            , TimeSinceLastShoutedFeedMe
            )
        , InputFunction(Asymmetric, Exponential, Linear, Normal, Sigmoid)
        , Model
        )
import OpenSolid.Point2d as Point2d
import OpenSolid.Vector2d as Vector2d


computeUtility : Agent -> Time -> Action -> Float
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
-}
computeConsideration : Agent -> Time -> Maybe Float -> Action -> Consideration -> Float
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
                    e ^ (-(tightness ^ squareness) * (abs (mappedInput - center)) ^ squareness)

                Asymmetric centerA bendA offsetA squarenessA centerB bendB offsetB squarenessB ->
                    let
                        f ctr bend offset sqns x =
                            (atan (bend * (x - ctr))) / (sqns * pi) + offset

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
    case (isNaN n) of
        True ->
            0

        False ->
            n


linearTransform : Float -> Float -> Float -> Float -> Float -> Float
linearTransform bMin bMax aMin aMax x =
    let
        offset =
            bMin - aMin

        scale =
            (bMax - bMin) / (aMax - aMin)
    in
        scale * (x + offset)


getConsiderationRawValue : Agent -> Time -> Action -> Consideration -> Float
getConsiderationRawValue agent currentTime action consideration =
    case consideration.input of
        Hunger ->
            agent.hunger

        DistanceToTargetPoint point ->
            point |> Point2d.distanceFrom agent.physics.position

        Constant f ->
            f

        CurrentSpeed ->
            agent.physics.velocity
                |> Vector2d.length

        TimeSinceLastShoutedFeedMe ->
            let
                timeSince =
                    case agent.timeLastShoutedFeedMe of
                        Nothing ->
                            10000

                        Just t ->
                            currentTime - t
            in
                if isNaN timeSince then
                    Debug.crash "wtf"
                else
                    timeSince

        CurrentlyCallingOut ->
            case agent.callingOut of
                Nothing ->
                    0

                Just _ ->
                    1

        IsCurrentAction ->
            if agent.currentAction == action.name then
                1
            else
                0


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

        (ActionGenerator name gen) :: rest ->
            (gen model agent) :: (applyList model agent rest)

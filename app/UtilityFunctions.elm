module UtilityFunctions exposing (..)

import Types
    exposing
        ( Action
        , Agent
        , Consideration
        , ConsiderationInput(Constant, CurrentSpeed, DistanceToTargetPoint, Hunger)
        , InputFunction(Exponential, InverseNormal, Linear, Normal, Sigmoid)
        )
import OpenSolid.Point2d as Point2d
import OpenSolid.Vector2d as Vector2d


computeUtility : Agent -> Action -> Float
computeUtility agent action =
    let
        tiny =
            List.map (computeConsideration agent Nothing) action.considerations
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
computeConsideration : Agent -> Maybe Float -> Consideration -> Float
computeConsideration agent forced consideration =
    let
        inputOrForced =
            case forced of
                Nothing ->
                    getConsiderationRawValue agent consideration

                Just x ->
                    x

        mappedInput =
            linearTransform 0 1 consideration.inputMin consideration.inputMax inputOrForced

        output =
            case consideration.function of
                Linear m b ->
                    m * mappedInput + b

                Exponential exponent ->
                    mappedInput ^ exponent

                Sigmoid bend center ->
                    1 / (1 + e ^ (-bend * (mappedInput - center)))

                Normal tightness center ->
                    e ^ (-tightness * (mappedInput + center) ^ 2)

                InverseNormal tightness center ->
                    1 - e ^ (-tightness * (mappedInput + center) ^ 2)

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


getConsiderationRawValue : Agent -> Consideration -> Float
getConsiderationRawValue agent consideration =
    case consideration.input of
        Hunger ->
            agent.hunger

        DistanceToTargetPoint point ->
            point |> Point2d.distanceFrom agent.position

        Constant f ->
            f

        CurrentSpeed ->
            agent.velocity
                |> Vector2d.length

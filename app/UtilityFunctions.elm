module UtilityFunctions exposing (..)

import Types exposing (Action, Agent, Consideration, ConsiderationInput(DistanceToTargetPoint, Hunger), InputFunction(Exponential, InverseNormal, Linear, Normal, Sigmoid))
import OpenSolid.Point2d as Point2d


computeUtility : Agent -> Action -> Float
computeUtility agent action =
    List.map (computeConsideration agent) action.considerations
        |> List.foldl (+) 0


computeConsideration : Agent -> Consideration -> Float
computeConsideration agent consideration =
    let
        inputVal =
            case consideration.input of
                Hunger ->
                    agent.hunger

                DistanceToTargetPoint point ->
                    point |> Point2d.distanceFrom agent.position

        mappedInput =
            linearTransform 0 1 consideration.inputMin consideration.inputMax inputVal

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
    in
        output |> nansToZero |> clamp 0 1


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

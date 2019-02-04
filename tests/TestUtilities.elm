module TestUtilities exposing (suite)

import Expect exposing (Expectation, FloatingPointTolerance(..))
import Test exposing (Test, describe, test)
import UtilityFunctions exposing (linearTransform)


standardTransform =
    linearTransform 0 100 0 1


epsilon =
    Absolute 0.000000001


suite : Test
suite =
    describe "linear transforms"
        [ test "basics 1" <|
            \_ ->
                standardTransform 0.9
                    |> Expect.within epsilon 90
        , test "basics 2" <|
            \_ ->
                standardTransform 0.1
                    |> Expect.within epsilon 10
        , test "outside the lower bounds" <|
            \_ ->
                standardTransform -0.1
                    |> Expect.within epsilon -10
        , test "outside the upper bounds" <|
            \_ ->
                standardTransform 1.1
                    |> Expect.within epsilon 110
        , test "flipped input range" <|
            \_ ->
                linearTransform 0 100 1 0 0.9
                    |> Expect.within epsilon 10
        , test "flipped output range" <|
            \_ ->
                linearTransform 100 0 0 1 0.9
                    |> Expect.within epsilon 10
        , test "flipped both ranges" <|
            \_ ->
                linearTransform 100 0 1 0 0.9
                    |> Expect.within epsilon 90
        ]

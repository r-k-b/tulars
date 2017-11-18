module Example exposing (..)

import Expect exposing (Expectation, FloatingPointTolerance(Absolute))
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (Test, describe, test, todo)
import UtilityFunctions exposing (linearTransform)


suite : Test
suite =
    describe "main"
        [ describe "1d linear transforms"
            [ test "no-op" <|
                \_ ->
                    linearTransform 0 1 0 1 1
                        |> Expect.equal 1
            , test "simple scale" <|
                \_ ->
                    linearTransform 0 1 0 2 1
                        |> Expect.equal 0.5
            , test "flip" <|
                \_ ->
                    linearTransform 0 1 1 0 1
                        |> Expect.equal 0
            , test "offset" <|
                \_ ->
                    linearTransform 0 1 3 4 3.8
                        |> Expect.within (Absolute 1.0e-9) 0.8
            , test "offset overmax" <|
                \_ ->
                    linearTransform 0 1 3 4 4.8
                        |> Expect.within (Absolute 1.0e-9) 1.8
            , test "offset flip a" <|
                \_ ->
                    linearTransform 0 1 100 99 100
                        |> Expect.equal 0
            , test "offset flip b" <|
                \_ ->
                    linearTransform 0 1 100 99 99
                        |> Expect.equal 1
            ]
        ]

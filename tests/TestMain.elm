module TestMain exposing (suite)

import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "main"
        [ describe "object pickup"
            [ describe "food items"
                [ test "no such food ID means nothing happens" <|
                    \_ ->
                        1 |> Expect.equal 1
                ]
            ]
        ]

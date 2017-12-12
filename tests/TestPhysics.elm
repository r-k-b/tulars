module TestPhysics exposing (suite)

import Expect exposing (Expectation, FloatingPointTolerance(Absolute))
import Fuzz exposing (Fuzzer, int, list, string)
import Physics exposing (collide)
import Test exposing (Test, describe, test, todo)
import OpenSolid.Point2d exposing (fromCoordinates)
import OpenSolid.Direction2d exposing (fromAngle, positiveX)
import OpenSolid.Vector2d as V2 exposing (Vector2d, fromComponents, zero)
import Types exposing (Collision, Physical)


defaultPhysics =
    { position = fromCoordinates ( 0, 0 )
    , facing = positiveX
    , velocity = zero
    , acceleration = zero
    , radius = 1
    }


type alias Empty =
    {}


circleAt : Float -> Float -> Float -> Physical Empty
circleAt x y radius =
    { physics =
        { defaultPhysics
            | position = fromCoordinates ( x, y )
            , radius = radius
        }
    }


suite : Test
suite =
    describe "physics"
        [ describe "circle penetration"
            [ test "exact overlap" <|
                \_ ->
                    collide
                        (circleAt 0 0 10)
                        (circleAt 0 0 10)
                        |> Expect.equal (Collision Nothing 20)
            , test "some overlap" <|
                \_ ->
                    collide
                        (circleAt 0 0 10)
                        (circleAt 15 0 10)
                        |> Expect.equal (Collision (Just positiveX) 5)
            , test "touching" <|
                \_ ->
                    collide
                        (circleAt 0 0 10)
                        (circleAt 20 0 10)
                        |> Expect.equal (Collision (Just positiveX) 0)
            , test "no overlap" <|
                \_ ->
                    collide
                        (circleAt 0 0 10)
                        (circleAt 30 0 10)
                        |> Expect.equal (Collision (Just positiveX) -10)
            ]
        ]

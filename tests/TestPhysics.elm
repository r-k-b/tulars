module TestPhysics exposing (suite)

import Direction2d exposing (positiveX)
import Expect exposing (Expectation, FloatingPointTolerance(..))
import Physics exposing (collide)
import Point2d as Point2d
import Test exposing (Test, describe, test)
import Types exposing (Collision, Physical)
import Vector2d exposing (Vector2d, zero)


defaultPhysics =
    { position = Point2d.fromCoordinates ( 0, 0 )
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
            | position = Point2d.fromCoordinates ( x, y )
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

module TestPhysics exposing (suite)

import Direction2d exposing (positiveX)
import Expect exposing (FloatingPointTolerance(..))
import Length
import Physics exposing (collide)
import Point2d
import Test exposing (Test, describe, test)
import Types exposing (Collision, Physical, PhysicalProperties)
import Vector2d exposing (zero)


defaultPhysics : PhysicalProperties
defaultPhysics =
    { position = Point2d.origin
    , facing = positiveX
    , velocity = zero
    , acceleration = zero
    , radius = Length.meters 1
    }


type alias Empty =
    {}


circleAt : Float -> Float -> Float -> Physical Empty
circleAt x y radius =
    { physics =
        { defaultPhysics
            | position = Point2d.fromMeters { x = x, y = y }
            , radius = Length.meters radius
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
                        |> Expect.equal (Collision Nothing (Length.meters 20))
            , test "some overlap" <|
                \_ ->
                    collide
                        (circleAt 0 0 10)
                        (circleAt 15 0 10)
                        |> Expect.equal (Collision (Just positiveX) (Length.meters 5))
            , test "touching" <|
                \_ ->
                    collide
                        (circleAt 0 0 10)
                        (circleAt 20 0 10)
                        |> Expect.equal (Collision (Just positiveX) (Length.meters 0))
            , test "no overlap" <|
                \_ ->
                    collide
                        (circleAt 0 0 10)
                        (circleAt 30 0 10)
                        |> Expect.equal (Collision (Just positiveX) (Length.meters -10))
            ]
        ]

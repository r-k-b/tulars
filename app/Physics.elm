module Physics exposing (collide)

import Direction2d as D2
import Length exposing (Length, Meters)
import Point2d exposing (Point2d, distanceFrom)
import Quantity as Q
import Types exposing (Collision, Physical)


collide : Physical a -> Physical b -> Collision
collide oa ob =
    let
        a : Point2d Meters Types.YDownCoords
        a =
            oa.physics.position

        b : Point2d Meters Types.YDownCoords
        b =
            ob.physics.position

        centersDistance : Length
        centersDistance =
            a |> distanceFrom b

        normal : Maybe (D2.Direction2d Types.YDownCoords)
        normal =
            D2.from a b

        penetration : Length
        penetration =
            (oa.physics.radius |> Q.plus ob.physics.radius)
                |> Q.minus centersDistance
    in
    Collision normal penetration

module Physics exposing (collide)

import Direction2d as D2
import Point2d exposing (distanceFrom)
import Types exposing (Collision, Physical)


collide : Physical a -> Physical b -> Collision
collide oa ob =
    let
        a =
            oa.physics.position

        b =
            ob.physics.position

        centersDistance =
            a |> distanceFrom b

        normal =
            D2.from a b

        penetration =
            oa.physics.radius + ob.physics.radius - centersDistance
    in
        Collision normal penetration

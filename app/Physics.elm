module Physics exposing (collide)

import OpenSolid.Point2d exposing (distanceFrom)
import OpenSolid.Vector2d exposing (normalize)
import OpenSolid.Direction2d as D2
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

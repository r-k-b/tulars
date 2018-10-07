module Util exposing (mousePosToVec2)

import Vector2d as V2 exposing (Vector2d)


mousePosToVec2 : { x : Int, y : Int } -> Vector2d
mousePosToVec2 p =
    V2.fromComponents ( toFloat p.x, toFloat p.y )

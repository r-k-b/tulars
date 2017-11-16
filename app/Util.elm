module Util exposing (..)

import Mouse exposing (Position)
import OpenSolid.Point2d exposing (Point2d)
import OpenSolid.Vector2d as V2 exposing (Vector2d, difference, sum)
import Types exposing (Model)


mousePosToVec2 : { x : Int, y : Int } -> Vector2d
mousePosToVec2 p =
    V2.fromComponents ( toFloat p.x, toFloat p.y )


getPosition : Model -> Vector2d
getPosition { position, drag } =
    case drag of
        Nothing ->
            position

        Just { start, current } ->
            difference (sum position current) start

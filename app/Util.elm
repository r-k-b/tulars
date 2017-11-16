module Util exposing (..)

import Math.Vector2 exposing (Vec2, add, sub, vec2)
import Mouse exposing (Position)
import Types exposing (Model)


mousePosToVec2 : Position -> Vec2
mousePosToVec2 p =
    vec2 (toFloat p.x) (toFloat p.y)


getPosition : Model -> Vec2
getPosition { position, drag } =
    case drag of
        Nothing ->
            position

        Just { start, current } ->
            sub (add position current) start

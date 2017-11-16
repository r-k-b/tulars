module Types exposing (..)

import Math.Vector2 exposing (Vec2)
import Mouse exposing (Position)
import Time exposing (Time)


type alias Model =
    { position : Vec2
    , drag : Maybe Drag
    , time : Time
    }


type alias Drag =
    { start : Vec2
    , current : Vec2
    }


type Msg
    = DragStart Vec2
    | DragAt Vec2
    | DragEnd Vec2
    | RAFtick Time

module Types exposing (..)

import Mouse exposing (Position)
import Time exposing (Time)


type alias Model =
    { position : Position
    , drag : Maybe Drag
    , time : Time
    }


type alias Drag =
    { start : Position
    , current : Position
    }


type Msg
    = DragStart Position
    | DragAt Position
    | DragEnd Position
    | RAFtick Time

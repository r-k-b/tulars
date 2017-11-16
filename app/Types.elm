module Types exposing (..)

import Mouse exposing (Position)
import OpenSolid.Direction2d exposing (Direction2d)
import OpenSolid.Point2d exposing (Point2d)
import OpenSolid.Vector2d as V2 exposing (Vector2d)
import Time exposing (Time)


type alias Model =
    { position : Vector2d
    , drag : Maybe Drag
    , time : Time
    , agents : List Agent
    }


type alias Drag =
    { start : Vector2d
    , current : Vector2d
    }


type Msg
    = DragStart Vector2d
    | DragAt Vector2d
    | DragEnd Vector2d
    | RAFtick Time
    | InitTime Time


type alias Agent =
    { position : Point2d
    , facing : Direction2d
    , velocity : Vector2d
    , acceleration : Vector2d
    }

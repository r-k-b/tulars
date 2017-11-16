module Types exposing (..)

import Mouse exposing (Position)
import OpenSolid.Direction2d exposing (Direction2d)
import OpenSolid.Point2d exposing (Point2d)
import OpenSolid.Vector2d as V2 exposing (Vector2d)
import Time exposing (Time)


type alias Model =
    { time : Time
    , agents : List Agent
    }


type Msg
    = RAFtick Time
    | InitTime Time


type alias Action =
    { name : String
    , considerations : List Consideration
    }


type alias Consideration =
    { name : String
    , function : InputFunction
    , input : ConsiderationInput
    , inputMin : Float
    , inputMax : Float
    , weighting : Float
    , offset : Float
    }


type ConsiderationInput
    = Hunger
    | DistanceToTargetPoint Point2d


type InputFunction
    = Linear Float Float
    | Exponential Float
    | Sigmoid
    | Normal


type alias Agent =
    { position : Point2d
    , facing : Direction2d
    , velocity : Vector2d
    , acceleration : Vector2d
    , actions : List Action
    }

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
    | ToggleConditionsVisibility String String
    | ToggleConditionDetailsVisibility String String String


type alias Action =
    { name : String
    , outcome : ActionOutcome
    , considerations : List Consideration
    , considerationsVisible : Bool
    }


type ActionOutcome
    = DoNothing
    | MoveTo Point2d
    | ArrestMomentum


type alias Consideration =
    { name : String
    , function : InputFunction
    , input : ConsiderationInput
    , inputMin : Float
    , inputMax : Float
    , weighting : Float
    , offset : Float
    , detailsVisible : Bool
    }


type ConsiderationInput
    = Hunger
    | DistanceToTargetPoint Point2d
    | Constant Float


type alias Exponent =
    Float


type alias Slope =
    Float


type alias Offset =
    Float


type alias Bend =
    Float


type alias Center =
    Float


type alias Tightness =
    Float


type InputFunction
    = Linear Slope Offset
    | Exponential Exponent
    | Sigmoid Bend Center
    | Normal Tightness Center
    | InverseNormal Tightness Center


type alias Agent =
    { name : String
    , position : Point2d
    , facing : Direction2d
    , velocity : Vector2d
    , acceleration : Vector2d
    , actions : List Action
    , hunger : Float
    }

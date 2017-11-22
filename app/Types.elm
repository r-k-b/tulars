module Types exposing (..)

import Dict exposing (Dict)
import Mouse exposing (Position)
import OpenSolid.Direction2d exposing (Direction2d)
import OpenSolid.Point2d exposing (Point2d)
import OpenSolid.Vector2d as V2 exposing (Vector2d)
import Time exposing (Time)


type alias Model =
    { time : Time
    , agents : List Agent
    , foods : List Food
    , fires : List Fire
    }


type Msg
    = RAFtick Time
    | InitTime Time
    | ToggleConditionsVisibility String String
    | ToggleConditionDetailsVisibility String String String


type alias Agent =
    { name : String
    , position : Point2d
    , facing : Direction2d
    , velocity : Vector2d
    , acceleration : Vector2d
    , constantActions : ActionList
    , variableActions : ActionList
    , actionGenerators : ActionGeneratorList
    , visibleActions : Dict String Bool
    , hunger : Float
    , timeLastShoutedFeedMe : Maybe Time
    , callingOut : Maybe CurrentSignal
    }


type alias Action =
    { name : String
    , outcome : ActionOutcome
    , considerations : List Consideration
    , visibleConsiderations : Dict String Bool
    }


type ActionList
    = ActionList (List Action)


type alias ActionGenerator =
    { name : String
    , generator : Model -> ActionList
    }


type ActionGeneratorList
    = ActionGeneratorList (List ActionGenerator)


type ActionOutcome
    = DoNothing
    | MoveTo Point2d
    | MoveAwayFrom Point2d
    | ArrestMomentum
    | CallOut Signal Float
    | Wander


type Signal
    = FeedMe
    | GoAway
    | Eating


type alias CurrentSignal =
    { signal : Signal
    , started : Time
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
    | Constant Float
    | CurrentSpeed
    | TimeSinceLastShoutedFeedMe
    | CurrentlyCallingOut


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


type alias Food =
    { id : Int
    , position : Point2d
    , joules : Float
    }


type alias Fire =
    { id : Int
    , position : Point2d
    , originalPosition : Point2d
    }

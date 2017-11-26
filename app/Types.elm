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
    , extinguishers : List FireExtinguisher
    }


type Msg
    = RAFtick Time
    | InitTime Time
    | ToggleConditionsVisibility String String
    | ToggleConditionDetailsVisibility String String String


type alias Agent =
    { name : String
    , physics : PhysicalProperties
    , constantActions : List Action
    , variableActions : List Action
    , actionGenerators : List ActionGenerator
    , visibleActions : Dict String Bool
    , hunger : Float
    , timeLastShoutedFeedMe : Maybe Time
    , callingOut : Maybe CurrentSignal
    , holding : Holding
    }


type alias Action =
    { name : String
    , outcome : ActionOutcome
    , considerations : List Consideration
    , visibleConsiderations : Dict String Bool
    }


type ActionGenerator
    = ActionGenerator Name Generator


type ActionOutcome
    = DoNothing
    | MoveTo Point2d
    | MoveAwayFrom Point2d
    | ArrestMomentum
    | CallOut Signal Float
    | Wander
    | EatFood Int


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


type alias PhysicalProperties =
    { position : Point2d
    , facing : Direction2d
    , velocity : Vector2d
    , acceleration : Vector2d
    }


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
    , physics : PhysicalProperties
    , joules : Float
    }


type alias Fire =
    { id : Int
    , physics : PhysicalProperties
    }


type alias Name =
    String


type alias Generator =
    Model -> Agent -> List Action


type Holding
    = EmptyHanded
    | OnlyLeftHand Portable
    | OnlyRightHand Portable
    | EachHand Portable Portable
    | BothHands Portable


type Portable
    = Extinguisher FireExtinguisher
    | Edible Food


type alias FireExtinguisher =
    { id : Int
    , physics : PhysicalProperties
    , capacity : Float
    , remaining : Float
    }

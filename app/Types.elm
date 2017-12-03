module Types
    exposing
        ( Action
        , ActionGenerator(ActionGenerator)
        , ActionOutcome
            ( ArrestMomentum
            , BeggingForFood
            , CallOut
            , DoNothing
            , DropHeldFood
            , EatHeldFood
            , MoveAwayFrom
            , MoveTo
            , PickUp
            , Wander
            )
        , Agent
        , Consideration
        , ConsiderationInput
            ( Constant
            , CurrentlyCallingOut
            , CurrentSpeed
            , DistanceToTargetPoint
            , Hunger
            , IAmBeggingForFood
            , IsCarryingExtinguisher
            , IsCarryingFood
            , IsCurrentAction
            , TimeSinceLastShoutedFeedMe
            )
        , CurrentSignal
        , Fire
        , FireExtinguisher
        , Food
        , Holding(BothHands, EachHand, EmptyHanded, OnlyLeftHand, OnlyRightHand)
        , InputFunction(Asymmetric, Exponential, Linear, Normal, Sigmoid)
        , Model
        , Msg(InitTime, RAFtick, ToggleConditionDetailsVisibility, ToggleConditionsVisibility)
        , PhysicalProperties
        , Portable(Edible, Extinguisher)
        , ReferenceToPortable(ExtinguisherID, EdibleID)
        , Signal(Bored, Eating, FeedMe, GoAway)
        )

import Dict exposing (Dict)
import OpenSolid.Direction2d exposing (Direction2d)
import OpenSolid.Point2d exposing (Point2d)
import OpenSolid.Vector2d exposing (Vector2d)
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
    , currentAction : String
    , currentOutcome : String
    , hunger : Float
    , beggingForFood : Bool
    , topActionLastStartTimes : Dict String Time
    , callingOut : Maybe CurrentSignal
    , holding : Holding

    -- , desireToStayStill : Bool
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
    | MoveTo String Point2d
    | MoveAwayFrom String Point2d
    | ArrestMomentum
    | CallOut Signal Float
    | Wander
    | PickUp ReferenceToPortable
    | EatHeldFood
    | DropHeldFood
    | BeggingForFood Bool


type Signal
    = FeedMe
    | GoAway
    | Eating
    | Bored


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
    = Hunger {- Hunger increases over time -}
    | DistanceToTargetPoint Point2d
    | Constant Float
    | CurrentSpeed
    | TimeSinceLastShoutedFeedMe
    | CurrentlyCallingOut
    | IsCurrentAction
    | IAmBeggingForFood
    | IsCarryingFood
    | IsCarryingExtinguisher


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


type alias Squareness =
    Float


type InputFunction
    = Linear Slope Offset
    | Exponential Exponent
    | Sigmoid Bend Center
    | Normal Tightness Center Squareness
    | Asymmetric Center Bend Offset Squareness Center Bend Offset Squareness


type alias Food =
    { id : Int
    , physics : PhysicalProperties
    , joules : Float
    , freshJoules : Float
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


type ReferenceToPortable
    = ExtinguisherID Int
    | EdibleID Int


type alias FireExtinguisher =
    { id : Int
    , physics : PhysicalProperties
    , capacity : Float
    , remaining : Float
    }

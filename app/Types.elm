module Types exposing
    ( Action
    , ActionGenerator(..)
    , ActionOutcome(..)
    , Agent
    , Collision
    , Consideration
    , ConsiderationInput(..)
    , CurrentSignal
    , Fire
    , FireExtinguisher
    , Food
    , Growable
    , GrowableState(..)
    , Hitpoints(..)
    , Holding(..)
    , InputFunction(..)
    , Layer(..)
    , Model
    , Msg(..)
    , Physical
    , PhysicalProperties
    , Portable(..)
    , Range(..)
    , ReferenceToPortable(..)
    , Retardant
    , Scene
    , Signal(..)
    )

import Dict exposing (Dict)
import Direction2d exposing (Direction2d)
import Point2d exposing (Point2d)
import Set exposing (Set)
import Time exposing (Posix)
import Vector2d exposing (Vector2d)


type Hitpoints
    = Hitpoints Float Float -- current, max


type Range
    = Range { min : Float, max : Float, value : Float }


type alias Model =
    { time : Posix
    , agents : List Agent
    , foods : List Food
    , fires : List Fire
    , growables : List Growable
    , extinguishers : List FireExtinguisher
    , retardants : List Retardant
    , paused : Bool
    }


type alias Scene =
    { agents : List Agent
    , foods : List Food
    , fires : List Fire
    , growables : List Growable
    , extinguishers : List FireExtinguisher
    , retardants : List Retardant
    }


type Msg
    = RAFtick Posix
    | ToggleConditionsVisibility String String
    | ToggleConditionDetailsVisibility String String String
    | TogglePaused
    | Reset
    | LoadScene Scene


type alias Agent =
    { name : String
    , physics : PhysicalProperties
    , constantActions : List Action
    , variableActions : List Action
    , actionGenerators : List ActionGenerator
    , visibleActions : Dict String Bool
    , currentAction : String
    , currentOutcome : String
    , hunger : Range -- 0 = not hungry at all, 1 = starving
    , beggingForFood : Bool
    , topActionLastStartTimes : Dict String Posix
    , callingOut : Maybe CurrentSignal
    , holding : Holding
    , foodsGivenAway : Set Int
    , hp : Hitpoints
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
    | ShootExtinguisher Direction2d
    | PlantSeed Int


type Signal
    = FeedMe
    | GoAway
    | Eating
    | Bored


type alias CurrentSignal =
    { signal : Signal
    , started : Posix
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
    | IsCarrying ( String, Portable -> Bool )
    | FoodWasGivenAway Int


type alias PhysicalProperties =
    { position : Point2d
    , facing : Direction2d
    , velocity : Vector2d
    , acceleration : Vector2d
    , radius : Float
    }


type alias Physical a =
    { a | physics : PhysicalProperties }


type alias Collision =
    { normal : Maybe Direction2d
    , penetration : Float -- scale-dependent units
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
    , joules : Range
    }


type GrowableState
    = FertileSoil { plantedProgress : Range }
    | GrowingPlant { growth : Range, hp : Hitpoints }
    | GrownPlant { hp : Hitpoints }
    | DeadPlant { hp : Hitpoints }


type alias Growable =
    { id : Int
    , physics : PhysicalProperties
    , state : GrowableState
    }


type alias Fire =
    { id : Int
    , physics : PhysicalProperties
    , hp : Hitpoints
    }


type alias Retardant =
    { physics : PhysicalProperties
    , expiry : Posix
    }


type alias Name =
    String


type alias Generator =
    Model -> Agent -> List Action


type Holding
    = EmptyHanded
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


type Layer
    = Names
    | StatusBars

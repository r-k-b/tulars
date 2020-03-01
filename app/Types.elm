module Types exposing
    ( Action
    , ActionGenerator
    , ActionOutcome(..)
    , Agent
    , CarryableCheck(..)
    , Collision
    , Consideration
    , ConsiderationInput(..)
    , CurrentSignal
    , Fire
    , FireExtinguisher
    , Food
    , GeneratorType(..)
    , Growable
    , GrowableState(..)
    , Hitpoints(..)
    , Holding(..)
    , InputFunction(..)
    , Layer(..)
    , MenuItem
    , MenuItemType(..)
    , Model
    , Msg(..)
    , Physical
    , PhysicalProperties
    , Portable(..)
    , Range(..)
    , ReferenceToPortable(..)
    , Retardant
    , Route(..)
    , Scene
    , Signal(..)
    , close
    )

import Dict exposing (Dict)
import Direction2d exposing (Direction2d)
import Html
import Point2d exposing (Point2d)
import SelectList exposing (SelectList)
import Set exposing (Set)
import Time exposing (Posix)
import Tree.Zipper exposing (Zipper)
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
    , menu : Zipper (MenuItem Msg)
    , retardants : List Retardant
    , paused : Bool
    , tabs : SelectList Route
    }


type Route
    = About
    | MainMap
    | Variants


type alias Scene =
    { agents : List Agent
    , foods : List Food
    , fires : List Fire
    , growables : List Growable
    , extinguishers : List FireExtinguisher
    , retardants : List Retardant
    }


type Msg
    = ExportClicked
    | LoadClicked
    | LoadScene Scene
    | RAFTick Posix
    | SaveClicked
    | TabClicked Int
    | TabCloserClicked Route Int
    | TabOpenerClicked Route
    | ToggleConditionsVisibility String String
    | ToggleConditionDetailsVisibility String String String
    | TogglePaused
    | OpenMenuAt (Zipper (MenuItem Msg))


type alias Agent =
    { name : String
    , physics : PhysicalProperties
    , constantActions : List Action
    , variableActions : List Action
    , actionGenerators : List GeneratorType
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


type GeneratorType
    = AvoidFire
    | DropFoodForBeggars
    | EatCarriedFood
    | FightFires
    | HoverNear String
    | MaintainPersonalSpace
    | MoveToFood
    | MoveToGiveFoodToBeggars
    | PickUpFoodToEat
    | PlantThingsToEatLater
    | SetBeggingState
    | StopAtFood


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
    | DropHeldThing
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
    | Held CarryableCheck
    | FoodWasGivenAway Int


type CarryableCheck
    = IsAnything
    | IsAFireExtinguisher
    | IsFood


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


type alias ActionGenerator =
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


{-| Be sure to use CypressHandles.cypress.\* rather than inline strings and
attributes.
-}
type alias MenuItem msg =
    { cypressHandle : Maybe (Html.Attribute msg)
    , menuItemType : MenuItemType msg
    , name : String
    }


type MenuItemType msg
    = SimpleItem msg
    | ParentItem


type IsExpanded
    = NotExpanded
    | Expanded
    | KeepExpanded


close : IsExpanded -> IsExpanded
close isExpanded =
    case isExpanded of
        NotExpanded ->
            NotExpanded

        Expanded ->
            NotExpanded

        KeepExpanded ->
            Expanded

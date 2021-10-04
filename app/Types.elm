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
    , EntryKind(..)
    , Fire
    , FireExtinguisher
    , Flags
    , Food
    , GeneratorType(..)
    , Growable
    , GrowableState(..)
    , Hitpoints(..)
    , Holding(..)
    , InputFunction(..)
    , Layer(..)
    , LogEntry
    , MenuItem
    , MenuItemLabel(..)
    , MenuItemType(..)
    , Model
    , Msg(..)
    , PastTense(..)
    , Physical
    , PhysicalProperties
    , Portable(..)
    , Range(..)
    , ReferenceToPortable(..)
    , Retardant
    , Route(..)
    , Scene
    , Signal(..)
    , Species(..)
    , YDownCoords
    )

import Dict exposing (Dict)
import Direction2d exposing (Direction2d)
import Html
import Length exposing (Length, Meters)
import Point2d exposing (Point2d)
import SelectList exposing (SelectList)
import Set exposing (Set)
import Time exposing (Posix)
import Tree.Zipper exposing (Zipper)
import Vector2d exposing (Vector2d)


type alias Action =
    { name : String
    , outcome : ActionOutcome
    , considerations : List Consideration
    , visibleConsiderations : Dict String Bool
    }


type alias ActionGenerator =
    Model
    -> Agent
    -> List Action -- current, max


type ActionOutcome
    = DoNothing
    | MoveTo String (Point2d Meters YDownCoords)
    | MoveAwayFrom String (Point2d Meters YDownCoords)
    | ArrestMomentum
    | CallOut Signal
    | Wander
    | PickUp ReferenceToPortable
    | EatHeldFood
    | DropHeldFood
    | DropHeldThing
    | BeggingForFood Bool
    | ShootExtinguisher (Direction2d YDownCoords)
    | PlantSeed Int


{-| AKA "Actor". Something that moves around and does things.

`constantActions` don't change (without player intervention?)

`variableActions` are derived from the `actionGenerators` and are transient.
(We _could_ recompute them on demand, but keeping them around might enable some
performance wins, if the actionGenerators are expensive to run often.)

-}
type alias Agent =
    { name : String
    , physics : PhysicalProperties
    , species : Species
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


type CarryableCheck
    = IsAnything
    | IsAFireExtinguisher
    | IsFood


type alias Collision =
    { normal : Maybe (Direction2d YDownCoords)
    , penetration : Length -- scale-dependent units
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
    | MetersToTargetPoint (Point2d Meters YDownCoords)
    | Constant Float
    | CurrentSpeedInMetersPerSecond
    | TimeSinceLastShoutedFeedMe
    | IsCurrentAction
    | IAmBeggingForFood
    | Held CarryableCheck
    | FoodWasGivenAway Int


type alias CurrentSignal =
    { signal : Signal
    , started : Posix
    }


type EntryKind
    = AgentEntry { agentName : String } PastTense (Point2d Meters YDownCoords)
    | SceneLoaded String
    | SceneSaved


type alias Fire =
    { id : Int
    , physics : PhysicalProperties
    , hp : Hitpoints
    }


type alias FireExtinguisher =
    { id : Int
    , physics : PhysicalProperties
    , capacity : Float
    , remaining : Float
    }


type alias Flags =
    { gitHash : String
    , posixMillis : Int
    }


type alias Food =
    { id : Int
    , physics : PhysicalProperties
    , joules : Range
    }


type GeneratorType
    = AvoidFire
    | DropFoodForBeggars
    | EatCarriedFood
    | FightFires
    | HoverNear String
    | MaintainPersonalSpace Species
    | MoveToFood
    | MoveToGiveFoodToBeggars
    | PickUpFoodToEat
    | PlantThingsToEatLater
    | SetBeggingState
    | StayNear Species
    | StopAtFood


type alias Growable =
    { id : Int
    , physics : PhysicalProperties
    , state : GrowableState
    }


type GrowableState
    = FertileSoil { plantedProgress : Range }
    | GrowingPlant { growth : Range, hp : Hitpoints }
    | GrownPlant { hp : Hitpoints }
    | DeadPlant { hp : Hitpoints }


type Hitpoints
    = Hitpoints Float Float


type Holding
    = EmptyHanded
    | BothHands Portable


type InputFunction
    = Linear { slope : Float, offset : Float }
    | Exponential { exponent : Float }
    | Sigmoid { bend : Float, center : Float }
    | Normal { tightness : Float, center : Float, squareness : Float }
    | Asymmetric
        { centerA : Float
        , bendA : Float
        , offsetA : Float
        , squarenessA : Float
        , centerB : Float
        , bendB : Float
        , offsetB : Float
        , squarenessB : Float
        }


type Layer
    = Names


type alias LogEntry =
    { entry : EntryKind
    , time : Posix
    }


{-| Be sure to use CypressHandles.cypress.\* rather than inline strings and
attributes.
-}
type alias MenuItem msg =
    { cypressHandle : Maybe (Html.Attribute msg)
    , menuItemType : MenuItemType msg
    , name : MenuItemLabel
    }


type MenuItemLabel
    = TextLabel String
    | PauseLabel


type MenuItemType msg
    = SimpleItem msg
    | ParentItem


type alias Model =
    { time : Posix
    , agents : List Agent
    , focalPoint :
        -- TODO[camera]: keep this point in view
        Point2d Meters YDownCoords
    , foods : List Food
    , fires : List Fire
    , gitHash : String
    , growables : List Growable
    , extinguishers : List FireExtinguisher
    , log : List LogEntry
    , menu : Zipper (MenuItem Msg)
    , retardants : List Retardant
    , paused : Bool
    , showNames : Bool
    , tabs : SelectList Route
    }


type Msg
    = ExportClicked
    | FocusLocation (Point2d Meters YDownCoords)
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
    | ToggleShowNamesClicked
    | OpenMenuAt (Zipper (MenuItem Msg))


type PastTense
    = CriedForHelp
    | Died
    | PickedUp Portable


type alias Physical a =
    { a | physics : PhysicalProperties }


type alias PhysicalProperties =
    { position : Point2d Meters YDownCoords
    , facing : Direction2d YDownCoords
    , velocity : Vector2d Meters YDownCoords
    , acceleration : Vector2d Meters YDownCoords
    , radius : Length
    }


type Portable
    = Extinguisher FireExtinguisher
    | Edible Food


type Range
    = Range { min : Float, max : Float, value : Float }


type ReferenceToPortable
    = ExtinguisherID Int
    | EdibleID Int


type alias Retardant =
    { physics : PhysicalProperties
    , expiry : Posix
    }


type Route
    = About
    | AgentInfo
    | MainMap
    | Variants


type alias Scene =
    { agents : List Agent
    , foods : List Food
    , fires : List Fire
    , growables : List Growable
    , extinguishers : List FireExtinguisher
    , name : String
    , retardants : List Retardant
    }


type Signal
    = FeedMe
    | Bored


type Species
    = Human
    | Rabbit
    | Wolf


{-| Used as a Phantom Type, so we're less likely to mix up coordinate systems.
-}
type YDownCoords
    = YDownCoords

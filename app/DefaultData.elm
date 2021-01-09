module DefaultData exposing
    ( agentRadius
    , armsReach
    , defaultHysteresis
    , extinguishers
    , fires
    , foodRadius
    , foods
    , growables
    , humans
    , rabbits
    , retardantRadius
    , unseeded
    , withSuffix
    , wolves
    )

import Angle
import Dict
import Direction2d
import Length exposing (Length, Meters)
import Point2d exposing (Point2d)
import Set
import Types
    exposing
        ( Action
        , ActionOutcome(..)
        , Agent
        , Consideration
        , ConsiderationInput(..)
        , Fire
        , FireExtinguisher
        , Food
        , GeneratorType(..)
        , Growable
        , GrowableState(..)
        , Hitpoints(..)
        , Holding(..)
        , InputFunction(..)
        , Portable(..)
        , Range(..)
        , ReferenceToPortable(..)
        , Signal(..)
        , Species(..)
        , YDownCoords
        )
import Vector2d


foods : List Food
foods =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 0)
            , position = Point2d.fromMeters { x = -100, y = 100 }
            , velocity = Vector2d.zero
            , acceleration = Vector2d.zero
            , radius = foodRadius
            }
      , joules = Range { min = 0, max = 3 * 10 ^ 9, value = 3 * 10 ^ 9 }
      }
    , { id = 2
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 0)
            , position = Point2d.fromMeters { x = 100, y = 100 }
            , velocity = Vector2d.zero
            , acceleration = Vector2d.zero
            , radius = foodRadius
            }
      , joules = Range { min = 0, max = 3 * 10 ^ 9, value = 3 * 10 ^ 9 }
      }
    ]


fires : List Fire
fires =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 0)
            , position = Point2d.fromMeters { x = -100, y = -100 }
            , velocity = Vector2d.fromMeters { x = 0, y = 0 }
            , acceleration = Vector2d.zero
            , radius = fireRadius
            }
      , hp = Hitpoints 100 100
      }
    ]


growables : List Growable
growables =
    [ FertileSoil { plantedProgress = unseeded } |> basicGrowableAt (Point2d.fromMeters { x = -80, y = -70 }) 1
    , FertileSoil { plantedProgress = unseeded } |> basicGrowableAt (Point2d.fromMeters { x = -80, y = -50 }) 2
    , FertileSoil { plantedProgress = unseeded } |> basicGrowableAt (Point2d.fromMeters { x = -80, y = -30 }) 3
    , GrowingPlant { growth = plantGrowth 0, hp = Hitpoints 1 50 } |> basicGrowableAt (Point2d.fromMeters { x = -60, y = -70 }) 4
    , GrowingPlant { growth = plantGrowth 10, hp = Hitpoints 30 50 } |> basicGrowableAt (Point2d.fromMeters { x = -60, y = -50 }) 5
    , GrowingPlant { growth = plantGrowth 30, hp = Hitpoints 50 50 } |> basicGrowableAt (Point2d.fromMeters { x = -60, y = -30 }) 6
    , GrownPlant { hp = Hitpoints 1 50 } |> basicGrowableAt (Point2d.fromMeters { x = -40, y = -70 }) 7
    , GrownPlant { hp = Hitpoints 20 50 } |> basicGrowableAt (Point2d.fromMeters { x = -40, y = -50 }) 8
    , GrownPlant { hp = Hitpoints 50 50 } |> basicGrowableAt (Point2d.fromMeters { x = -40, y = -30 }) 9
    , DeadPlant { hp = Hitpoints 1 50 } |> basicGrowableAt (Point2d.fromMeters { x = -20, y = -90 }) 10
    , DeadPlant { hp = Hitpoints 30 50 } |> basicGrowableAt (Point2d.fromMeters { x = -20, y = -50 }) 11
    , DeadPlant { hp = Hitpoints 50 50 } |> basicGrowableAt (Point2d.fromMeters { x = -20, y = -30 }) 12
    ]


plantGrowth : Float -> Range
plantGrowth value =
    Range { min = 0, max = 30, value = value }


unseeded : Range
unseeded =
    Range { min = 0, max = 30, value = 0 }


basicGrowableAt : Point2d Meters YDownCoords -> Int -> GrowableState -> Growable
basicGrowableAt position id state =
    { id = id
    , physics =
        { facing = Direction2d.fromAngle (Angle.degrees 0)
        , position = position
        , velocity = Vector2d.fromMeters { x = 0, y = 0 }
        , acceleration = Vector2d.zero
        , radius = growableRadius
        }
    , state = state
    }


extinguishers : List FireExtinguisher
extinguishers =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 0)
            , position = Point2d.fromMeters { x = -20, y = -300 }
            , velocity = Vector2d.fromMeters { x = 0, y = 0 }
            , acceleration = Vector2d.zero
            , radius = extinguisherRadius
            }
      , capacity = 100
      , remaining = 100
      }
    ]


humans : List Agent
humans =
    [ { name = "Alf"
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 70)
            , position = Point2d.fromMeters { x = 200, y = 150 }
            , velocity = Vector2d.fromMeters { x = -1, y = -10 }
            , acceleration = Vector2d.zero
            , radius = agentRadius
            }
      , species = Human
      , actionGenerators =
            [ MoveToFood
            , StopAtFood
            , PickUpFoodToEat
            , EatCarriedFood
            , AvoidFire
            , MaintainPersonalSpace Human
            , DropFoodForBeggars
            , MoveToGiveFoodToBeggars
            , SetBeggingState
            , FightFires
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ stayNearOrigin
            , justChill
            , emoteBored
            , shoutFeedMe
            ]
      , currentAction = "none"
      , currentOutcome = "none"
      , hunger = Range { min = 0, max = 1, value = 0.8 }
      , beggingForFood = False
      , callingOut = Nothing
      , holding = EmptyHanded
      , topActionLastStartTimes = Dict.empty
      , foodsGivenAway = Set.empty
      , hp = Hitpoints 100 100
      }
    , { name = "Bob"
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 200)
            , position = Point2d.fromMeters { x = 100, y = 250 }
            , velocity = Vector2d.fromMeters { x = -10, y = -20 }
            , acceleration = Vector2d.fromMeters { x = -2, y = -1 }
            , radius = agentRadius
            }
      , species = Human
      , actionGenerators =
            [ MoveToFood
            , StopAtFood
            , PickUpFoodToEat
            , EatCarriedFood
            , AvoidFire
            , MaintainPersonalSpace Human
            , DropFoodForBeggars
            , MoveToGiveFoodToBeggars
            , SetBeggingState
            , FightFires
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ stayNearOrigin
            , wander
            , emoteBored
            , shoutFeedMe
            ]
      , currentAction = "none"
      , currentOutcome = "none"
      , hunger = Range { min = 0, max = 1, value = 0 }
      , beggingForFood = False
      , callingOut = Nothing
      , holding = EmptyHanded
      , topActionLastStartTimes = Dict.empty
      , foodsGivenAway = Set.empty
      , hp = Hitpoints 100 100
      }
    , { name = "Charlie"
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 150)
            , position = Point2d.fromMeters { x = -120, y = -120 }
            , velocity = Vector2d.fromMeters { x = 0, y = 0 }
            , acceleration = Vector2d.fromMeters { x = 0, y = 0 }
            , radius = agentRadius
            }
      , species = Human
      , actionGenerators =
            [ StopAtFood
            , PickUpFoodToEat
            , EatCarriedFood
            , AvoidFire
            , MaintainPersonalSpace Human
            , HoverNear "Bob"
            , SetBeggingState
            , FightFires
            , PlantThingsToEatLater
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ justChill
            , emoteBored
            , stayNearOrigin
            , shoutFeedMe
            ]
      , currentAction = "none"
      , currentOutcome = "none"
      , hunger = Range { min = 0, max = 1, value = 0.8 }
      , beggingForFood = False
      , callingOut = Nothing
      , holding = EmptyHanded
      , topActionLastStartTimes = Dict.empty
      , foodsGivenAway = Set.empty
      , hp = Hitpoints 100 100
      }
    , { name = "Dead Don"
      , physics =
            { facing = Direction2d.fromAngle (Angle.degrees 70)
            , position = Point2d.fromMeters { x = 200, y = 150 }
            , velocity = Vector2d.fromMeters { x = -1, y = -10 }
            , acceleration = Vector2d.zero
            , radius = agentRadius
            }
      , species = Human
      , actionGenerators = []
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions = []
      , currentAction = "none"
      , currentOutcome = "none"
      , hunger = Range { min = 0, max = 1, value = 0 }
      , beggingForFood = False
      , callingOut = Nothing
      , holding = EmptyHanded
      , topActionLastStartTimes = Dict.empty
      , foodsGivenAway = Set.empty
      , hp = Hitpoints 0 100
      }
    ]


rabbits : List Agent
rabbits =
    List.range 1 16
        |> List.map
            (\n ->
                standardRabbitAt
                    (Point2d.fromMeters { x = 200, y = 150.0 + toFloat n * 10.0 })
                    ("Rabbit " ++ String.fromInt n)
            )


standardRabbitAt : Point2d.Point2d Meters YDownCoords -> String -> Agent
standardRabbitAt position name =
    { name = name
    , physics =
        { facing = Direction2d.fromAngle (Angle.degrees 70)
        , position = position
        , velocity = Vector2d.fromMeters { x = 0, y = 0 }
        , acceleration = Vector2d.zero
        , radius = agentRadius
        }
    , species = Rabbit
    , actionGenerators =
        [ AvoidFire
        , EatCarriedFood
        , MaintainPersonalSpace Rabbit

        -- eat plants? (when not scared?)
        -- run from wolves?
        -- avoid humans?
        -- make burrows? (when not scared?)
        -- hide in burrows?
        -- be on guard?
        -- become scared?
        -- run fast when scared?
        ]
    , visibleActions = Dict.empty
    , variableActions = []
    , constantActions =
        [ stayNearOrigin
        , wander
        ]
    , currentAction = "none"
    , currentOutcome = "none"
    , hunger = Range { min = 0, max = 1, value = 0 }
    , beggingForFood = False
    , callingOut = Nothing
    , holding = EmptyHanded
    , topActionLastStartTimes = Dict.empty
    , foodsGivenAway = Set.empty
    , hp = Hitpoints 20 20
    }


wolves : List Agent
wolves =
    List.range 1 16
        |> List.map
            (\n ->
                standardWolfAt
                    (Point2d.fromMeters { x = -200, y = 150.0 + toFloat n * 10.0 })
                    ("Wolf " ++ String.fromInt n)
            )


standardWolfAt : Point2d.Point2d Meters YDownCoords -> String -> Agent
standardWolfAt position name =
    { name = name
    , physics =
        { facing = Direction2d.fromAngle (Angle.degrees 70)
        , position = position
        , velocity = Vector2d.fromMeters { x = 0, y = 0 }
        , acceleration = Vector2d.zero
        , radius = agentRadius
        }
    , species = Wolf
    , actionGenerators =
        [ AvoidFire
        , StayNear Wolf

        -- eat food from ground?
        -- eat corpses?
        -- run after rabbits?
        -- avoid humans?
        -- hide in tall grass?
        ]
    , visibleActions = Dict.empty
    , variableActions = []
    , constantActions =
        [ stayNearOrigin
        , justChill
        ]
    , currentAction = "none"
    , currentOutcome = "none"
    , hunger = Range { min = 0, max = 1, value = 0 }
    , beggingForFood = False
    , callingOut = Nothing
    , holding = EmptyHanded
    , topActionLastStartTimes = Dict.empty
    , foodsGivenAway = Set.empty
    , hp = Hitpoints 20 20
    }


justChill : Action
justChill =
    Action
        "just chill"
        DoNothing
        [ { name = "always 0.02"
          , function = Linear { slope = 1, offset = 0 }
          , input = Constant 0.02
          , inputMin = 0
          , inputMax = 1
          , weighting = 1
          , offset = 0
          }
        ]
        Dict.empty


wander : Action
wander =
    Action
        "wander"
        Wander
        [ { name = "always 0.04"
          , function = Linear { slope = 1, offset = 0 }
          , input = Constant 0.04
          , inputMin = 0
          , inputMax = 1
          , weighting = 1
          , offset = 0
          }
        ]
        Dict.empty


stayNearOrigin : Action
stayNearOrigin =
    Action
        "stay within 200 or 300 units of the origin"
        (MoveTo "origin" Point2d.origin)
        [ { name = "distance from origin"
          , function = Linear { slope = 1, offset = 0 }
          , input = MetersToTargetPoint Point2d.origin
          , inputMin = 200
          , inputMax = 300
          , weighting = 0.1
          , offset = 0
          }
        , defaultHysteresis 0.1
        ]
        Dict.empty


shoutFeedMe : Action
shoutFeedMe =
    Action
        "shout \"feed me!\" "
        (CallOut FeedMe)
        [ { name = "hunger"
          , function = Sigmoid { bend = 15, center = 0.5 }
          , input = Hunger
          , inputMin = 0
          , inputMax = 1
          , weighting = 0.5
          , offset = 0
          }
        , { name = "take a breath"
          , function =
                Asymmetric
                    { centerA = 0.38
                    , bendA = 10
                    , offsetA = 0.5
                    , squarenessA = 0.85
                    , centerB = 0.98
                    , bendB = -1000
                    , offsetB = 0.5
                    , squarenessB = 1
                    }
          , input = TimeSinceLastShoutedFeedMe
          , inputMin = 10000
          , inputMax = 1000
          , weighting = -1
          , offset = 1
          }
        , { name = "currently begging"
          , function = Linear { slope = 1, offset = 0 }
          , input = IAmBeggingForFood
          , inputMin = 0
          , inputMax = 1
          , weighting = 1
          , offset = 0
          }
        , defaultHysteresis 1
        ]
        Dict.empty


emoteBored : Action
emoteBored =
    Action
        "emote 'bored...'"
        (CallOut Bored)
        [ { name = "always 0.03"
          , function = Linear { slope = 1, offset = 0 }
          , input = Constant 0.03
          , inputMin = 0
          , inputMax = 1
          , weighting = 1
          , offset = 0
          }
        ]
        Dict.empty


defaultHysteresis : Float -> Consideration
defaultHysteresis weighting =
    { name = "hysteresis"
    , function = Linear { slope = 1, offset = 0 }
    , input = IsCurrentAction
    , inputMin = 0
    , inputMax = 1
    , weighting = weighting
    , offset = 1
    }


withSuffix : Int -> String -> String
withSuffix id s =
    s ++ " (#" ++ String.fromInt id ++ ")"


agentRadius : Length
agentRadius =
    Length.meters 10


armsReach : Length
armsReach =
    Length.meters 20


extinguisherRadius : Length
extinguisherRadius =
    Length.meters 10


retardantRadius : Length
retardantRadius =
    Length.meters 3


fireRadius : Length
fireRadius =
    Length.meters 6


growableRadius : Length
growableRadius =
    Length.meters 5


foodRadius : Length
foodRadius =
    Length.meters 10

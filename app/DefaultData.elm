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

import Dict
import Direction2d as Direction2d
import Maybe
import Point2d as Point2d
import Set
import Types
    exposing
        ( Action
        , ActionGenerator
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
        , Model
        , Portable(..)
        , Range(..)
        , ReferenceToPortable(..)
        , Signal(..)
        )
import Vector2d as Vector2d


foods : List Food
foods =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( -100, 100 )
            , velocity = Vector2d.zero
            , acceleration = Vector2d.zero
            , radius = foodRadius
            }
      , joules = Range { min = 0, max = 3 * 10 ^ 9, value = 3 * 10 ^ 9 }
      }
    , { id = 2
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( 100, 100 )
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
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( 100, -100 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
            , acceleration = Vector2d.zero
            , radius = fireRadius
            }
      , hp = Hitpoints 100 100
      }
    ]


growables : List Growable
growables =
    [ FertileSoil { plantedProgress = unseeded } |> basicGrowableAt ( -80, -70 ) 1
    , FertileSoil { plantedProgress = unseeded } |> basicGrowableAt ( -80, -50 ) 2
    , FertileSoil { plantedProgress = unseeded } |> basicGrowableAt ( -80, -30 ) 3
    , GrowingPlant { growth = plantGrowth 0, hp = Hitpoints 1 50 } |> basicGrowableAt ( -60, -70 ) 4
    , GrowingPlant { growth = plantGrowth 10, hp = Hitpoints 30 50 } |> basicGrowableAt ( -60, -50 ) 5
    , GrowingPlant { growth = plantGrowth 30, hp = Hitpoints 50 50 } |> basicGrowableAt ( -60, -30 ) 6
    , GrownPlant { hp = Hitpoints 1 50 } |> basicGrowableAt ( -40, -70 ) 7
    , GrownPlant { hp = Hitpoints 20 50 } |> basicGrowableAt ( -40, -50 ) 8
    , GrownPlant { hp = Hitpoints 50 50 } |> basicGrowableAt ( -40, -30 ) 9
    , DeadPlant { hp = Hitpoints 1 50 } |> basicGrowableAt ( -20, -90 ) 10
    , DeadPlant { hp = Hitpoints 30 50 } |> basicGrowableAt ( -20, -50 ) 11
    , DeadPlant { hp = Hitpoints 50 50 } |> basicGrowableAt ( -20, -30 ) 12
    ]


plantGrowth : Float -> Range
plantGrowth value =
    Range { min = 0, max = 30, value = value }


unseeded : Range
unseeded =
    Range { min = 0, max = 30, value = 0 }


basicGrowableAt : ( Float, Float ) -> Int -> GrowableState -> Growable
basicGrowableAt coords id state =
    { id = id
    , physics =
        { facing = Direction2d.fromAngle (degrees 0)
        , position = Point2d.fromCoordinates coords
        , velocity = Vector2d.fromComponents ( 0, 0 )
        , acceleration = Vector2d.zero
        , radius = growableRadius
        }
    , state = state
    }


extinguishers : List FireExtinguisher
extinguishers =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( -20, -300 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
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
            { facing = Direction2d.fromAngle (degrees 70)
            , position = Point2d.fromCoordinates ( 200, 150 )
            , velocity = Vector2d.fromComponents ( -1, -10 )
            , acceleration = Vector2d.zero
            , radius = agentRadius
            }
      , actionGenerators =
            [ MoveToFood
            , StopAtFood
            , PickUpFoodToEat
            , EatCarriedFood
            , AvoidFire
            , MaintainPersonalSpace
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
            { facing = Direction2d.fromAngle (degrees 200)
            , position = Point2d.fromCoordinates ( 100, 250 )
            , velocity = Vector2d.fromComponents ( -10, -20 )
            , acceleration = Vector2d.fromComponents ( -2, -1 )
            , radius = agentRadius
            }
      , actionGenerators =
            [ MoveToFood
            , StopAtFood
            , PickUpFoodToEat
            , EatCarriedFood
            , AvoidFire
            , MaintainPersonalSpace
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
            { facing = Direction2d.fromAngle (degrees 150)
            , position = Point2d.fromCoordinates ( -120, -120 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
            , acceleration = Vector2d.fromComponents ( 0, 0 )
            , radius = agentRadius
            }
      , actionGenerators =
            [ StopAtFood
            , PickUpFoodToEat
            , EatCarriedFood
            , AvoidFire
            , MaintainPersonalSpace
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
            { facing = Direction2d.fromAngle (degrees 70)
            , position = Point2d.fromCoordinates ( 200, 150 )
            , velocity = Vector2d.fromComponents ( -1, -10 )
            , acceleration = Vector2d.zero
            , radius = agentRadius
            }
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
    -- TODO: add a distinguishing property like human / rabbit / wolf
    [ (standardRabbitAt <| Point2d.fromCoordinates ( 200, 150 )) <| "Rabbit 1"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 160 )) <| "Rabbit 2"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 170 )) <| "Rabbit 3"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 180 )) <| "Rabbit 4"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 190 )) <| "Rabbit 5"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 200 )) <| "Rabbit 6"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 210 )) <| "Rabbit 7"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 220 )) <| "Rabbit 8"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 230 )) <| "Rabbit 9"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 240 )) <| "Rabbit 10"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 250 )) <| "Rabbit 11"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 260 )) <| "Rabbit 12"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 270 )) <| "Rabbit 13"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 280 )) <| "Rabbit 14"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 290 )) <| "Rabbit 15"
    , (standardRabbitAt <| Point2d.fromCoordinates ( 200, 300 )) <| "Rabbit 16"
    ]


standardRabbitAt : Point2d.Point2d -> String -> Agent
standardRabbitAt position name =
    -- TODO: add a distinguishing property like human / rabbit / wolf
    { name = name
    , physics =
        { facing = Direction2d.fromAngle (degrees 70)
        , position = position
        , velocity = Vector2d.fromComponents ( 0, 0 )
        , acceleration = Vector2d.zero
        , radius = agentRadius
        }
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
    , hp = Hitpoints 20 20
    }


wolves : List Agent
wolves =
    [ (standardWolfAt <| Point2d.fromCoordinates ( -200, 150 )) <| "Wolf 1"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 160 )) <| "Wolf 2"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 170 )) <| "Wolf 3"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 180 )) <| "Wolf 4"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 190 )) <| "Wolf 5"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 200 )) <| "Wolf 6"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 210 )) <| "Wolf 7"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 220 )) <| "Wolf 8"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 230 )) <| "Wolf 9"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 240 )) <| "Wolf 10"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 250 )) <| "Wolf 11"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 260 )) <| "Wolf 12"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 270 )) <| "Wolf 13"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 280 )) <| "Wolf 14"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 290 )) <| "Wolf 15"
    , (standardWolfAt <| Point2d.fromCoordinates ( -200, 300 )) <| "Wolf 16"
    ]


standardWolfAt : Point2d.Point2d -> String -> Agent
standardWolfAt position name =
    -- TODO: add a distinguishing property like human / rabbit / wolf
    { name = name
    , physics =
        { facing = Direction2d.fromAngle (degrees 70)
        , position = position
        , velocity = Vector2d.fromComponents ( 0, 0 )
        , acceleration = Vector2d.zero
        , radius = agentRadius
        }
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
    , hp = Hitpoints 20 20
    }


justChill : Action
justChill =
    Action
        "just chill"
        DoNothing
        [ { name = "always 0.02"
          , function = Linear 1 0
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
          , function = Linear 1 0
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
          , function = Linear 1 0
          , input = DistanceToTargetPoint Point2d.origin
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
        (CallOut FeedMe 1.0)
        [ { name = "hunger"
          , function = Sigmoid 15 0.5
          , input = Hunger
          , inputMin = 0
          , inputMax = 1
          , weighting = 0.5
          , offset = 0
          }
        , { name = "take a breath"
          , function = Asymmetric 0.38 10 0.5 0.85 0.98 -1000 0.5 1
          , input = TimeSinceLastShoutedFeedMe
          , inputMin = 10000
          , inputMax = 1000
          , weighting = -1
          , offset = 1
          }
        , { name = "currently begging"
          , function = Linear 1 0
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
        (CallOut Bored 1.0)
        [ { name = "always 0.03"
          , function = Linear 1 0
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
    , function = Linear 1 0
    , input = IsCurrentAction
    , inputMin = 0
    , inputMax = 1
    , weighting = weighting
    , offset = 1
    }


withSuffix : Int -> String -> String
withSuffix id s =
    s ++ " (#" ++ String.fromInt id ++ ")"


agentRadius : Float
agentRadius =
    10


armsReach : Float
armsReach =
    20


extinguisherRadius : Float
extinguisherRadius =
    10


retardantRadius : Float
retardantRadius =
    3


fireRadius : Float
fireRadius =
    6


growableRadius : Float
growableRadius =
    5


foodRadius : Float
foodRadius =
    10

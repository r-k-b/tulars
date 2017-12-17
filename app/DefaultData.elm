module DefaultData
    exposing
        ( agents
        , extinguishers
        , fires
        , foods
        , retardantRadius
        , hpMax
        )

import Dict
import Maybe exposing (withDefault)
import OpenSolid.Direction2d as Direction2d
import OpenSolid.Point2d as Point2d
import OpenSolid.Vector2d as Vector2d
import Types
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
            , ShootExtinguisher
            , Wander
            )
        , Agent
        , Consideration
        , ConsiderationInput
            ( Constant
            , CurrentSpeed
            , DistanceToTargetPoint
            , FoodWasGivenAway
            , Hunger
            , IAmBeggingForFood
            , IsCarryingExtinguisher
            , IsCarryingFood
            , IsCurrentAction
            , TimeSinceLastShoutedFeedMe
            )
        , Fire
        , FireExtinguisher
        , Food
        , Holding(BothHands, EmptyHanded)
        , InputFunction(Asymmetric, Exponential, Linear, Normal, Sigmoid)
        , Model
        , Portable(Edible)
        , ReferenceToPortable(EdibleID, ExtinguisherID)
        , Signal(Bored, FeedMe)
        )
import UtilityFunctions exposing (isHolding, portableIsFood)
import Set


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
      , joules = 3000000000
      , freshJoules = 3000000000
      }
    , { id = 2
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( 100, 100 )
            , velocity = Vector2d.zero
            , acceleration = Vector2d.zero
            , radius = foodRadius
            }
      , joules = 3000000000
      , freshJoules = 3000000000
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
      , hp = 100
      }
    ]


extinguishers : List FireExtinguisher
extinguishers =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( -20, -20 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
            , acceleration = Vector2d.zero
            , radius = extinguisherRadius
            }
      , capacity = 100
      , remaining = 100
      }
    ]


agents : List Agent
agents =
    [ { name = "Alf"
      , physics =
            { facing = Direction2d.fromAngle (degrees 70)
            , position = Point2d.fromCoordinates ( 200, 150 )
            , velocity = Vector2d.fromComponents ( -1, -10 )
            , acceleration = Vector2d.zero
            , radius = agentRadius
            }
      , actionGenerators =
            [ moveToFood
            , stopAtFood
            , pickUpFoodToEat
            , eatCarriedFood
            , avoidFire
            , maintainPersonalSpace
            , dropFoodForBeggar
            , moveToGiveFoodToBeggar
            , setBeggingState
            , fightFires
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
      , hunger = 0.8
      , beggingForFood = False
      , callingOut = Nothing
      , holding = EmptyHanded
      , topActionLastStartTimes = Dict.empty
      , foodsGivenAway = Set.empty
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
            [ moveToFood
            , stopAtFood
            , pickUpFoodToEat
            , eatCarriedFood
            , avoidFire
            , maintainPersonalSpace
            , dropFoodForBeggar
            , moveToGiveFoodToBeggar
            , setBeggingState
            , fightFires
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
      , hunger = 0.0
      , beggingForFood = False
      , callingOut = Nothing
      , holding = EmptyHanded
      , topActionLastStartTimes = Dict.empty
      , foodsGivenAway = Set.empty
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
            [ stopAtFood
            , pickUpFoodToEat
            , eatCarriedFood
            , avoidFire
            , maintainPersonalSpace
            , hoverNear "Bob"
            , setBeggingState
            , fightFires
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
      , hunger = 0.8
      , beggingForFood = False
      , callingOut = Nothing
      , holding = EmptyHanded
      , topActionLastStartTimes = Dict.empty
      , foodsGivenAway = Set.empty
      }
    ]


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
          , weighting = 1
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


moveToFood : ActionGenerator
moveToFood =
    let
        generator : Model -> Agent -> List Action
        generator model _ =
            List.map goalPerItem model.foods

        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("move toward edible food" |> withSuffix food.id)
                (MoveTo ("food" |> withSuffix food.id) food.physics.position)
                [ { name = "hunger"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "too far from food item"
                  , function = Exponential 2
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 3000
                  , inputMax = 20
                  , weighting = 0.5
                  , offset = 0
                  }
                , { name = "in range of food item"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 20
                  , inputMax = 25
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "not already carrying food"
                  , function = Linear 1 0
                  , input = IsCarryingFood
                  , inputMin = 1
                  , inputMax = 0
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "haven't given this away before"
                  , function = Linear 1 0
                  , input = FoodWasGivenAway food.id
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = -2
                  , offset = 1
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
    in
        ActionGenerator "stop at food" generator


stopAtFood : ActionGenerator
stopAtFood =
    let
        generator : Model -> Agent -> List Action
        generator model _ =
            List.map goalPerItem model.foods

        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("stop when in range of edible food" |> withSuffix food.id)
                ArrestMomentum
                [ { name = "in range of food item"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 25
                  , inputMax = 20
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "still moving"
                  , function = Sigmoid 10 0.5
                  , input = CurrentSpeed
                  , inputMin = 3
                  , inputMax = 6
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "haven't given this away before"
                  , function = Linear 1 0
                  , input = FoodWasGivenAway food.id
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = -2
                  , offset = 1
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
    in
        ActionGenerator "stop at food" generator


pickUpFoodToEat : ActionGenerator
pickUpFoodToEat =
    let
        generator : Model -> Agent -> List Action
        generator model _ =
            List.map goalPerItem model.foods

        goalPerItem : Food -> Action
        goalPerItem food =
            Action
                ("pick up food to eat" |> withSuffix food.id)
                (PickUp <| EdibleID food.id)
                [ { name = "in pickup range"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint food.physics.position
                  , inputMin = 26
                  , inputMax = 25
                  , weighting = 2
                  , offset = 0
                  }
                , { name = "hunger"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "haven't given this away before"
                  , function = Linear 1 0
                  , input = FoodWasGivenAway food.id
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = -2
                  , offset = 1
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
    in
        ActionGenerator "pick up food to eat" generator


setBeggingState : ActionGenerator
setBeggingState =
    let
        generator : Model -> Agent -> List Action
        generator _ agent =
            if agent.beggingForFood then
                [ ceaseBegging ]
            else
                [ beginBegging ]

        ceaseBegging : Action
        ceaseBegging =
            Action
                "quit begging"
                (BeggingForFood False)
                [ { name = "I'm no longer hungry"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 0.4
                  , inputMax = 0.3
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty

        beginBegging : Action
        beginBegging =
            Action
                "start begging"
                (BeggingForFood True)
                [ { name = "I'm hungry"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 0.7
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "set begging state" generator


dropFoodForBeggar : ActionGenerator
dropFoodForBeggar =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            if isHolding portableIsFood agent.holding then
                model.agents
                    |> List.filter (\other -> other.name /= agent.name)
                    |> List.filter .beggingForFood
                    |> List.map goalPerItem
            else
                []

        goalPerItem : Agent -> Action
        goalPerItem agent =
            Action
                ("drop food for beggar (" ++ agent.name ++ ")")
                DropHeldFood
                [ { name = "I am carrying some food"
                  , function = Linear 1 0
                  , input = IsCarryingFood
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "beggar is nearby"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint agent.physics.position
                  , inputMin = 40
                  , inputMax = 10
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "I don't want to eat the food"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 1
                  , inputMax = 0.5
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "pick up food to eat" generator


moveToGiveFoodToBeggar : ActionGenerator
moveToGiveFoodToBeggar =
    let
        generator : Model -> Agent -> List Action
        generator model _ =
            model.agents
                |> List.filter .beggingForFood
                |> List.map goalPerItem

        goalPerItem : Agent -> Action
        goalPerItem agent =
            Action
                ("move to give food to beggar (" ++ agent.name ++ ")")
                (MoveTo ("giveFoodTo(" ++ agent.name ++ ")") agent.physics.position)
                [ { name = "I am carrying some food"
                  , function = Linear 1 0
                  , input = IsCarryingFood
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "beggar is reasonably close"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint agent.physics.position
                  , inputMin = 500
                  , inputMax = 0
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "I don't want to eat the food"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 1
                  , inputMax = 0.5
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "pick up food to eat" generator


eatCarriedFood : ActionGenerator
eatCarriedFood =
    let
        generator : Model -> Agent -> List Action
        generator _ agent =
            List.filterMap identity <|
                case agent.holding of
                    EmptyHanded ->
                        []

                    BothHands (Edible _) ->
                        [ goalPerItem ]

                    BothHands _ ->
                        []

        goalPerItem : Maybe Action
        goalPerItem =
            Action
                "eat carried meal"
                EatHeldFood
                [ { name = "currently carrying food"
                  , function = Linear 1 0
                  , input = IsCarryingFood
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "hunger"
                  , function = Linear 1 0
                  , input = Hunger
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 3
                  , offset = 0
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
                |> Just
    in
        ActionGenerator "eat carried food" generator


avoidFire : ActionGenerator
avoidFire =
    let
        generator : Model -> Agent -> List Action
        generator model _ =
            List.map goalPerItem model.fires

        goalPerItem : Fire -> Action
        goalPerItem fire =
            Action
                ("get away from the fire" |> withSuffix fire.id)
                (MoveAwayFrom ("fire" |> withSuffix fire.id) fire.physics.position)
                [ { name = "too close to fire"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint fire.physics.position
                  , inputMin = 100
                  , inputMax = 10
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "unless I've got an extinguisher"
                  , function = Linear 1 0
                  , input = IsCarryingExtinguisher
                  , inputMin = 1
                  , inputMax = 0
                  , weighting = 0.9
                  , offset = 0.1
                  }
                ]
                Dict.empty
    in
        ActionGenerator "avoid fire" generator


fightFires : ActionGenerator
fightFires =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            if List.length model.fires > 0 then
                List.map (shootExtinguisher agent) model.fires
                    ++ List.map getWithinFightingRange model.fires
                    ++ List.map pickupNearbyExtinguishers model.extinguishers
                    ++ List.map moveToGetExtinguishers model.extinguishers
            else
                []

        shootExtinguisher : Agent -> Fire -> Action
        shootExtinguisher agent fire =
            let
                direction =
                    Direction2d.from agent.physics.position fire.physics.position
                        |> withDefault (Direction2d.fromAngle 0)
            in
                Action
                    ("use extinguisher on fire" |> withSuffix fire.id)
                    (ShootExtinguisher direction)
                    [ { name = "within range"
                      , function = Linear 1 0
                      , input = DistanceToTargetPoint fire.physics.position
                      , inputMin = 60
                      , inputMax = 55
                      , weighting = 3
                      , offset = 0
                      }
                    , { name = "carrying an extinguisher"
                      , function = Linear 1 0
                      , input = IsCarryingExtinguisher
                      , inputMin = 0
                      , inputMax = 1
                      , weighting = 1
                      , offset = 0
                      }
                    ]
                    Dict.empty

        getWithinFightingRange : Fire -> Action
        getWithinFightingRange fire =
            Action
                ("get within range" |> withSuffix fire.id)
                (MoveTo ("fire" |> withSuffix fire.id) fire.physics.position)
                [ { name = "close enough"
                  , function = Asymmetric 0.3 10 0.5 0.8 0.97 -1000 0.5 1
                  , input = DistanceToTargetPoint fire.physics.position
                  , inputMin = 400
                  , inputMax = 30
                  , weighting = 3
                  , offset = 0
                  }
                , { name = "carrying an extinguisher"
                  , function = Linear 1 0
                  , input = IsCarryingExtinguisher
                  , inputMin = 0
                  , inputMax = 1
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty

        pickupNearbyExtinguishers : FireExtinguisher -> Action
        pickupNearbyExtinguishers fext =
            Action
                ("pick up a nearby fire extinguisher" |> withSuffix fext.id)
                (PickUp <| ExtinguisherID fext.id)
                [ { name = "in pickup range"
                  , function = Exponential 0.01
                  , input = DistanceToTargetPoint fext.physics.position
                  , inputMin = 26
                  , inputMax = 25
                  , weighting = 2
                  , offset = 0
                  }
                ]
                Dict.empty

        moveToGetExtinguishers : FireExtinguisher -> Action
        moveToGetExtinguishers fext =
            Action
                ("move to get an extinguisher" |> withSuffix fext.id)
                (MoveTo ("fire extinguisher" |> withSuffix fext.id) fext.physics.position)
                [ { name = "get close enough to pick it up"
                  , function = Asymmetric 0.3 10 0.5 0.8 0.97 -1000 0.5 1
                  , input = DistanceToTargetPoint fext.physics.position
                  , inputMin = 20
                  , inputMax = 400
                  , weighting = 1
                  , offset = 0
                  }
                , { name = "not already carrying an extinguisher"
                  , function = Linear 1 0
                  , input = IsCarryingExtinguisher
                  , inputMin = 1
                  , inputMax = 0
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "fight fires" generator


maintainPersonalSpace : ActionGenerator
maintainPersonalSpace =
    let
        generator : Model -> Agent -> List Action
        generator model agent =
            model.agents
                |> List.filter (\other -> other.name /= agent.name)
                |> List.map goalPerItem

        goalPerItem : Agent -> Action
        goalPerItem otherAgent =
            Action
                ("maintain personal space from " ++ otherAgent.name)
                (MoveAwayFrom otherAgent.name otherAgent.physics.position)
                [ { name = "space invaded"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint otherAgent.physics.position
                  , inputMin = 15
                  , inputMax = 5
                  , weighting = 1
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "avoid fire" generator


hoverNear : String -> ActionGenerator
hoverNear targetAgentName =
    let
        generator : Model -> Agent -> List Action
        generator model _ =
            model.agents
                |> List.filter (\other -> other.name == targetAgentName)
                |> List.map goalPerItem

        goalPerItem : Agent -> Action
        goalPerItem otherAgent =
            Action
                ("hang around " ++ targetAgentName)
                (MoveTo otherAgent.name otherAgent.physics.position)
                [ { name = "close, but not close enough"
                  , function = Normal 2.6 0.5 10
                  , input = DistanceToTargetPoint otherAgent.physics.position
                  , inputMin = 30
                  , inputMax = 70
                  , weighting = 0.6
                  , offset = 0
                  }
                ]
                Dict.empty
    in
        ActionGenerator "avoid fire" generator


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
    s ++ " (#" ++ toString id ++ ")"


agentRadius : Float
agentRadius =
    10


extinguisherRadius : Float
extinguisherRadius =
    10


retardantRadius : Float
retardantRadius =
    3


fireRadius : Float
fireRadius =
    6


foodRadius : Float
foodRadius =
    10


type alias HPMax =
    { fire : Float
    , agent : Float
    }


hpMax : HPMax
hpMax =
    { fire = 100
    , agent = 100
    }

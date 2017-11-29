module DefaultData
    exposing
        ( agents
        , extinguishers
        , fires
        , foods
        )

import Dict
import OpenSolid.Direction2d as Direction2d
import OpenSolid.Point2d as Point2d
import OpenSolid.Vector2d as Vector2d
import Types
    exposing
        ( Action
        , ActionGenerator(ActionGenerator)
        , ActionOutcome
            ( ArrestMomentum
            , CallOut
            , DoNothing
            , EatHeldFood
            , MoveAwayFrom
            , MoveTo
            , PickUpFood
            , Wander
            )
        , Agent
        , Consideration
        , ConsiderationInput
            ( Constant
            , CurrentSpeed
            , DistanceToTargetPoint
            , Hunger
            , IsCarryingFood
            , IsCurrentAction
            , TimeSinceLastShoutedFeedMe
            )
        , Fire
        , FireExtinguisher
        , Food
        , Holding(BothHands, EachHand, EmptyHanded, OnlyLeftHand, OnlyRightHand)
        , InputFunction(Asymmetric, Exponential, Linear, Normal, Sigmoid)
        , Model
        , Portable(Edible)
        , Signal(FeedMe)
        )


foods : List Food
foods =
    [ { id = 1
      , physics =
            { facing = Direction2d.fromAngle (degrees 0)
            , position = Point2d.fromCoordinates ( -100, 100 )
            , velocity = Vector2d.zero
            , acceleration = Vector2d.zero
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
            }
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
            }
      , actionGenerators =
            [ moveToFood
            , stopAtFood
            , pickUpFoodToEat
            , eatCarriedFood
            , avoidFire
            , maintainPersonalSpace
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ stayNearOrigin
            , justChill
            ]
      , currentAction = "none"
      , hunger = 0.8
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      , holding = EmptyHanded
      , desireToEat = False
      }
    , { name = "Bob"
      , physics =
            { facing = Direction2d.fromAngle (degrees 200)
            , position = Point2d.fromCoordinates ( 100, 250 )
            , velocity = Vector2d.fromComponents ( -10, -20 )
            , acceleration = Vector2d.fromComponents ( -2, -1 )
            }
      , actionGenerators =
            [ moveToFood
            , stopAtFood
            , pickUpFoodToEat
            , eatCarriedFood
            , avoidFire
            , maintainPersonalSpace
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ stayNearOrigin
            , wander
            ]
      , currentAction = "none"
      , hunger = 0.0
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      , holding = EmptyHanded
      , desireToEat = False
      }
    , { name = "Charlie"
      , physics =
            { facing = Direction2d.fromAngle (degrees 150)
            , position = Point2d.fromCoordinates ( -120, -120 )
            , velocity = Vector2d.fromComponents ( 0, 0 )
            , acceleration = Vector2d.fromComponents ( 0, 0 )
            }
      , actionGenerators =
            [ stopAtFood
            , pickUpFoodToEat
            , eatCarriedFood
            , avoidFire
            , maintainPersonalSpace
            , hoverNear "Bob"
            ]
      , visibleActions = Dict.empty
      , variableActions = []
      , constantActions =
            [ justChill
            , stayNearOrigin
            , shoutFeedMe
            ]
      , currentAction = "none"
      , hunger = 0.8
      , timeLastShoutedFeedMe = Nothing
      , callingOut = Nothing
      , holding = EmptyHanded
      , desireToEat = False
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
          , input = Constant 0.02
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
        (MoveTo Point2d.origin)
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
        , defaultHysteresis 1
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
                (MoveTo food.physics.position)
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
                (PickUpFood food.id)
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
                , defaultHysteresis 0.1
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

                    OnlyLeftHand (Edible _) ->
                        [ goalPerItem ]

                    OnlyLeftHand _ ->
                        []

                    OnlyRightHand (Edible _) ->
                        [ goalPerItem ]

                    OnlyRightHand _ ->
                        []

                    EachHand _ (Edible _) ->
                        [ goalPerItem ]

                    EachHand (Edible _) _ ->
                        [ goalPerItem ]

                    EachHand _ _ ->
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
                (MoveAwayFrom fire.physics.position)
                [ { name = "too close to fire"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint fire.physics.position
                  , inputMin = 100
                  , inputMax = 10
                  , weighting = 3
                  , offset = 0
                  }
                , defaultHysteresis 0.1
                ]
                Dict.empty
    in
        ActionGenerator "avoid fire" generator


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
                (MoveAwayFrom otherAgent.physics.position)
                [ { name = "space invaded"
                  , function = Linear 1 0
                  , input = DistanceToTargetPoint otherAgent.physics.position
                  , inputMin = 15
                  , inputMax = 5
                  , weighting = 1
                  , offset = 0
                  }
                , defaultHysteresis 0.1
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
                (MoveTo otherAgent.physics.position)
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

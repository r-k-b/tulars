module TestMain exposing (suite)

import Angle
import DefaultData exposing (agentRadius, foodRadius)
import Dict
import Direction2d
import Expect exposing (Expectation, FloatingPointTolerance(..))
import Main exposing (closeTabAt, pickUpFood)
import Point2d
import SelectList exposing (SelectList)
import Set
import Test exposing (Test, describe, test)
import Types exposing (Agent, Food, Hitpoints(..), Holding(..), Portable(..), Range(..))
import Vector2d


agent : Agent
agent =
    { name = "Alf"
    , physics =
        { facing = Direction2d.fromAngle (Angle.degrees 70)
        , position = Point2d.origin
        , velocity = Vector2d.zero
        , acceleration = Vector2d.zero
        , radius = agentRadius
        }
    , actionGenerators = []
    , visibleActions = Dict.empty
    , variableActions = []
    , constantActions = []
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


food1 : Food
food1 =
    { id = 1
    , physics =
        { facing = Direction2d.fromAngle (Angle.degrees 0)
        , position = Point2d.fromMeters { x = 0, y = 10 }
        , velocity = Vector2d.zero
        , acceleration = Vector2d.zero
        , radius = foodRadius
        }
    , joules = Range { min = 0, max = 3 * 10 ^ 9, value = 3 * 10 ^ 9 }
    }


food2 : Food
food2 =
    { id = 2
    , physics =
        { facing = Direction2d.fromAngle (Angle.degrees 0)
        , position = Point2d.fromMeters { x = 10, y = 0 }
        , velocity = Vector2d.zero
        , acceleration = Vector2d.zero
        , radius = foodRadius
        }
    , joules = Range { min = 0, max = 3 * 10 ^ 9, value = 3 * 10 ^ 9 }
    }


food3OutOfReach : Food
food3OutOfReach =
    { id = 3
    , physics =
        { facing = Direction2d.fromAngle (Angle.degrees 0)
        , position = Point2d.fromMeters { x = 100, y = 100 }
        , velocity = Vector2d.zero
        , acceleration = Vector2d.zero
        , radius = foodRadius
        }
    , joules = Range { min = 0, max = 3 * 10 ^ 9, value = 3 * 10 ^ 9 }
    }


suite : Test
suite =
    describe "main"
        [ describe "object pickup"
            [ describe "food items"
                [ test "no such food ID means nothing happens" <|
                    \_ ->
                        pickUpFood
                            agent
                            3
                            [ food1, food2 ]
                            |> Expect.equal ( agent, [ food1, food2 ] )
                , test "the first food item is picked up" <|
                    \_ ->
                        pickUpFood
                            agent
                            1
                            [ food1, food2 ]
                            |> Expect.equal
                                ( { agent | holding = BothHands (Edible food1) }
                                , [ food2 ]
                                )
                , test "the second food item is picked up" <|
                    \_ ->
                        pickUpFood
                            agent
                            2
                            [ food1, food2 ]
                            |> Expect.equal
                                ( { agent | holding = BothHands (Edible food2) }
                                , [ food1 ]
                                )
                , test "a food item out of range is not picked up" <|
                    \_ ->
                        pickUpFood
                            agent
                            3
                            [ food1, food2, food3OutOfReach ]
                            |> Expect.equal
                                ( agent
                                , [ food1, food2, food3OutOfReach ]
                                )
                ]
            ]
        , let
            sl : List a -> a -> List a -> SelectList a
            sl =
                SelectList.fromLists
          in
          describe "tabs"
            [ test "closing the active tab should select the next tab to the right" <|
                \_ ->
                    sl [ 'a', 'b' ] 'c' [ 'd', 'e' ]
                        |> closeTabAt 0 'c'
                        |> Expect.equal (sl [ 'a', 'b' ] 'd' [ 'e' ])
            , test "closing a left tab should preserve the selection" <|
                \_ ->
                    sl [ 'a', 'b', 'c' ] 'd' [ 'e' ]
                        |> closeTabAt -2 'b'
                        |> Expect.equal (sl [ 'a', 'c' ] 'd' [ 'e' ])
            , test "closing a right tab should preserve the selection" <|
                \_ ->
                    sl [ 'a' ] 'b' [ 'c', 'd', 'e' ]
                        |> closeTabAt 2 'd'
                        |> Expect.equal (sl [ 'a' ] 'b' [ 'c', 'e' ])
            , test "closing the far right tab should preserve the selection" <|
                \_ ->
                    sl [ 'a' ] 'b' [ 'c', 'd', 'e' ]
                        |> closeTabAt 3 'e'
                        |> Expect.equal (sl [ 'a' ] 'b' [ 'c', 'd' ])
            , test "closing the far left tab should preserve the selection" <|
                \_ ->
                    sl [ 'a', 'b', 'c' ] 'd' [ 'e' ]
                        |> closeTabAt -3 'a'
                        |> Expect.equal (sl [ 'b', 'c' ] 'd' [ 'e' ])
            ]
        ]

module TestMenu exposing (suite)

import Expect exposing (Expectation, FloatingPointTolerance(..))
import Menu exposing (CullInfo(..), cullInvisible)
import Test exposing (Test, describe, test)
import Tree exposing (tree)
import Tree.Zipper as Zipper


suite : Test
suite =
    describe "culling tree zippers"
        [ test "basic example" <|
            \_ ->
                let
                    input =
                        tree 'a'
                            [ tree 'b'
                                [ tree 'e'
                                    [ tree 'g'
                                        []
                                    ]
                                ]
                            , tree 'c'
                                [ tree 'f'
                                    []
                                ]
                            , tree 'd'
                                []
                            ]
                            |> Zipper.fromTree
                            |> Zipper.forward

                    expected =
                        tree ( 'a', HadChildren )
                            [ tree ( 'b', HadChildren )
                                [ tree ( 'e', HadChildren ) [] ]
                            , tree ( 'c', HadChildren ) []
                            , tree ( 'd', NoChildren ) []
                            ]
                            |> Just
                in
                Maybe.map cullInvisible input |> Expect.equal expected
        ]

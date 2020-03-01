module TestMenu exposing (suite)

import Expect exposing (Expectation, FloatingPointTolerance(..))
import Maybe exposing (andThen)
import Menu exposing (AnnotatedCrumb, AnnotatedCrumbChildren(..), CullInfo, zipperToAnnotatedBreadcrumbs, zipperToBreadcrumbs)
import Test exposing (Test, describe, test)
import Tree exposing (tree)
import Tree.Zipper as Zipper exposing (Zipper)


suite : Test
suite =
    describe "culling tree zippers"
        [ test "should be able to extract the basic breadcrumb trail" <|
            \_ ->
                let
                    input : Maybe (Zipper Char)
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
                            |> andThen Zipper.forward

                    expected : Maybe ( Char, List Char )
                    expected =
                        ( 'a', [ 'b', 'e' ] )
                            |> Just
                in
                Maybe.map zipperToBreadcrumbs input |> Expect.equal expected
        , test "should be able to extract an annotated breadcrumb trail" <|
            \_ ->
                let
                    input : Maybe (Zipper Char)
                    input =
                        tree 'a'
                            [ tree 'b'
                                [ tree 'e'
                                    [ tree 'g'
                                        [ tree 'h'
                                            []
                                        ]
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
                            |> andThen Zipper.forward

                    expected : AnnotatedCrumb Char
                    expected =
                        { label = 'a'
                        , siblingsBefore = []
                        , siblingsAfter = []
                        , directChildren =
                            CrumbTrailContinues
                                []
                                { label = 'b'
                                , siblingsBefore = []
                                , siblingsAfter =
                                    [ { label = 'c', hadChildren = True }
                                    , { label = 'd', hadChildren = False }
                                    ]
                                , directChildren =
                                    CrumbTrailContinues []
                                        { label = 'e'
                                        , siblingsBefore = []
                                        , siblingsAfter = []
                                        , directChildren =
                                            NoMoreCrumbs
                                                [ { label = 'g'
                                                  , hadChildren = True
                                                  }
                                                ]
                                        }
                                        []
                                }
                                []
                        }
                in
                Maybe.map zipperToAnnotatedBreadcrumbs input
                    |> Expect.equal (Just expected)
        , test "should be able to extract an annotated breadcrumb trail with 'before' siblings" <|
            \_ ->
                let
                    input : Maybe (Zipper Char)
                    input =
                        tree 'a'
                            [ tree 'c'
                                [ tree 'f'
                                    []
                                ]
                            , tree 'b'
                                [ tree 'e'
                                    [ tree 'g'
                                        [ tree 'h'
                                            []
                                        ]
                                    ]
                                ]
                            , tree 'd'
                                []
                            ]
                            |> Zipper.fromTree
                            |> Zipper.forward
                            |> andThen Zipper.nextSibling
                            |> andThen Zipper.forward

                    expected : AnnotatedCrumb Char
                    expected =
                        { label = 'a'
                        , siblingsBefore = []
                        , siblingsAfter = []
                        , directChildren =
                            CrumbTrailContinues
                                []
                                { label = 'b'
                                , siblingsBefore =
                                    [ { label = 'c', hadChildren = True }
                                    ]
                                , siblingsAfter =
                                    [ { label = 'd', hadChildren = False }
                                    ]
                                , directChildren =
                                    CrumbTrailContinues []
                                        { label = 'e'
                                        , siblingsBefore = []
                                        , siblingsAfter = []
                                        , directChildren =
                                            NoMoreCrumbs
                                                [ { label = 'g'
                                                  , hadChildren = True
                                                  }
                                                ]
                                        }
                                        []
                                }
                                []
                        }
                in
                Maybe.map zipperToAnnotatedBreadcrumbs input
                    |> Expect.equal (Just expected)
        ]

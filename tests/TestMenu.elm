module TestMenu exposing (suite)

import Expect exposing (Expectation)
import Maybe exposing (andThen)
import Maybe.Extra as ME
import Menu
    exposing
        ( AnnotatedCrumb
        , AnnotatedCrumbChildren(..)
        , zipperToAnnotatedBreadcrumbs
        , zipperToBreadcrumbs
        )
import Test exposing (Test, describe, test)
import Tree exposing (tree)
import Tree.Zipper as Zipper exposing (Zipper, firstChild, label, nextSibling)


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
                    initialTree : Zipper Char
                    initialTree =
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

                    input : Maybe (Zipper Char)
                    input =
                        initialTree
                            |> Zipper.forward
                            |> andThen Zipper.forward

                    a : Zipper Char
                    a =
                        initialTree

                    b : Maybe (Zipper Char)
                    b =
                        a |> firstChild

                    c : Maybe (Zipper Char)
                    c =
                        b |> Maybe.andThen nextSibling

                    d : Maybe (Zipper Char)
                    d =
                        c |> Maybe.andThen nextSibling

                    {- There's a builtin `e` already. -}
                    ee : Maybe (Zipper Char)
                    ee =
                        b |> Maybe.andThen firstChild

                    g : Maybe (Zipper Char)
                    g =
                        ee |> Maybe.andThen firstChild

                    expected : Maybe (AnnotatedCrumb Char)
                    expected =
                        Just expectedHelper
                            |> ME.andMap b
                            |> ME.andMap c
                            |> ME.andMap d
                            |> ME.andMap ee
                            |> ME.andMap g

                    expectedHelper :
                        Zipper Char
                        -> Zipper Char
                        -> Zipper Char
                        -> Zipper Char
                        -> Zipper Char
                        -> AnnotatedCrumb Char
                    expectedHelper b_ c_ d_ ee_ g_ =
                        { focus = a
                        , siblingsBefore = []
                        , siblingsAfter = []
                        , directChildren =
                            CrumbTrailContinues
                                []
                                { focus = b_
                                , siblingsBefore = []
                                , siblingsAfter = [ c_, d_ ]
                                , directChildren =
                                    CrumbTrailContinues
                                        []
                                        { focus = ee_
                                        , siblingsBefore = []
                                        , siblingsAfter = []
                                        , directChildren =
                                            NoMoreCrumbs [ g_ ]
                                        }
                                        []
                                }
                                []
                        }
                in
                Maybe.map zipperToAnnotatedBreadcrumbs input
                    |> Expect.all
                        [ Expect.equal expected

                        -- sanity checks on helpers
                        , checkHelperLabel 'a' a
                        , checkHelperLabel 'b' (b |> orBadData)
                        , checkHelperLabel 'c' (c |> orBadData)
                        , checkHelperLabel 'd' (d |> orBadData)
                        , checkHelperLabel 'e' (ee |> orBadData)
                        , checkHelperLabel 'g' (g |> orBadData)
                        ]
        , test "should be able to extract an annotated breadcrumb trail with 'before' siblings" <|
            \_ ->
                let
                    initialTree : Zipper Char
                    initialTree =
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

                    input : Maybe (Zipper Char)
                    input =
                        initialTree
                            |> Zipper.firstChild
                            |> andThen Zipper.nextSibling
                            |> andThen Zipper.firstChild

                    a : Zipper Char
                    a =
                        initialTree

                    b : Maybe (Zipper Char)
                    b =
                        a |> firstChild |> andThen nextSibling

                    c : Maybe (Zipper Char)
                    c =
                        a |> firstChild

                    d : Maybe (Zipper Char)
                    d =
                        b |> Maybe.andThen nextSibling

                    ee : Maybe (Zipper Char)
                    ee =
                        b |> Maybe.andThen firstChild

                    g : Maybe (Zipper Char)
                    g =
                        ee |> Maybe.andThen firstChild

                    expected : Maybe (AnnotatedCrumb Char)
                    expected =
                        Just expectedHelper
                            |> ME.andMap b
                            |> ME.andMap c
                            |> ME.andMap d
                            |> ME.andMap ee
                            |> ME.andMap g

                    expectedHelper :
                        Zipper Char
                        -> Zipper Char
                        -> Zipper Char
                        -> Zipper Char
                        -> Zipper Char
                        -> AnnotatedCrumb Char
                    expectedHelper b_ c_ d_ ee_ g_ =
                        { focus = a
                        , siblingsBefore = []
                        , siblingsAfter = []
                        , directChildren =
                            CrumbTrailContinues
                                []
                                { focus = b_
                                , siblingsBefore = [ c_ ]
                                , siblingsAfter = [ d_ ]
                                , directChildren =
                                    CrumbTrailContinues
                                        []
                                        { focus = ee_
                                        , siblingsBefore = []
                                        , siblingsAfter = []
                                        , directChildren =
                                            NoMoreCrumbs [ g_ ]
                                        }
                                        []
                                }
                                []
                        }
                in
                Maybe.map zipperToAnnotatedBreadcrumbs input
                    |> Expect.all
                        [ Expect.equal expected

                        -- sanity checks on helpers
                        , checkHelperLabel 'a' a
                        , checkHelperLabel 'b' (b |> orBadData)
                        , checkHelperLabel 'c' (c |> orBadData)
                        , checkHelperLabel 'd' (d |> orBadData)
                        , checkHelperLabel 'e' (ee |> orBadData)
                        , checkHelperLabel 'g' (g |> orBadData)
                        ]
        ]


orBadData : Maybe (Zipper Char) -> Zipper Char
orBadData =
    Maybe.withDefault (tree 'Z' [] |> Zipper.fromTree)


checkHelperLabel : Char -> Zipper Char -> (a -> Expectation)
checkHelperLabel char helper _ =
    Expect.equal char (helper |> label)

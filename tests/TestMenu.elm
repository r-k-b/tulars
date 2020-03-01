module TestMenu exposing (suite)

import Expect exposing (Expectation, FloatingPointTolerance(..))
import Maybe exposing (andThen)
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
                    dammit =
                        dammitAll "extract-annotated-trail"

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

                    b : Zipper Char
                    b =
                        a |> firstChild |> dammit "b"

                    c : Zipper Char
                    c =
                        b |> nextSibling |> dammit "c"

                    d : Zipper Char
                    d =
                        c |> nextSibling |> dammit "d"

                    {- There's a builtin `e` already. -}
                    ee : Zipper Char
                    ee =
                        b |> firstChild |> dammit "e"

                    g : Zipper Char
                    g =
                        ee |> firstChild |> dammit "g"

                    expected : AnnotatedCrumb Char
                    expected =
                        { focus = a
                        , siblingsBefore = []
                        , siblingsAfter = []
                        , directChildren =
                            CrumbTrailContinues
                                []
                                { focus = b
                                , siblingsBefore = []
                                , siblingsAfter = [ c, d ]
                                , directChildren =
                                    CrumbTrailContinues
                                        []
                                        { focus = ee
                                        , siblingsBefore = []
                                        , siblingsAfter = []
                                        , directChildren =
                                            NoMoreCrumbs [ g ]
                                        }
                                        []
                                }
                                []
                        }
                in
                Maybe.map zipperToAnnotatedBreadcrumbs input
                    |> Expect.all
                        [ Expect.equal (Just expected)

                        -- sanity checks on helpers
                        , checkHelperLabel 'a' a
                        , checkHelperLabel 'b' b
                        , checkHelperLabel 'c' c
                        , checkHelperLabel 'd' d
                        , checkHelperLabel 'e' ee
                        , checkHelperLabel 'g' g
                        ]
        , test "should be able to extract an annotated breadcrumb trail with 'before' siblings" <|
            \_ ->
                let
                    dammit =
                        dammitAll "with-before-sibs"

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

                    b : Zipper Char
                    b =
                        a |> firstChild |> andThen nextSibling |> dammit "b"

                    c : Zipper Char
                    c =
                        a |> firstChild |> dammit "c"

                    d : Zipper Char
                    d =
                        b |> nextSibling |> dammit "d"

                    ee : Zipper Char
                    ee =
                        b |> firstChild |> dammit "e"

                    g : Zipper Char
                    g =
                        ee |> firstChild |> dammit "g"

                    expected : AnnotatedCrumb Char
                    expected =
                        { focus = a
                        , siblingsBefore = []
                        , siblingsAfter = []
                        , directChildren =
                            CrumbTrailContinues
                                []
                                { focus = b
                                , siblingsBefore = [ c ]
                                , siblingsAfter = [ d ]
                                , directChildren =
                                    CrumbTrailContinues
                                        []
                                        { focus = ee
                                        , siblingsBefore = []
                                        , siblingsAfter = []
                                        , directChildren =
                                            NoMoreCrumbs [ g ]
                                        }
                                        []
                                }
                                []
                        }
                in
                Maybe.map zipperToAnnotatedBreadcrumbs input
                    |> Expect.all
                        [ Expect.equal (Just expected)

                        -- sanity checks on helpers
                        , checkHelperLabel 'a' a
                        , checkHelperLabel 'b' b
                        , checkHelperLabel 'c' c
                        , checkHelperLabel 'd' d
                        , checkHelperLabel 'e' ee
                        , checkHelperLabel 'g' g
                        ]
        ]


{-| Unwraps `Maybe`s, at the cost of extra boilerplate and fragility.

Only suitable for test code.

-}
dammitAll : String -> String -> Maybe.Maybe a -> a
dammitAll testName partOfTest maybeA =
    (maybeA
        |> Maybe.map always
        |> Maybe.withDefault
            (\() ->
                [ "Somebody done had mistaken assumptions about the test data:\n"
                , "    test: '"
                , testName
                , "'\n"
                , "    part: '"
                , partOfTest
                , "'"
                ]
                    |> String.join ""
                    |> Debug.todo
            )
    )
        ()


checkHelperLabel : Char -> Zipper Char -> (a -> Expectation)
checkHelperLabel char helper a =
    Expect.equal char (helper |> label)

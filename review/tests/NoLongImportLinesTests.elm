module NoLongImportLinesTests exposing (testRule, tests)

import NoLongImportLines
import Review.Test exposing (ReviewResult)
import Test exposing (Test, describe, test)


testRule : String -> ReviewResult
testRule =
    Review.Test.run NoLongImportLines.rule


standardErrorUnder : String -> { message : String, details : List String, under : String }
standardErrorUnder under =
    { message =
        "Do not keep `import` lines longer than 120 characters."
    , details =
        [ "Even though `elm-format` keeps the items sorted, having very long"
            ++ " lines like this invites merge conflicts, and reduces"
            ++ " readability."
        ]
    , under = under
    }


tests : Test
tests =
    describe "NoLongImportLines"
        [ describe "detection"
            [ test "should not warn about short one-liners" <|
                \() ->
                    testRule """module A exposing (..)
            import Foo exposing (bar)"""
                        |> Review.Test.expectNoErrors
            , test "should not warn about short multi-liners" <|
                \() ->
                    testRule """module A exposing (..)
            import Test
                exposing
                    ( Test
                    , describe
                    , test
                    )"""
                        |> Review.Test.expectNoErrors
            , test "should not warn about long multi-liners" <|
                \() ->
                    testRule """module A exposing (..)
            import Test
                exposing
                    ( Test
                    , describeWhyThisNameIsSoUnreasonablyLongButNeverthelessSomeoneHasProbablyHadToExposeANameAtLeastThisLongOrLongerThan120Chars
                    , test
                    )"""
                        |> Review.Test.expectNoErrors
            , test "should warn about long one-liners" <|
                \() ->
                    let
                        longLine =
                            "import Html exposing (Attribute, Html, a, button, code, div, em, h2, h3, h4, h5, li, p, span, strong, table, td, text, th, tr, ul)"
                    in
                    testRule ("module A exposing (..)\n" ++ longLine)
                        |> Review.Test.expectErrors
                            [ Review.Test.error
                                (standardErrorUnder longLine)
                            ]
            ]
        ]

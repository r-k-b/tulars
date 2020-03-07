module NoLongImportLines exposing (rule)

{-| Some Elm tooling will always change `import` lines from multi-line to
single-line when updating an `import` statement, even when the single line
would be extremely long and prone to merge conflicts.

This rule enforces that no single-line `import` statements longer then 120
characters should exist.


# Usage

After adding [`elm-review`][elm-review] to your project, import this rule from
your `ReviewConfig.elm` file and add it to the config. E.g.:

    import NoLongImportLines
    import Review.Rule exposing (Rule)

    config : List Rule
    config =
        [ NoLongImportLines.rule ]

[elm-review]: https://package.elm-lang.org/packages/jfmengels/elm-review/latest/

@docs rule

-}

import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.Import exposing (Import)
import Elm.Syntax.Node as Node exposing (Node)
import Elm.Syntax.Range exposing (Range)
import Elm.Syntax.TypeAnnotation
    exposing
        ( RecordDefinition
        , RecordField
        , TypeAnnotation(..)
        )
import Review.Rule as Rule exposing (Error, Rule, error)



-- Create a new rule


{-| A rule for elm-review that discourages the use of very long `import`
statements, which are prone to merge conflicts.
-}
rule : Rule
rule =
    -- Define the rule with the same name as the module it is defined in
    Rule.newSchema "NoLongImportLines"
        -- Make it look at declarations
        |> Rule.withSimpleImportVisitor importVisitor
        |> Rule.fromSchema


details =
    { message =
        "Do not keep `import` lines longer than 120 characters."
    , details =
        [ "Even though `elm-format` keeps the items sorted, having very long"
            ++ " lines like this invites merge conflicts, and reduces"
            ++ " readability."
        ]
    }


importVisitor : Node Import -> List Error
importVisitor node =
    let
        range : Range
        range =
            node |> Node.range

        isSingleLine : Bool
        isSingleLine =
            range.start.row == range.end.row

        exceedsMaxLength : Bool
        exceedsMaxLength =
            range.end.column > 120
    in
    if isSingleLine && exceedsMaxLength then
        [ node |> Node.range |> error details ]

    else
        []

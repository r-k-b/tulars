module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import NoBooleanCase
import NoDebug.Log
import NoDebug.TodoOrToString
import NoExposingEverything
import NoImportingEverything
import NoLongImportLines
import NoMissingSubscriptionsCall
import NoMissingTypeExpose
import NoRecursiveUpdate
import NoUselessSubscriptions
import Review.Rule exposing (Rule)


config : List Rule
config =
    [ NoBooleanCase.rule
    , NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule
    , NoExposingEverything.rule
    , NoImportingEverything.rule []
    , NoLongImportLines.rule
    , NoMissingSubscriptionsCall.rule
    , NoMissingTypeExpose.rule
    , NoRecursiveUpdate.rule
    , NoUselessSubscriptions.rule
    ]

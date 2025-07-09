module Main exposing (main)

import Browser
import Types
    exposing
        ( Flags
        , Model
        , Msg(..)
        )
import View exposing (view)


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }


initialModelAt : Model
initialModelAt =
    { demoButtonsEnabled = True
    , demoCounter = 0
    }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( initialModelAt
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg model =
    case msg of
        ToggleDemoClicked ->
            { model | demoButtonsEnabled = not model.demoButtonsEnabled }

        DemoBtn1Clicked ->
            { model | demoCounter = model.demoCounter + 1 }

        DemoBtn2Clicked ->
            { model | demoCounter = model.demoCounter + 1 }

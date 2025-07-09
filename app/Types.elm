module Types exposing
    ( Flags
    , Model
    , Msg(..)
    )


type alias Flags =
    { posixMillis : Int
    }


type alias Model =
    { demoButtonsEnabled : Bool
    , demoCounter : Int
    }


type Msg
    = ToggleDemoClicked
    | DemoBtn1Clicked
    | DemoBtn2Clicked

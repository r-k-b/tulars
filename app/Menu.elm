module Menu exposing (..)


type alias MenuItem =
    { id : Int
    , name : String
    , parent : Maybe Int
    }

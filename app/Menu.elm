module Menu exposing (..)

import SelectList exposing (SelectList)


type Menu a
    = NoneSelected (List a)
    | OneSelected (SelectList a)

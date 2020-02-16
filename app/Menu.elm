module Menu exposing (..)

import SelectList exposing (SelectList)


type Menu a
    = NoneSelected (List a)
    | OneSelected (SelectList a)


type MenuItem msg
    = SimpleItem String msg
    | ParentItem String (Menu (MenuItem msg))

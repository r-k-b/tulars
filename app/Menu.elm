module Menu exposing (..)


type MenuItem msg
    = SimpleItem String msg
    | ParentItem String IsExpanded (List (MenuItem msg))


type IsExpanded
    = NotExpanded
    | Expanded


toggleExpanded : MenuItem msg -> MenuItem msg
toggleExpanded item =
    case item of
        SimpleItem _ _ ->
            item

        ParentItem name isExpanded children ->
            ParentItem name (flipExpand isExpanded) children


flipExpand : IsExpanded -> IsExpanded
flipExpand isExpanded =
    case isExpanded of
        NotExpanded ->
            Expanded

        Expanded ->
            NotExpanded


getItemChildren : MenuItem msg -> List (MenuItem msg)
getItemChildren menuItem =
    case menuItem of
        SimpleItem _ _ ->
            []

        ParentItem _ _ children ->
            children

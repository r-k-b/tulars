module Menu exposing (..)


type MenuItem msg
    = SimpleItem String msg
    | ParentItem String IsExpanded (List (MenuItem msg))


type IsExpanded
    = NotExpanded
    | Expanded
    | KeepExpanded


closeItem : MenuItem msg -> MenuItem msg
closeItem item =
    case item of
        SimpleItem _ _ ->
            item

        ParentItem name isExpanded children ->
            ParentItem name (close isExpanded) children


keepItemExpanded : MenuItem msg -> MenuItem msg
keepItemExpanded item =
    case item of
        SimpleItem _ _ ->
            item

        ParentItem name _ children ->
            ParentItem name KeepExpanded children


close : IsExpanded -> IsExpanded
close isExpanded =
    case isExpanded of
        NotExpanded ->
            NotExpanded

        Expanded ->
            NotExpanded

        KeepExpanded ->
            Expanded


expandedAsBool : IsExpanded -> Bool
expandedAsBool isExpanded =
    case isExpanded of
        NotExpanded ->
            False

        Expanded ->
            True

        KeepExpanded ->
            True


getItemChildren : MenuItem msg -> List (MenuItem msg)
getItemChildren menuItem =
    case menuItem of
        SimpleItem _ _ ->
            []

        ParentItem _ _ children ->
            children

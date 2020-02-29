module Menu exposing (..)

import Tree exposing (Tree, tree)
import Tree.Zipper as Zipper exposing (Zipper, toTree)


type MenuItem msg
    = SimpleItem String msg
    | ParentItem String


type IsExpanded
    = NotExpanded
    | Expanded
    | KeepExpanded


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


type CullInfo
    = NoChildren
    | HadChildren


cullInvisible : Zipper a -> Tree ( a, CullInfo )
cullInvisible zipper =
    let
        truncatedListOfChildren : List ( a, CullInfo )
        truncatedListOfChildren =
            zipper
                |> Zipper.children
                |> List.map snip
    in
    zipper
        |> toTree
        |> Tree.map (\a -> ( a, HadChildren ))


snip : Tree a -> ( a, CullInfo )
snip tree =
    ( tree |> Tree.label
    , case tree |> Tree.children of
        [] ->
            NoChildren

        _ ->
            HadChildren
    )


cullInvisibleHelper : Zipper a -> Tree ( a, CullInfo ) -> ( Maybe (Zipper a), Tree ( a, CullInfo ) )
cullInvisibleHelper focus innerTree =
    let
        label : ( a, CullInfo )
        label =
            ( focus |> Zipper.label, HadChildren )

        children : List (Tree ( a, CullInfo ))
        children =
            innerTree
                :: (focus
                        |> Zipper.children
                        |> List.map
                            (Tree.map
                                (\tree -> ( tree |> Tree.label |> (\l -> tree l []), NoChildren ))
                            )
                   )
    in
    ( focus |> Zipper.parent, tree label children )

module Menu exposing (..)

import Tree exposing (Tree)
import Tree.Zipper as Zipper exposing (Zipper)


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


type alias CullInfo a =
    { label : a
    , hadChildren : Bool
    }


zipperToBreadcrumbs : Zipper a -> ( a, List a )
zipperToBreadcrumbs zipper =
    zipperToBreadcrumbsHelper
        (zipper |> Zipper.parent)
        (zipper |> Zipper.label)
        []


zipperToBreadcrumbsHelper : Maybe (Zipper a) -> a -> List a -> ( a, List a )
zipperToBreadcrumbsHelper maybeZipper label crumbs =
    case maybeZipper of
        Just parent ->
            zipperToBreadcrumbsHelper
                (parent |> Zipper.parent)
                (parent |> Zipper.label)
                (label :: crumbs)

        Nothing ->
            ( label, crumbs )


type alias AnnotatedCrumb a =
    { label : a
    , siblingsBefore : List (CullInfo a)
    , siblingsAfter : List (CullInfo a)
    , directChildren : AnnotatedCrumbChildren a
    }


type AnnotatedCrumbChildren a
    = NoMoreCrumbs (List (CullInfo a))
    | CrumbTrailContinues (List (CullInfo a)) (AnnotatedCrumb a) (List (CullInfo a))


zipperToAnnotatedBreadcrumbs : Zipper a -> AnnotatedCrumb a
zipperToAnnotatedBreadcrumbs zipper =
    let
        endOfTheTrail : AnnotatedCrumb a
        endOfTheTrail =
            { label = zipper |> Zipper.label
            , siblingsBefore = zipper |> Zipper.siblingsBeforeFocus |> getCullInfos
            , siblingsAfter = zipper |> Zipper.siblingsAfterFocus |> getCullInfos
            , directChildren =
                zipper
                    |> Zipper.children
                    |> getCullInfos
                    |> NoMoreCrumbs
            }
    in
    zipperToAnnotatedBreadcrumbsHelper
        (zipper |> Zipper.parent)
        endOfTheTrail


getCullInfos : List (Tree a) -> List (CullInfo a)
getCullInfos trees =
    trees |> List.map getCullInfo


getCullInfo : Tree a -> CullInfo a
getCullInfo tree =
    { label = tree |> Tree.label
    , hadChildren = tree |> Tree.children |> List.length |> (<) 0
    }


zipperToAnnotatedBreadcrumbsHelper :
    Maybe (Zipper a)
    -> AnnotatedCrumb a
    -> AnnotatedCrumb a
zipperToAnnotatedBreadcrumbsHelper maybeZipper crumbs =
    case maybeZipper of
        Just parent ->
            let
                nextCrumb : AnnotatedCrumb a
                nextCrumb =
                    { label = parent |> Zipper.label
                    , siblingsBefore =
                        parent
                            |> Zipper.siblingsBeforeFocus
                            |> getCullInfos
                    , siblingsAfter =
                        parent
                            |> Zipper.siblingsAfterFocus
                            |> getCullInfos
                    , directChildren =
                        CrumbTrailContinues
                            []
                            crumbs
                            []
                    }
            in
            zipperToAnnotatedBreadcrumbsHelper
                (parent |> Zipper.parent)
                nextCrumb

        Nothing ->
            crumbs

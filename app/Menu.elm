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


type CullInfo
    = NoChildren
    | HadChildren


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
    , siblingsBefore : List a
    , siblingsAfter : List a
    , directChildren : AnnotatedCrumbChildren a
    }


type AnnotatedCrumbChildren a
    = NoMoreCrumbs (List a)
    | CrumbTrailContinues (List a) (AnnotatedCrumb a) (List a)


zipperToAnnotatedBreadcrumbs : Zipper a -> AnnotatedCrumb a
zipperToAnnotatedBreadcrumbs zipper =
    let
        endOfTheTrail : AnnotatedCrumb a
        endOfTheTrail =
            { label = zipper |> Zipper.label
            , siblingsBefore = zipper |> Zipper.siblingsBeforeFocus |> getLabels
            , siblingsAfter = zipper |> Zipper.siblingsAfterFocus |> getLabels
            , directChildren =
                zipper
                    |> Zipper.children
                    |> getLabels
                    |> NoMoreCrumbs
            }
    in
    zipperToAnnotatedBreadcrumbsHelper
        (zipper |> Zipper.parent)
        endOfTheTrail


getLabels : List (Tree a) -> List a
getLabels trees =
    trees |> List.map Tree.label


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
                            |> getLabels
                    , siblingsAfter =
                        parent
                            |> Zipper.siblingsAfterFocus
                            |> getLabels
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

module Menu exposing
    ( AnnotatedCrumb
    , AnnotatedCrumbChildren(..)
    , zipperToAnnotatedBreadcrumbs
    , zipperToBreadcrumbs
    )

import Maybe exposing (withDefault)
import Tree.Zipper as Zipper exposing (Zipper)


type alias AnnotatedCrumb a =
    { focus : Zipper a
    , siblingsBefore : List (Zipper a)
    , siblingsAfter : List (Zipper a)
    , directChildren : AnnotatedCrumbChildren a
    }


type AnnotatedCrumbChildren a
    = NoMoreCrumbs (List (Zipper a))
    | CrumbTrailContinues (List (Zipper a)) (AnnotatedCrumb a) (List (Zipper a))


zipperToAnnotatedBreadcrumbs : Zipper a -> AnnotatedCrumb a
zipperToAnnotatedBreadcrumbs zipper =
    let
        endOfTheTrail : AnnotatedCrumb a
        endOfTheTrail =
            { focus = zipper
            , siblingsBefore = zipper |> siblingsBeforeFocus []
            , siblingsAfter = zipper |> siblingsAfterFocus [] |> List.reverse
            , directChildren =
                let
                    firstChild : Maybe (Zipper a)
                    firstChild =
                        zipper |> Zipper.firstChild
                in
                firstChild
                    |> Maybe.map (\first -> siblingsAfterFocus [ first ] first)
                    |> withDefault []
                    |> List.reverse
                    |> NoMoreCrumbs
            }
    in
    zipperToAnnotatedBreadcrumbsHelper
        (zipper |> Zipper.parent)
        endOfTheTrail


zipperToBreadcrumbs : Zipper a -> ( a, List a )
zipperToBreadcrumbs zipper =
    zipperToBreadcrumbsHelper
        (zipper |> Zipper.parent)
        (zipper |> Zipper.label)
        []


siblingsAfterFocus : List (Zipper a) -> Zipper a -> List (Zipper a)
siblingsAfterFocus accumulator zipper =
    case zipper |> Zipper.nextSibling of
        Just sibling ->
            siblingsAfterFocus (sibling :: accumulator) sibling

        Nothing ->
            accumulator


siblingsBeforeFocus : List (Zipper a) -> Zipper a -> List (Zipper a)
siblingsBeforeFocus accumulator zipper =
    case zipper |> Zipper.previousSibling of
        Just sibling ->
            siblingsBeforeFocus (sibling :: accumulator) sibling

        Nothing ->
            accumulator


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
                    { focus = parent
                    , siblingsBefore = parent |> siblingsBeforeFocus []
                    , siblingsAfter = parent |> siblingsAfterFocus [] |> List.reverse
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

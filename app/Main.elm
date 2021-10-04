module Main exposing (closeTabAt, main, pickUpFood)

import Angle
import Browser
import Browser.Events exposing (onAnimationFrame)
import CypressHandles exposing (cypress)
import DefaultData exposing (armsReach, retardantRadius, unseeded)
import Dict exposing (Dict)
import Direction2d exposing (Direction2d)
import Html
import Length exposing (Meters)
import List exposing (map)
import List.Extra as LE
import MapAccumulate exposing (mapAccumL)
import Maybe exposing (withDefault)
import Maybe.Extra as ME
import Physics exposing (collide)
import Point2d exposing (Point2d)
import Quantity as Q
import Scenes exposing (loadScene, sceneA, sceneB, sceneC, sceneD)
import SelectList exposing (SelectList, selected)
import Set exposing (Set, insert)
import Time exposing (Posix)
import Tree exposing (Tree, tree)
import Tree.Zipper as Zipper exposing (Zipper)
import Tuple3
import Types
    exposing
        ( Action
        , ActionOutcome(..)
        , Agent
        , Collision
        , CurrentSignal
        , EntryKind(..)
        , Fire
        , FireExtinguisher
        , Flags
        , Food
        , Growable
        , GrowableState(..)
        , Hitpoints(..)
        , Holding(..)
        , MenuItem
        , MenuItemLabel(..)
        , MenuItemType(..)
        , Model
        , Msg(..)
        , PastTense(..)
        , Physical
        , PhysicalProperties
        , Portable(..)
        , Range(..)
        , ReferenceToPortable(..)
        , Retardant
        , Route(..)
        , Signal(..)
        , YDownCoords
        )
import UtilityFunctions
    exposing
        ( boolString
        , computeUtility
        , computeVariableActions
        , getActions
        , hpAsFloat
        , hpRawValue
        , isBeggingRelated
        , isMovementAction
        , log
        , logAll
        , mapRange
        , normaliseRange
        , onlyArrestMomentum
        , rangeCurrentValue
        , setHitpoints
        , updateRange
        )
import Vector2d exposing (Vector2d)
import View exposing (view)


main : Program Flags Model Msg
main =
    Browser.document
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }



-- MODEL


initialModelAt : String -> Posix -> Model
initialModelAt gitHash posixTime =
    { agents = []
    , extinguishers = []
    , fires = []
    , focalPoint = Point2d.origin
    , foods = []
    , gitHash = gitHash
    , growables = []
    , log = []
    , menu = initialMenu
    , paused = False
    , retardants = []
    , showNames = False
    , tabs = SelectList.fromLists [] MainMap []
    , time = posixTime
    }
        |> loadScene sceneA


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initialModelAt
        flags.gitHash
        (flags.posixMillis |> Time.millisToPosix)
    , Cmd.none
    )


initialMenu : Zipper (MenuItem Msg)
initialMenu =
    let
        s : String -> Msg -> Tree (MenuItem Msg)
        s name msg =
            tree
                { cypressHandle = Nothing
                , menuItemType = SimpleItem msg
                , name = TextLabel name
                }
                []

        labelledS :
            MenuItemLabel
            -> Msg
            ->
                Tree
                    { cypressHandle : Maybe (Html.Attribute Msg)
                    , menuItemType : MenuItemType Msg
                    , name : MenuItemLabel
                    }
        labelledS name msg =
            tree
                { cypressHandle = Nothing
                , menuItemType = SimpleItem msg
                , name = name
                }
                []

        p : String -> List (Tree (MenuItem Msg)) -> Tree (MenuItem Msg)
        p name =
            tree
                { cypressHandle = Nothing
                , menuItemType = ParentItem
                , name = TextLabel name
                }

        cyHandle : Html.Attribute Msg -> Tree (MenuItem Msg) -> Tree (MenuItem Msg)
        cyHandle attr =
            Tree.mapLabel
                (\label ->
                    { label | cypressHandle = Just attr }
                )
    in
    p "root"
        [ p "Open a Scene" sceneButtons
        , p "Options"
            [ -- should we make the label change to suit the current state?
              s "Show/Hide Names" ToggleShowNamesClicked
            ]
        , s "Save" SaveClicked
        , s "Load" LoadClicked
        , labelledS PauseLabel TogglePaused
        , s "Export JSON" ExportClicked
        , s "Variants" (Variants |> TabOpenerClicked)
        , s "Agent Info" (AgentInfo |> TabOpenerClicked)
            |> cyHandle cypress.mainMenu.agentInfo
        , s "About" (About |> TabOpenerClicked)
            |> cyHandle cypress.mainMenu.about
        , p "Deeper Tree example 2"
            [ p "dt ex2 1"
                [ p "dt ex2 1 a" [ s "dt ex2 1 a x" TogglePaused ]
                , p "dt ex2 1 b" [ s "dt ex2 1 b y" TogglePaused ]
                , p "dt ex2 1 c" [ s "dt ex2 1 c z" TogglePaused ]
                ]
            , p "dt ex2 2"
                [ p "dt ex2 2 a" [ s "dt ex2 2 a x" TogglePaused ]
                , p "dt ex2 2 b" [ s "dt ex2 2 b y" TogglePaused ]
                , p "dt ex2 2 c" [ s "dt ex2 2 c z" TogglePaused ]
                ]
            , p "dt ex2 3"
                [ p "dt ex2 3 a" [ s "dt ex2 3 a x" TogglePaused ]
                , p "dt ex2 3 b" [ s "dt ex2 3 b y" TogglePaused ]
                , p "dt ex2 3 c" [ s "dt ex2 3 c z" TogglePaused ]
                ]
            ]
        ]
        |> Zipper.fromTree


sceneButtons :
    List
        (Tree
            { cypressHandle : Maybe.Maybe a
            , menuItemType : MenuItemType Msg
            , name : MenuItemLabel
            }
        )
sceneButtons =
    [ sceneA
    , sceneB
    , sceneC
    , sceneD
    ]
        |> List.map
            (\scene ->
                tree
                    { cypressHandle = Nothing
                    , menuItemType = SimpleItem (LoadScene scene)
                    , name = TextLabel scene.name
                    }
                    []
            )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg model =
    case msg of
        ExportClicked ->
            -- todo
            model

        FocusLocation point ->
            { model | focalPoint = point }

        LoadClicked ->
            -- todo
            model

        LoadScene scene ->
            model
                |> loadScene scene
                |> andCloseTheMenu

        RAFTick newT ->
            if model.paused then
                { model | time = newT }

            else
                moveWorld newT model

        SaveClicked ->
            -- todo
            model |> log SceneSaved

        TabClicked relativeIndex ->
            { model | tabs = model.tabs |> selectTabAt relativeIndex }

        TabCloserClicked route index ->
            { model | tabs = model.tabs |> closeTabAt index route }

        TabOpenerClicked route ->
            { model | tabs = model.tabs |> openTabFor route }
                |> andCloseTheMenu

        ToggleConditionsVisibility agentName actionName ->
            let
                updateActionVisibility : Dict String Bool -> Dict String Bool
                updateActionVisibility viz =
                    let
                        prior : Bool
                        prior =
                            Dict.get actionName viz
                                |> withDefault False
                    in
                    Dict.insert actionName (not prior) viz

                newAgents : List Agent
                newAgents =
                    map
                        (\agent ->
                            if agent.name == agentName then
                                { agent | visibleActions = updateActionVisibility agent.visibleActions }

                            else
                                agent
                        )
                        model.agents
            in
            { model | agents = newAgents }

        ToggleConditionDetailsVisibility agentName actionName considerationName ->
            let
                updateConsiderationVisibility : Dict String Bool -> Dict String Bool
                updateConsiderationVisibility viz =
                    let
                        prior : Bool
                        prior =
                            Dict.get considerationName viz
                                |> withDefault False
                    in
                    Dict.insert considerationName (not prior) viz

                updateAgentActions : List Action -> List Action
                updateAgentActions list =
                    map
                        (\action ->
                            if action.name == actionName then
                                { action
                                    | visibleConsiderations =
                                        updateConsiderationVisibility action.visibleConsiderations
                                }

                            else
                                action
                        )
                        list

                newAgents : List Agent
                newAgents =
                    map
                        (\agent ->
                            if agent.name == agentName then
                                { agent
                                    | constantActions = updateAgentActions agent.constantActions
                                    , variableActions = updateAgentActions agent.variableActions
                                }

                            else
                                agent
                        )
                        model.agents
            in
            { model | agents = newAgents }

        TogglePaused ->
            { model | paused = not model.paused }
                |> andCloseTheMenu

        ToggleShowNamesClicked ->
            { model | showNames = not model.showNames }

        OpenMenuAt zipper ->
            { model | menu = zipper }


selectTabAt : Int -> SelectList Route -> SelectList Route
selectTabAt relativeIndex tabs =
    tabs |> SelectList.attempt (SelectList.selectBy relativeIndex)


{-| Selects an existing tab with a matching route, or creates a new tab to the
right of the current tab, selecting the new tab.
-}
openTabFor : Route -> SelectList Route -> SelectList Route
openTabFor targetRoute tabs =
    if (tabs |> selected) == targetRoute then
        tabs

    else
        ME.orList
            [ tabs |> SelectList.selectBeforeIf ((==) targetRoute)
            , tabs |> SelectList.selectAfterIf ((==) targetRoute)
            ]
            |> withDefault (tabs |> SelectList.insertBefore targetRoute)


closeTabAt : Int -> a -> SelectList a -> SelectList a
closeTabAt relativeIndex route tabs =
    let
        foundTabs : Maybe (SelectList a)
        foundTabs =
            tabs |> SelectList.selectBy relativeIndex

        backToOriginalSelection : Int
        backToOriginalSelection =
            if relativeIndex < 0 then
                -relativeIndex - 1

            else if relativeIndex > 0 then
                min relativeIndex (SelectList.afterLength tabs - 1)
                    |> (*) -1

            else
                0

        weAreDeletingTheExpectedTabAt : SelectList a -> Bool
        weAreDeletingTheExpectedTabAt validOffset =
            route == (validOffset |> SelectList.selected)
    in
    case foundTabs of
        Just validOffset ->
            if weAreDeletingTheExpectedTabAt validOffset then
                validOffset
                    |> SelectList.attempt SelectList.delete
                    |> SelectList.attempt
                        (SelectList.selectBy backToOriginalSelection)

            else
                tabs

        Nothing ->
            tabs


moveProjectiles : Int -> List (Physical a) -> List (Physical a)
moveProjectiles dTime projectiles =
    map (doPhysics dTime) projectiles


{-| todo: use verlet integration?
-}
doPhysics : Int -> Physical a -> Physical a
doPhysics deltaTime x =
    let
        p : PhysicalProperties
        p =
            x.physics

        dV : Vector2d Meters YDownCoords
        dV =
            Vector2d.scaleBy (toFloat deltaTime / 1000) p.velocity

        newPosition : Point2d Meters YDownCoords
        newPosition =
            Point2d.translateBy dV p.position

        newVelocity : Vector2d Meters YDownCoords
        newVelocity =
            Vector2d.plus p.velocity p.acceleration

        updatedPhysics : PhysicalProperties
        updatedPhysics =
            { position = newPosition
            , facing = p.facing
            , velocity = newVelocity
            , acceleration = p.acceleration
            , radius = p.radius
            }
    in
    { x | physics = updatedPhysics }


moveAgent : Posix -> Int -> Agent -> ( Agent, Maybe EntryKind )
moveAgent currentTime dT agent =
    let
        dV : Vector2d Meters YDownCoords
        dV =
            Vector2d.scaleBy ((toFloat dT |> min 1000) / 1000) agent.physics.velocity

        newPosition : Point2d Meters YDownCoords
        newPosition =
            Point2d.translateBy dV agent.physics.position

        newVelocity : Vector2d Meters YDownCoords
        newVelocity =
            -- how do we adjust for large/small dT?
            agent.physics.velocity
                |> applyFriction
                |> Vector2d.plus deltaAcceleration

        deltaAcceleration : Vector2d Meters YDownCoords
        deltaAcceleration =
            Vector2d.scaleBy (toFloat dT / 1000) agent.physics.acceleration

        topMovementActionIsArrestMomentum : Maybe Action
        topMovementActionIsArrestMomentum =
            getActions agent
                |> List.filter isMovementAction
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head
                |> Maybe.andThen onlyArrestMomentum

        movementVectors : List (Vector2d Meters YDownCoords)
        movementVectors =
            case topMovementActionIsArrestMomentum of
                Just arrestMomentumAction ->
                    getMovementVector currentTime dT agent arrestMomentumAction
                        |> Maybe.map List.singleton
                        |> withDefault []

                Nothing ->
                    List.filterMap (getMovementVector currentTime dT agent) (getActions agent)

        newAcceleration : Vector2d Meters YDownCoords
        newAcceleration =
            movementVectors
                |> Vector2d.sum
                |> deadzone
                |> Vector2d.direction
                |> ME.unwrap Vector2d.zero
                    (Vector2d.withLength (Length.meters 64))

        newFacing : Direction2d YDownCoords
        newFacing =
            Vector2d.direction newAcceleration
                |> withDefault agent.physics.facing

        topAction : Maybe Action
        topAction =
            getActions agent |> LE.maximumBy (computeUtility agent currentTime)

        newOutcome : String
        newOutcome =
            topAction
                |> Maybe.map .outcome
                |> Maybe.map outcomeToString
                |> withDefault "none"

        newTopActionLastStartTimes : Dict String Posix
        newTopActionLastStartTimes =
            if newOutcome == agent.currentOutcome then
                agent.topActionLastStartTimes

            else
                agent.topActionLastStartTimes
                    |> Dict.insert newOutcome currentTime

        newCallAndEntry : ( Maybe CurrentSignal, Maybe EntryKind )
        newCallAndEntry =
            topAction
                |> Maybe.andThen extractCallouts
                |> updateCurrentSignal agent currentTime agent.callingOut

        ( newCall, callEntry ) =
            newCallAndEntry

        increasedHunger : Range
        increasedHunger =
            agent.hunger
                |> mapRange (\hunger -> hunger + 0.000003 * toFloat dT)

        hitpointsAfterStarvation : Hitpoints
        hitpointsAfterStarvation =
            case agent.hp of
                Hitpoints current max ->
                    if (agent.hunger |> normaliseRange) > 0.5 then
                        Hitpoints ((current - 0.001 * toFloat dT) |> clamp 0 max) max

                    else
                        Hitpoints current max

        newPhysics : PhysicalProperties
        newPhysics =
            let
                p : PhysicalProperties
                p =
                    agent.physics
            in
            { p
                | position = newPosition
                , facing = newFacing
                , velocity = newVelocity
                , acceleration = newAcceleration
            }

        beggingForFood : Bool
        beggingForFood =
            topAction
                |> Maybe.andThen isBeggingRelated
                |> withDefault agent.beggingForFood

        ( newHunger, newHolding ) =
            if
                topAction
                    |> Maybe.map (.outcome >> (==) EatHeldFood)
                    |> withDefault False
            then
                agent |> eat

            else
                ( increasedHunger, agent.holding )
    in
    ( { agent
        | physics = newPhysics
        , currentAction = topAction |> Maybe.map .name |> withDefault "none"
        , currentOutcome = newOutcome
        , hunger = newHunger
        , beggingForFood = beggingForFood
        , topActionLastStartTimes = newTopActionLastStartTimes
        , callingOut = newCall
        , holding = newHolding
        , hp = hitpointsAfterStarvation
      }
    , callEntry
    )


extractCallouts : Action -> Maybe Signal
extractCallouts action =
    case action.outcome of
        CallOut x ->
            Just x

        _ ->
            Nothing


{-| If the signal type is unchanged, preserve the original time.
-}
updateCurrentSignal :
    Agent
    -> Posix
    -> Maybe CurrentSignal
    -> Maybe Signal
    -> ( Maybe CurrentSignal, Maybe EntryKind )
updateCurrentSignal agent time currentSignal maybeNewSignal =
    case maybeNewSignal of
        Just newSignal ->
            case currentSignal of
                Just priorSignal ->
                    if priorSignal.signal == newSignal then
                        ( Just priorSignal, Nothing )

                    else
                        ( Just { signal = newSignal, started = time }
                        , Just <|
                            AgentEntry { agentName = agent.name }
                                CriedForHelp
                                agent.physics.position
                        )

                Nothing ->
                    ( Just { signal = newSignal, started = time }
                    , Just <|
                        AgentEntry { agentName = agent.name }
                            CriedForHelp
                            agent.physics.position
                    )

        Nothing ->
            ( Nothing, Nothing )


deadzone : Vector2d Meters coords -> Vector2d Meters coords
deadzone v =
    if Vector2d.length v |> Q.greaterThan (Length.centimeters 5) then
        v

    else
        Vector2d.zero


getMovementVector : Posix -> Int -> Agent -> Action -> Maybe (Vector2d Meters YDownCoords)
getMovementVector currentTime deltaTime agent action =
    case action.outcome of
        DoNothing ->
            Nothing

        MoveTo _ point ->
            let
                weighted : Vector2d Meters YDownCoords
                weighted =
                    Vector2d.from agent.physics.position point
                        |> Vector2d.direction
                        |> ME.unwrap Vector2d.zero
                            (Vector2d.withLength <| Length.meters weighting)

                weighting : Float
                weighting =
                    computeUtility agent currentTime action
            in
            Just weighted

        MoveAwayFrom _ point ->
            let
                weighted : Vector2d Meters YDownCoords
                weighted =
                    Vector2d.from point agent.physics.position
                        |> Vector2d.direction
                        |> ME.unwrap Vector2d.zero
                            (Vector2d.withLength <| Length.meters weighting)

                weighting : Float
                weighting =
                    computeUtility agent currentTime action
            in
            Just weighted

        ArrestMomentum ->
            let
                weighting : Float
                weighting =
                    computeUtility agent currentTime action
            in
            if weighting < 0.1 then
                Nothing

            else
                Just
                    (agent.physics.velocity
                        |> Vector2d.reverse
                        |> Vector2d.direction
                        |> ME.unwrap Vector2d.zero
                            (Vector2d.withLength <| Length.meters weighting)
                    )

        CallOut _ ->
            Nothing

        Wander ->
            agent.physics.facing
                |> Vector2d.withLength (Length.meters 1)
                |> Vector2d.rotateBy
                    (Angle.degrees 10 |> Q.multiplyBy (toFloat deltaTime / 1000))
                |> Just

        PickUp _ ->
            Nothing

        EatHeldFood ->
            Nothing

        DropHeldFood ->
            Nothing

        DropHeldThing ->
            Nothing

        BeggingForFood _ ->
            Nothing

        ShootExtinguisher _ ->
            Nothing

        PlantSeed _ ->
            Nothing


{-| Scales a vector, representing how much speed is lost to friction.
-}
applyFriction : Vector2d Meters coords -> Vector2d Meters coords
applyFriction velocity =
    let
        speed : Float
        speed =
            Vector2d.length velocity |> Length.inMeters

        t : Float
        t =
            1.1

        u : Float
        u =
            0.088

        n : number
        n =
            30

        k : Float
        k =
            0.26

        -- \frac{1}{e^{k\left(x-n\right)}+t}+u\ \left\{0\le x\right\}
        -- see https://www.desmos.com/calculator/7i2gwxpej1
        factor : Float
        factor =
            1 / (e ^ (k * (speed - n)) + t) + u
    in
    if speed < 0.1 then
        Vector2d.zero

    else
        velocity |> Vector2d.scaleBy factor


regenerateVariableActions : Model -> Agent -> Agent
regenerateVariableActions model agent =
    let
        newActions : List Action
        newActions =
            computeVariableActions model agent
                |> map preserveProperties

        preservableProperties : Dict.Dict String (Dict.Dict String Bool)
        preservableProperties =
            agent.variableActions
                |> map (\action -> ( action.name, action.visibleConsiderations ))
                |> Dict.fromList

        preserveProperties : Action -> Action
        preserveProperties action =
            let
                oldVCs : Dict String Bool
                oldVCs =
                    Dict.get action.name preservableProperties
                        |> withDefault Dict.empty
            in
            { action | visibleConsiderations = oldVCs }
    in
    { agent | variableActions = newActions }


moveWorld : Posix -> Model -> Model
moveWorld newTime model =
    let
        deltaT : Int
        deltaT =
            (Time.posixToMillis newTime - Time.posixToMillis model.time)
                |> min 50

        survivingAgentsAndDeathEntries : ( List Agent, List EntryKind )
        survivingAgentsAndDeathEntries =
            model.agents
                |> List.partition (.hp >> hpAsFloat >> (<) 0)
                |> Tuple.mapSecond (List.map toDeathEntry)

        ( survivingAgents, deathEntries ) =
            survivingAgentsAndDeathEntries

        movedAgentsAndEntries : List ( Agent, Maybe EntryKind )
        movedAgentsAndEntries =
            survivingAgents
                |> map
                    (moveAgent newTime deltaT
                        >> Tuple.mapFirst (regenerateVariableActions model)
                    )

        movedAgents : List Agent
        movedAgents =
            movedAgentsAndEntries |> List.map Tuple.first

        movementEntries : List EntryKind
        movementEntries =
            movedAgentsAndEntries |> List.filterMap Tuple.second

        newRetardants : List Retardant
        newRetardants =
            List.foldr
                (createRetardantProjectiles newTime)
                []
                movedAgents

        retardantsWithDecay : List Retardant
        retardantsWithDecay =
            model.retardants
                |> moveProjectiles deltaT
                |> List.filterMap (decayRetardant newTime)
                |> (++) newRetardants

        ( retardantsAfterCollisionWithFire, firesAfterCollisionWithRetardants ) =
            List.foldr
                collideRetardantsAndFires
                ( [], model.fires )
                retardantsWithDecay

        foodsAfterDecay : List Food
        foodsAfterDecay =
            model.foods
                |> List.filterMap (rotFood deltaT)

        changesAfterPickedItems : PickedItems
        changesAfterPickedItems =
            List.foldr
                (foldOverPickedItems newTime)
                { agentAcc = []
                , foodAcc = foodsAfterDecay
                , extinguisherAcc = model.extinguishers
                , logEntryAcc = []
                }
                movedAgents

        { agentAcc, foodAcc, extinguisherAcc, logEntryAcc } =
            changesAfterPickedItems

        {- Is there a better way to indicate we've not missed a property from
           changesAfterPickedItems?
        -}
        pickupEntries : List EntryKind
        pickupEntries =
            logEntryAcc

        ( agentsAfterDroppingFood, includingDroppedFood ) =
            List.foldr
                (foldOverDroppedFood newTime)
                ( [], foodAcc )
                agentAcc

        updatedGrowables : List Growable
        updatedGrowables =
            List.foldr
                (foldOverAgentsAndGrowables newTime deltaT)
                model.growables
                agentsAfterDroppingFood
    in
    { model
        | time = newTime
        , agents = agentsAfterDroppingFood
        , foods = includingDroppedFood
        , fires = firesAfterCollisionWithRetardants
        , growables = updatedGrowables
        , extinguishers = extinguisherAcc
        , retardants = retardantsAfterCollisionWithFire
    }
        |> logAll deathEntries
        |> logAll movementEntries
        |> logAll pickupEntries


toDeathEntry : Agent -> EntryKind
toDeathEntry agent =
    AgentEntry { agentName = agent.name } Died agent.physics.position


createRetardantProjectiles : Posix -> Agent -> List Retardant -> List Retardant
createRetardantProjectiles currentTime agent acc =
    let
        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head
    in
    case topAction of
        Just action ->
            case action.outcome of
                ShootExtinguisher direction ->
                    { physics =
                        { position = agent.physics.position
                        , facing = direction
                        , velocity =
                            direction
                                |> Vector2d.withLength (Length.meters 100)
                                |> Vector2d.rotateBy (currentTime |> angleFuzz 0.8 |> Angle.radians)
                        , acceleration = Vector2d.zero
                        , radius = retardantRadius
                        }
                    , expiry = Time.posixToMillis currentTime + 1000 |> Time.millisToPosix
                    }
                        :: acc

                _ ->
                    acc

        Nothing ->
            acc


type alias PickedItems =
    { agentAcc : List Agent
    , foodAcc : List Food
    , extinguisherAcc : List FireExtinguisher
    , logEntryAcc : List EntryKind
    }


type alias PickedItemsHelper =
    { updatedAgent : Agent
    , updatedFoods : List Food
    , updatedExtinguishers : List FireExtinguisher
    , newEntries : List EntryKind
    }


foldOverPickedItems : Posix -> Agent -> PickedItems -> PickedItems
foldOverPickedItems currentTime agent { agentAcc, foodAcc, extinguisherAcc, logEntryAcc } =
    let
        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head

        { updatedFoods, updatedExtinguishers, updatedAgent, newEntries } =
            let
                noChange : PickedItemsHelper
                noChange =
                    { updatedAgent = agent
                    , updatedFoods = foodAcc
                    , updatedExtinguishers = extinguisherAcc
                    , newEntries = []
                    }
            in
            case topAction of
                Just action ->
                    case action.outcome of
                        DoNothing ->
                            noChange

                        MoveTo _ _ ->
                            noChange

                        MoveAwayFrom _ _ ->
                            noChange

                        ArrestMomentum ->
                            noChange

                        CallOut _ ->
                            noChange

                        Wander ->
                            noChange

                        PickUp (ExtinguisherID extinguisherID) ->
                            let
                                modified :
                                    ( Agent
                                    , List FireExtinguisher
                                    , List EntryKind
                                    )
                                modified =
                                    pickUpExtinguisher agent extinguisherID extinguisherAcc
                            in
                            { updatedAgent = Tuple3.first modified
                            , updatedFoods = foodAcc
                            , updatedExtinguishers = Tuple3.second modified
                            , newEntries = Tuple3.third modified
                            }

                        PickUp (EdibleID foodID) ->
                            let
                                modified : ( Agent, List Food )
                                modified =
                                    pickUpFood agent foodID foodAcc
                            in
                            { updatedAgent = Tuple.first modified
                            , updatedFoods = Tuple.second modified
                            , updatedExtinguishers = extinguisherAcc
                            , newEntries = []
                            }

                        EatHeldFood ->
                            noChange

                        DropHeldFood ->
                            noChange

                        DropHeldThing ->
                            noChange

                        BeggingForFood _ ->
                            noChange

                        ShootExtinguisher _ ->
                            noChange

                        PlantSeed _ ->
                            noChange

                Nothing ->
                    noChange
    in
    { agentAcc = updatedAgent :: agentAcc
    , foodAcc = updatedFoods
    , extinguisherAcc = updatedExtinguishers
    , logEntryAcc = List.append newEntries logEntryAcc
    }


foldOverDroppedFood : Posix -> Agent -> ( List Agent, List Food ) -> ( List Agent, List Food )
foldOverDroppedFood currentTime agent ( agentAcc, foodAcc ) =
    let
        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head

        ( updatedAgent, updatedFoods ) =
            case topAction of
                Just action ->
                    case action.outcome of
                        DropHeldFood ->
                            dropFood agent foodAcc

                        _ ->
                            ( agent, foodAcc )

                Nothing ->
                    ( agent, foodAcc )
    in
    ( updatedAgent :: agentAcc, updatedFoods )


foldOverAgentsAndGrowables : Posix -> Int -> Agent -> List Growable -> List Growable
foldOverAgentsAndGrowables currentTime deltaTMilliseconds agent growables =
    let
        topAction : Maybe Action
        topAction =
            getActions agent
                |> List.sortBy (computeUtility agent currentTime >> (*) -1)
                |> List.head

        withNaturalGrowth : List Growable
        withNaturalGrowth =
            growables
                |> List.map (growNaturally deltaTMilliseconds)

        updatedGrowables : List Growable
        updatedGrowables =
            case topAction of
                Just action ->
                    case action.outcome of
                        PlantSeed growableID ->
                            plantGrowable deltaTMilliseconds agent growableID withNaturalGrowth

                        _ ->
                            withNaturalGrowth

                Nothing ->
                    withNaturalGrowth
    in
    updatedGrowables


growNaturally : Int -> Growable -> Growable
growNaturally deltaTMilliseconds growable =
    case growable.state of
        FertileSoil _ ->
            growable

        GrowingPlant stats ->
            let
                growthAmount : Float
                growthAmount =
                    0.001 * toFloat deltaTMilliseconds

                newGrowth : Range
                newGrowth =
                    stats.growth |> mapRange ((+) growthAmount)
            in
            if (newGrowth |> normaliseRange) >= 1 then
                { growable | state = GrownPlant { hp = stats.hp } }

            else
                { growable | state = GrowingPlant { stats | growth = newGrowth } }

        GrownPlant _ ->
            growable

        DeadPlant state ->
            let
                decayAmount : Float
                decayAmount =
                    -0.0005 * toFloat deltaTMilliseconds

                newHP : Float
                newHP =
                    state.hp
                        |> hpRawValue
                        |> (\hp -> hp + decayAmount)

                newState : GrowableState
                newState =
                    if newHP <= 0 then
                        FertileSoil { plantedProgress = unseeded }

                    else
                        DeadPlant { state | hp = newHP |> setHitpoints state.hp }
            in
            { growable | state = newState }


pickUpFood : Agent -> Int -> List Food -> ( Agent, List Food )
pickUpFood agent foodID foods =
    let
        targetIsAvailable : Food -> Bool
        targetIsAvailable food =
            (food.id == foodID)
                && (food.physics.position
                        |> Point2d.distanceFrom agent.physics.position
                        |> Q.lessThan armsReach
                   )

        foodAvailable : Bool
        foodAvailable =
            foods |> List.any targetIsAvailable

        agentIsAvailable : Bool
        agentIsAvailable =
            case agent.holding of
                EmptyHanded ->
                    True

                BothHands _ ->
                    False

        pickup : Food -> Maybe Food
        pickup food =
            if (food |> targetIsAvailable) && agentIsAvailable then
                Nothing

            else
                Just food

        newFoods : List Food
        newFoods =
            List.filterMap pickup foods

        carry : Agent
        carry =
            if agentIsAvailable && foodAvailable then
                case foods |> List.filter targetIsAvailable |> List.head of
                    Just food ->
                        { agent | holding = BothHands (Edible food) }

                    Nothing ->
                        agent

            else
                agent
    in
    ( carry, newFoods )


plantGrowable : Int -> Agent -> Int -> List Growable -> List Growable
plantGrowable dT agent growableID growables =
    let
        targetIsAvailable : Growable -> Bool
        targetIsAvailable growable =
            (growable.id == growableID)
                && (agent.physics.position
                        |> Point2d.distanceFrom growable.physics.position
                        |> Q.lessThan armsReach
                   )

        tend : Growable -> Growable
        tend growable =
            if growable |> targetIsAvailable then
                { growable
                    | state =
                        case growable.state of
                            FertileSoil stats ->
                                let
                                    progressAmount : Float
                                    progressAmount =
                                        0.01 * toFloat dT

                                    newProgress : Range
                                    newProgress =
                                        stats.plantedProgress |> mapRange ((+) progressAmount)
                                in
                                if (newProgress |> normaliseRange) >= 1 then
                                    GrowingPlant
                                        { growth = Range { min = 0, max = 100, value = 0 }
                                        , hp = Hitpoints 50 50
                                        }

                                else
                                    FertileSoil { plantedProgress = newProgress }

                            GrowingPlant _ ->
                                growable.state

                            GrownPlant _ ->
                                growable.state

                            DeadPlant _ ->
                                growable.state
                }

            else
                growable
    in
    List.map tend growables


collideRetardantAndFire : Fire -> Maybe Retardant -> ( Maybe Fire, Maybe Retardant )
collideRetardantAndFire fire maybeRetardant =
    let
        noChange : ( Maybe Fire, Maybe Retardant )
        noChange =
            ( Just fire, maybeRetardant )
    in
    case maybeRetardant of
        Just retardant ->
            let
                collisionResult : Collision
                collisionResult =
                    collide retardant fire
            in
            if (collisionResult.penetration |> Length.inMeters) > 0 then
                let
                    updatedHP : Float
                    updatedHP =
                        (fire.hp |> hpRawValue) - 0.3

                    updatedFire : Maybe Fire
                    updatedFire =
                        if updatedHP < 0 then
                            Nothing

                        else
                            Just { fire | hp = updatedHP |> setHitpoints fire.hp }
                in
                ( updatedFire
                , Nothing
                )

            else
                noChange

        Nothing ->
            noChange


collideRetardantAndFires : Retardant -> List Fire -> ( List Fire, Maybe Retardant )
collideRetardantAndFires ret fires =
    mapAccumL collideRetardantAndFire (Just ret) fires
        |> justSomethings


collideRetardantsAndFires :
    Retardant
    -> ( List Retardant, List Fire )
    -> ( List Retardant, List Fire )
collideRetardantsAndFires retardant ( retardantAcc, fires ) =
    let
        ( updatedFires, updatedRetardant ) =
            collideRetardantAndFires retardant fires
    in
    case updatedRetardant of
        Just ret ->
            ( ret :: retardantAcc, updatedFires )

        Nothing ->
            ( retardantAcc, updatedFires )


pickUpExtinguisher :
    Agent
    -> Int
    -> List FireExtinguisher
    -> ( Agent, List FireExtinguisher, List EntryKind )
pickUpExtinguisher agent extinguisherID extinguishers =
    let
        targetIsAvailable : FireExtinguisher -> Bool
        targetIsAvailable extinguisher =
            extinguisher.id == extinguisherID

        targetAvailable : Bool
        targetAvailable =
            extinguishers |> List.any targetIsAvailable

        agentIsAvailable : Bool
        agentIsAvailable =
            case agent.holding of
                EmptyHanded ->
                    True

                BothHands _ ->
                    False

        pickup : FireExtinguisher -> Maybe FireExtinguisher
        pickup extinguisher =
            if (extinguisher |> targetIsAvailable) && agentIsAvailable then
                Nothing

            else
                Just extinguisher

        newTargets : List FireExtinguisher
        newTargets =
            List.filterMap pickup extinguishers

        carryAndEntry : ( Agent, List EntryKind )
        carryAndEntry =
            if agentIsAvailable && targetAvailable then
                case extinguishers |> List.head of
                    Just extinguisher ->
                        ( { agent | holding = BothHands (Extinguisher extinguisher) }
                        , [ AgentEntry { agentName = agent.name }
                                (PickedUp <| Extinguisher extinguisher)
                                extinguisher.physics.position
                          ]
                        )

                    Nothing ->
                        ( agent, [] )

            else
                ( agent, [] )
    in
    ( Tuple.first carryAndEntry, newTargets, Tuple.second carryAndEntry )


dropFood : Agent -> List Food -> ( Agent, List Food )
dropFood agent extantFoods =
    let
        droppedFoods : List Food
        droppedFoods =
            map (usePhysics agent.physics) <|
                case agent.holding of
                    EmptyHanded ->
                        []

                    BothHands (Edible x) ->
                        [ x ]

                    BothHands _ ->
                        []

        foodsGivenAway : Set Int
        foodsGivenAway =
            case droppedFoods of
                [ food ] ->
                    agent.foodsGivenAway |> insert food.id

                _ ->
                    -- this won't be correct if we can drop multiple foods
                    agent.foodsGivenAway

        sansFood : Holding
        sansFood =
            mapHeld unhandHeldFood agent.holding
    in
    ( { agent
        | holding = sansFood
        , foodsGivenAway = foodsGivenAway
      }
    , List.append extantFoods droppedFoods
    )


unhandHeldFood : Portable -> Maybe Portable
unhandHeldFood portable =
    case portable of
        Edible _ ->
            Nothing

        _ ->
            Just portable


usePhysics : PhysicalProperties -> Physical a -> Physical a
usePhysics newPhysics target =
    { target | physics = newPhysics }


eat : Agent -> ( Range, Holding )
eat agent =
    let
        someFood : Portable -> Bool
        someFood p =
            case p of
                Edible _ ->
                    True

                _ ->
                    False
    in
    if agent |> isHolding someFood then
        ( 0 |> updateRange agent.hunger
        , agent.holding |> mapHeld biteFood
        )

    else
        ( agent.hunger, agent.holding )


biteFood : Portable -> Maybe Portable
biteFood p =
    case p of
        Edible food ->
            let
                newJoules : Range
                newJoules =
                    food.joules
                        |> mapRange (\val -> val - 1000)
            in
            if normaliseRange newJoules <= 0 then
                Nothing

            else
                Just <| Edible { food | joules = newJoules }

        _ ->
            Just p


isHolding : (Portable -> Bool) -> Agent -> Bool
isHolding f agent =
    case agent.holding of
        EmptyHanded ->
            False

        BothHands p ->
            f p


mapHeld : (Portable -> Maybe Portable) -> Holding -> Holding
mapHeld f held =
    case held of
        EmptyHanded ->
            EmptyHanded

        BothHands p ->
            f p
                |> Maybe.map BothHands
                |> withDefault EmptyHanded


rotFood : Int -> Food -> Maybe Food
rotFood deltaT food =
    let
        newJoules : Float
        newJoules =
            (food.joules |> rangeCurrentValue) - (deltaT * 20000 |> toFloat)
    in
    if newJoules <= 0 then
        Nothing

    else
        Just { food | joules = newJoules |> updateRange food.joules }


outcomeToString : ActionOutcome -> String
outcomeToString outcome =
    case outcome of
        DoNothing ->
            "DoNothing"

        MoveTo desc _ ->
            "MoveTo(" ++ desc ++ ")"

        MoveAwayFrom desc _ ->
            "MoveAwayFrom(" ++ desc ++ ")"

        ArrestMomentum ->
            "ArrestMomentum"

        CallOut signal ->
            "CallOut(" ++ signalToString signal ++ ")"

        Wander ->
            "Wander"

        PickUp (ExtinguisherID id) ->
            "PickUpExtinguisher(id#" ++ String.fromInt id ++ ")"

        PickUp (EdibleID id) ->
            "PickUpFood(id#" ++ String.fromInt id ++ ")"

        EatHeldFood ->
            "EatHeldFood"

        DropHeldFood ->
            "DropHeldFood"

        DropHeldThing ->
            "DropHeldThing"

        BeggingForFood bool ->
            "BeggingForFood(" ++ boolString bool ++ ")"

        ShootExtinguisher direction ->
            "ShootExtinguisher(" ++ (direction |> Direction2d.toAngle |> Angle.inDegrees |> String.fromFloat) ++ ")"

        PlantSeed growableID ->
            "PlantSeed(" ++ (growableID |> String.fromInt) ++ ")"


signalToString : Signal -> String
signalToString signal =
    case signal of
        FeedMe ->
            "FeedMe"

        Bored ->
            "Bored"


decayRetardant : Posix -> Retardant -> Maybe Retardant
decayRetardant currentTime ret =
    if currentTime |> isAfter ret.expiry then
        Nothing

    else
        Just ret


isAfter : Posix -> Posix -> Bool
isAfter a b =
    Time.posixToMillis b > Time.posixToMillis a


goldenRatio : Float
goldenRatio =
    (1 + sqrt 5) / 2


hugeInt : Int
hugeInt =
    10 ^ 15


hugeFloat : Float
hugeFloat =
    10 ^ 15


hugeFloatGoldenRatio : Float
hugeFloatGoldenRatio =
    goldenRatio
        * hugeFloat


{-| Create an even pseudorandom angle distribution, without having to get Random involved.
-}
angleFuzz : Float -> Posix -> Float
angleFuzz spreadInRadians time =
    let
        factor : Float
        factor =
            (Time.posixToMillis time * hugeInt)
                |> modBy (floor hugeFloatGoldenRatio)
                |> toFloat
                |> (\x -> x / hugeFloatGoldenRatio - 0.5)
    in
    factor * spreadInRadians


justSomethings : ( List (Maybe a), b ) -> ( List a, b )
justSomethings =
    \( list, b ) -> ( list |> ME.values, b )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.paused then
        Sub.none

    else
        Sub.batch [ onAnimationFrame RAFTick ]


andCloseTheMenu : Model -> Model
andCloseTheMenu model =
    { model | menu = model.menu |> Zipper.root }

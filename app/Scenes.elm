module Scenes exposing (loadScene, sceneA, sceneB, sceneC, sceneD)

import DefaultData as DD
import Types exposing (EntryKind(..), Model, Scene)
import UtilityFunctions exposing (log)


loadScene : Scene -> Model -> Model
loadScene scene oldModel =
    { oldModel
        | agents = scene.agents
        , foods = scene.foods
        , fires = scene.fires
        , growables = scene.growables
        , extinguishers = scene.extinguishers
        , retardants = scene.retardants
    }
        |> log (SceneLoaded scene.name)


sceneA : Scene
sceneA =
    { agents = DD.humans
    , foods = DD.foods
    , fires = DD.fires
    , growables = DD.growables
    , extinguishers = DD.extinguishers
    , name = "The Gang Puts Out a Fire"
    , retardants = []
    }


sceneB : Scene
sceneB =
    { agents = DD.humans
    , foods = []
    , fires = []
    , growables = DD.growables
    , extinguishers = []
    , name = "Three Peeps and a Garden"
    , retardants = []
    }


sceneC : Scene
sceneC =
    { agents = DD.humans
    , foods = DD.foods
    , fires = []
    , growables = []
    , extinguishers = []
    , name = "Three Peeps and a Meal"
    , retardants = []
    }


sceneD : Scene
sceneD =
    { agents = DD.rabbits ++ DD.wolves
    , foods = []
    , fires = []
    , growables = DD.growables
    , extinguishers = []
    , name = "Wolves and Rabbits"
    , retardants = []
    }

module Scenes exposing (loadScene, sceneA, sceneB, sceneC)

import DefaultData as DD
import Types exposing (Model, Scene)


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


sceneA : Scene
sceneA =
    { agents = DD.agents
    , foods = DD.foods
    , fires = DD.fires
    , growables = DD.growables
    , extinguishers = DD.extinguishers
    , retardants = []
    }


sceneB : Scene
sceneB =
    { agents = DD.agents
    , foods = []
    , fires = []
    , growables = DD.growables
    , extinguishers = []
    , retardants = []
    }


sceneC : Scene
sceneC =
    { agents = DD.agents
    , foods = DD.foods
    , fires = []
    , growables = []
    , extinguishers = []
    , retardants = []
    }

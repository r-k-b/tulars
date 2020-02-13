module Scenes exposing (loadScene, sceneA, sceneB, sceneC, sceneD)

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
    { agents = DD.humans
    , foods = DD.foods
    , fires = DD.fires
    , growables = DD.growables
    , extinguishers = DD.extinguishers
    , retardants = []
    }


sceneB : Scene
sceneB =
    { agents = DD.humans
    , foods = []
    , fires = []
    , growables = DD.growables
    , extinguishers = []
    , retardants = []
    }


sceneC : Scene
sceneC =
    { agents = DD.humans
    , foods = DD.foods
    , fires = []
    , growables = []
    , extinguishers = []
    , retardants = []
    }


sceneD : Scene
sceneD =
    { agents = DD.rabbits ++ DD.wolves
    , foods = []
    , fires = []
    , growables = DD.growables
    , extinguishers = []
    , retardants = []
    }

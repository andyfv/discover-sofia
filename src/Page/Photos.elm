module Page.Photos exposing (Model, Msg, view, init, update)

import Html exposing (Html, div)
import Html.Attributes exposing (id)
--import Article exposing (Article, ArticleCard, Image)
--import Page exposing (viewCards)

--import Projects.NeighborhoodHere as NH exposing (..)
--import Projects.SymbolRecognition as SR exposing (..)
--import Projects.SailfishOS as SOS exposing (..)



-- MODEL


type alias Model =
    { isMapLoaded : Bool
    , isLandmarkSelected : Bool
    }


init : (Model, Cmd msg)
init =
    ( { isMapLoaded = False
      , isLandmarkSelected = False
      }
    , Cmd.none    
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> (Model, Cmd msg)
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)



-- VIEW


view : Model -> Html msg
view model  =
    div [ id "mapContainer" ] []
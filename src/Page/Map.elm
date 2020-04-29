port module Page.Map exposing (Model, Msg, view, init, update)

import Task
import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Decode exposing (Decoder, field, string)
--import Article exposing (Article, ArticleCard, Image)
--import Page exposing (viewCards)

port initializeMap : () -> Cmd msg

-- MODEL


type alias Model =
    { isMapLoaded : Bool
    , isLandmarkSelected : Bool
    , landmarks : List Landmark
    }


type alias Landmark =
    { id : Int
    , wikipage : String
    , wikiname : String
    }



init : (Model, Cmd msg)
init =
    ( { isMapLoaded = False
      , isLandmarkSelected = False
      , landmarks = []
      }
    , Cmd.batch 
        [ initializeMap ()
        , getLandmarks "//../assets/data.json"
        ]
    )




-- UPDATE


type Msg
    = NoOp
    | InitMap
    | MapInitialized
    | GotLandmarks (Result Http.Error (List Landmark))


update : Msg -> Model -> (Model, Cmd msg)
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)

        InitMap ->
            (model, initializeMap ())

        MapInitialized ->
            ({ model | isMapLoaded = True }, Cmd.none)

        GotLandmarks landmarks ->
            ({ model | landmarks = landmarks}, Cmd.none)



getLandmarks : String -> Cmd Msg
getLandmarks url =
    Http.get
        { url = url
        , expect = Http.expectJson GotLandmarks landmarkDecoder
        }


landmarkDecoder : Decoder (List Landmark)
landmarkDecoder =
    list 


-- VIEW


view : Model -> Html msg
view model  =
    div [ id "map-container" ] []
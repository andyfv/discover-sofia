port module Page.Map exposing (Model, Msg(..), view, init, update, subscriptions)

import Url.Builder as UrlBuilder exposing (crossOrigin, custom, QueryParameter)
import Task
import Http
import Html exposing (..)
import Html.Attributes exposing (id)
import Json.Decode as Decode exposing (Decoder, int, string, list)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, requiredAt, hardcoded)
--import Article exposing (Article, ArticleCard, Image)
--import Page exposing (viewCards)

port initializeMap : () -> Cmd msg
port mapInitialized : (() -> msg) -> Sub msg

port addMarker : (Encode.Value) -> Cmd msg
port showLandmarkSummary : (Int -> msg) -> Sub msg





-- MODEL


type alias Model =
    { isMapLoaded : Bool
    , isLandmarkSelected : Bool
    , landmarks : List Landmark
    }


type alias Landmark =
    { id : Int
    , wikiPage : String
    , wikiName : String
    }


type alias LandmarkSummary =
    { id : Int
    , title : String
    , thumbnail : String
    , extract : String
    , wikiUrl : String
    }



init : (Model, Cmd Msg)
init =
    (   { isMapLoaded = False
        , isLandmarkSelected = False
        , landmarks = []
        }
    , Cmd.batch 
        [ initializeMap ()
        , getLandmarksRequest "/../assets/data.json"
        --, Cmd.map (GetLandmarks "/../assets/data.json")
        ]
    )


-- SUBSCRIPTIONS

subscriptions : Sub Msg
subscriptions =
    Sub.batch 
        [ mapInitialized (\_ -> (MapInitialized))
        , showLandmarkSummary (\id -> OpenLandmarkSummary id)
        ]


-- UPDATE


type Msg
    = NoOp
    | InitMap
    | MapInitialized
    | GetLandmarks String
    | ReceivedLandmarks (Result Http.Error (List Landmark))
    | ReceivedLandmarkSummary (Result Http.Error (LandmarkSummary))
    --| ReceivedLandmarksWiki (Result Http.Error (List Landmark))


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)

        InitMap ->
            case model.isMapLoaded of
                True -> 
                    (model, Cmd.none)

                False ->
                    (model, initializeMap())

        MapInitialized ->
            ({ model | isMapLoaded = True }, Cmd.none)

        GetLandmarks url ->
            (model, getLandmarksRequest url)

        ReceivedLandmarks (Ok landmarks) ->
            let
                _ = Debug.log "landmarks" landmarks
            in
            ({ model | landmarks = landmarks }
            , Cmd.batch (List.map getLandmarkWiki landmarks)
            )

        ReceivedLandmarks (Err landmarks) ->
            (model, Cmd.none)

        ReceivedLandmarkSummary (Ok summary) ->
            let
                _ = Debug.log "summary" summary
            in
            (model, Cmd.none)

        ReceivedLandmarkSummary (Err summary) ->
            let 
                _ = Debug.log "summary err" summary
            in
            (model, Cmd.none)


--

{-
    Uncomment when deploying to Github/GitLab
    Wiki Link: https://en.wikipedia.org/api/rest_v1/page/summary/Stack_Overflow
-}
--wikiUrlBuilder : String -> String
--wikiUrlBuilder wikiName =
--    crossOrigin 
--        "https://en.wikipedia.org"
--        ["rest_v1", "page", "summary", wikiName]
--        []



{-
    Comment when deploying to Github/GitLab
    With cors-anywhere (npm install cors-anywhere)
    Link: url2 = "http://localhost:8080/https://en.wikipedia.org/api/rest_v1/page/summary/Stack_Overflow"
-}
wikiUrlBuilder : String -> String
wikiUrlBuilder wikiName =
    crossOrigin 
        "http://localhost:8080"
        ["https://en.wikipedia.org/api/rest_v1/page/summary", wikiName]
        []



getLandmarkWiki : Landmark -> Cmd Msg
getLandmarkWiki landmark =
    Http.get
        { url = wikiUrlBuilder landmark.wikiName
        , expect = Http.expectJson ReceivedLandmarkSummary (summaryDecoder landmark.id)
        }


summaryDecoder : Int -> Decoder LandmarkSummary
summaryDecoder id =
    Decode.succeed LandmarkSummary
        |> hardcoded id
        |> required "title" string
        |> requiredAt [ "thumbnail", "source" ] string
        |> required "extract" string
        |> requiredAt [ "content_urls", "desktop", "page" ] string


--


getLandmarksRequest : String -> Cmd Msg
getLandmarksRequest url =
    Http.get
        { url = url
        , expect = Http.expectJson ReceivedLandmarks landmarkListDecoder
        }


landmarkListDecoder : Decoder (List Landmark)
landmarkListDecoder =
    Decode.list landmarkDecoder
        |> Decode.field "landmarks"


landmarkDecoder : Decoder Landmark
landmarkDecoder =
    Decode.succeed Landmark
        |> required "id" int
        |> required "wikipage" string
        |> required "wikiname" string
    



-- VIEW


view : Model -> Html msg
view model  =
    div [ id "map-container" ] []
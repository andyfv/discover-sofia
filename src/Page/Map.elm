port module Page.Map exposing (Model, Msg(..), view, init, update, subscriptions)

import Url.Builder as UrlBuilder exposing (crossOrigin, custom, QueryParameter)
import Dict exposing (Dict)
import Task
import Http
import Html exposing (..)
import Html.Attributes exposing (id)
import Json.Decode as Decode exposing (Decoder, int, string, list, float)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, requiredAt, hardcoded)
import Json.Encode as Encode 
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
    , selectedLandmarkSummary : Maybe Int
    , landmarksList : List Landmark
    , landmarkSummaryList : Dict Int LandmarkSummary
    }


type alias Landmark =
    { id : Int
    , wikiPage : String
    , wikiName : String
    }


type alias LandmarkSummary =
    { id : Int
    , title : String
    , extract : String
    , thumbnail : String
    , originalImage : String
    , wikiUrl : String
    , coordinates : Coordinates
    }


type alias Coordinates =
    { lat : Float
    , lon : Float
    }


init : (Model, Cmd Msg)
init =
    (   { isMapLoaded = False
        , isLandmarkSelected = False
        , landmarksList = []
        , selectedLandmarkSummary = Nothing
        , landmarkSummaryList = Dict.empty        
        }
    , Cmd.batch [ initializeMap () ]
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
    --| GetLandmarks String
    | OpenLandmarkSummary Int
    | ReceivedLandmarks (Result Http.Error (List Landmark))
    | ReceivedLandmarkSummary (Result Http.Error (LandmarkSummary))


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    let
        _ = Debug.log "message" msg 
    in
    case msg of
        NoOp ->
            (model, Cmd.none)

        InitMap ->
            case model.isMapLoaded of
                True -> 
                    (model, Cmd.none)

                False ->
                    (model, initializeMap ())

        OpenLandmarkSummary id ->
            ( { model | isLandmarkSelected = True
              , selectedLandmarkSummary = Just id
              } , Cmd.none)

        MapInitialized ->
            ({ model | isMapLoaded = True }, getLandmarksRequest "/../assets/data.json")

        --GetLandmarks url ->
        --    (model, getLandmarksRequest url)

        ReceivedLandmarks (Ok landmarksList) ->
            let
                _ = Debug.log "landmarks" landmarksList
            in
            ({ model | landmarksList = landmarksList }
            , Cmd.batch (List.map getLandmarkWiki landmarksList)
            )

        ReceivedLandmarks (Err landmarksList) ->
            (model, Cmd.none)

        ReceivedLandmarkSummary (Ok summary) ->
            let
                _ = Debug.log "summary" summary
            in
            ( { model | landmarkSummaryList = Dict.insert summary.id summary model.landmarkSummaryList }
            , addMarker (encodeMarkerInfo summary))

        ReceivedLandmarkSummary (Err summary) ->
            let 
                _ = Debug.log "summary err" summary
            in
            (model, Cmd.none)


encodeMarkerInfo : LandmarkSummary -> Encode.Value
encodeMarkerInfo summary =
    let 
        encodedCoord = 
            Encode.object
                [ ("lat", Encode.float summary.coordinates.lat)
                , ("lon", Encode.float summary.coordinates.lon)
                ]
    in
    Encode.object
        [ ( "id", Encode.int summary.id )
        , ( "title", Encode.string summary.title)
        , ( "thumbnail", Encode.string summary.thumbnail )
        , ( "coords", encodedCoord ) 
        ]


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
        |> required "extract" string
        |> optionalAt [ "thumbnail", "source" ] string ""
        |> optionalAt [ "originalimage", "source" ] string ""
        |> requiredAt [ "content_urls", "desktop", "page" ] string
        |> required "coordinates" coordinatesDecoder 


coordinatesDecoder : Decoder Coordinates
coordinatesDecoder =
    Decode.succeed Coordinates
        |> required "lat" float
        |> required "lon" float

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
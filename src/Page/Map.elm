port module Page.Map exposing (Model, Msg(..), view, init, update, subscriptions)

import Url.Builder as UrlBuilder exposing (crossOrigin, custom, QueryParameter)
import Dict exposing (Dict)
import Task
import Http
import Html exposing (..)
import Html.Attributes exposing (id, class, alt, src, href)
import Html.Events exposing (on, onClick)
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
    | OpenLandmarkSummary Int
    | CloseLandmarkSummary
    | ReceivedLandmarks (Result Http.Error (List Landmark))
    | ReceivedLandmarkSummary (Result Http.Error (LandmarkSummary))


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
                    (model, initializeMap ())

        OpenLandmarkSummary id ->
            ( { model | isLandmarkSelected = True
              , selectedLandmarkSummary = Just id
              } , Cmd.none
            )

        CloseLandmarkSummary ->
            ( { model | isLandmarkSelected = False
              , selectedLandmarkSummary = Nothing
              } , Cmd.none
            )

        MapInitialized ->
            ( { model | isMapLoaded = True }
            , getLandmarksRequest "/../assets/data.json"
            )


        ReceivedLandmarks (Ok landmarksList) ->
            ( { model | landmarksList = landmarksList }
            , Cmd.batch (List.map getLandmarkWiki landmarksList)
            )

        ReceivedLandmarks (Err landmarksList) ->
            (model, Cmd.none)

        ReceivedLandmarkSummary (Ok summary) ->
            (   { model |
                    landmarkSummaryList = 
                        Dict.insert 
                        summary.id 
                        summary 
                        model.landmarkSummaryList 
                }
            , addMarker (encodeMarkerInfo summary)
            )

        ReceivedLandmarkSummary (Err summary) ->
            (model, Cmd.none)



-- HELPERES


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


view : Model -> Html Msg
view model  =
    div [ id "map-container" ] 
        [ viewSummary model ]
        

viewSummary : Model -> Html Msg
viewSummary model =
    case model.isLandmarkSelected of 
        False ->
            text ""

        True ->
            let 
                landmark = getSelectedLandmark model
            in
            case landmark of 
                Just landmarkSummary ->
                    div [ id "summary-container" ]
                        [ viewInfoControls
                        , div [ id "summary"]
                            [ viewTitle landmarkSummary.title
                            , viewImage landmarkSummary
                            , viewText landmarkSummary.extract
                            , viewWikiLink landmarkSummary.wikiUrl
                            ]
                        ]

                Nothing ->
                    div [ id "summary-container" ] [ text "No info" ]


getSelectedLandmark : Model -> Maybe LandmarkSummary
getSelectedLandmark model =
    case model.selectedLandmarkSummary of 
        Just id ->
            Dict.get id model.landmarkSummaryList

        Nothing -> 
            Nothing


viewInfoControls : Html Msg
viewInfoControls =
    div [ id "info-controls-container" ] 
        [ button [ class "info-control", class "directions"
        --, onClick ShowDirectionsOptions 
        ] [ text "Directions" ]
        , button [ class "info-control", class "close", onClick CloseLandmarkSummary ] [ text "Close" ]
        ]


viewTitle : String -> Html msg
viewTitle title =
    h3 [ id "summary-title" ] [ text title ]


viewImage : LandmarkSummary -> Html Msg
viewImage landmark =
    let
        image = if (landmark.originalImage == "") then
                    p [] [ text "No Image" ]
                else
                    img 
                        [ id "summary-image"
                        , alt landmark.title
                        , src landmark.thumbnail 
                        ]
                        []       
    in
    div [ id "summary-image" ]
        [ image ]


viewText : String -> Html msg
viewText summaryText =
    div [ id "summary-text" ]
        [ text summaryText ] 


viewWikiLink : String -> Html msg
viewWikiLink url =
    a [ id "summary-wiki" ,href url  ] [ text "Open Wiki Page" ]
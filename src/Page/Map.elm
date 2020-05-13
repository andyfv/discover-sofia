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
-- Map ports
port mapLoad : () -> Cmd msg
port mapLoaded : (() -> msg) -> Sub msg
port mapLoadingFailed : (String -> msg) -> Sub msg

-- Search
port mapSearch : String -> Cmd msg
port mapSearchResponse : (Value -> msg) -> Sub msg
port mapSearchFailed : (String -> msg) -> Sub msg
-- Directions ports
port geoserviceLocationGet : () -> Cmd msg
port geoserviceLocationReceive : (Value -> msg) -> Sub msg
port geoserviceLocationError : (String -> msg) -> Sub msg

port addMarker : (Encode.Value) -> Cmd msg
port showLandmarkSummary : (Int -> msg) -> Sub msg


        [ mapLoaded (\_ -> MapLoadedOk)
        , mapLoadingFailed (\err -> MapLoadedErr err)
        , mapSearchResponse (decodeValue itemListDecoder >> MapSearchResponse)
        , mapSearchFailed (\err -> MapSearchError err)
        -- Geoservices
        , geoserviceLocationReceive (decodeValue positionDecoder >> GeoserviceLocationReceive)
        , geoserviceLocationError (\message -> GeoserviceLocationError message)
        ]



-- MODEL


      , startPoint = StartPointInvalid ""
      , endPoint = EndPointInvalid ""
      , addressResults = AddressResultsEmpty
      , redactedRoutePoint = StartPoint
      }
    , Cmd.batch [ mapLoad () ]
    )

type alias Model =
    { isMapLoaded : Bool
    , isLandmarkSelected : Bool
    , startPoint : RoutePoint
    , endPoint : RoutePoint
    , landmarksList : List Landmark
    , landmarkSummaryList : Dict Int LandmarkSummary
    , addressResults : AddressResults
    , redactedRoutePoint : RedactedPoint
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


type MapStatus
    = MapLoaded
    | MapLoading
    | MapNotLoaded String
        , selectedLandmarkSummary = Nothing
        , landmarkSummaryList = Dict.empty
        }
    , Cmd.batch [ initializeMap () ]
    )


type AddressResults
    = AddressResultsEmpty
    | AddressResultsLoading
    | AddressResultsLoaded (List Item)
    | AddressResultsErr String

type RedactedPoint
    = StartPoint
    | EndPoint


type RoutePoint
    = StartPointValid String Position
    | StartPointInvalid String
    | EndPointValid String Position
    | EndPointInvalid String

subscriptions : Sub Msg
subscriptions =
    Sub.batch 
        [ mapInitialized (\_ -> (MapInitialized))
        , showLandmarkSummary (\id -> OpenLandmarkSummary id)
        ]


-- UPDATE


type Msg
    = NoOp
      -- MapStatus
    | MapLoadedOk
    | MapLoadedErr String
    | CloseLandmarkSummary
    | MapSearchResponse (Result Json.Decode.Error (List Item))
    | MapSearchResponseClear
    | MapSearchError String

update : Msg -> Model -> (Model, Cmd Msg)
    | GeoserviceLocationReceive (Result Json.Decode.Error Position)
    | GeoserviceLocationError String
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)

        MapLoadedOk ->
            ( { model | mapStatus = MapLoaded }
            , getLandmarksRequest "/../assets/data.json"
            )

        MapLoadedErr err ->
            ( { model | mapStatus = MapNotLoaded err }, Cmd.none )

                False ->
                    (model, initializeMap ())

        MapSearchResponse (Ok items) ->
            ( { model | addressResults = AddressResultsLoaded items }, Cmd.none )

        MapSearchResponse (Err items) ->
            let 
                _ = Debug.log "items" items
            in
            ( { model | addressResults = AddressResultsErr "Response body is incorrect" }, Cmd.none )

        MapSearchResponseClear ->
            ( { model | addressResults = AddressResultsEmpty }, Cmd.none )

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

        InfoUpdateMapRoute routePoint ->
            case routePoint of
                StartPointValid address position ->
                    ({ model | startPoint = routePoint }, Cmd.none)

                StartPointInvalid address ->
                    ({ model | startPoint = routePoint }, mapSearchHelper address model)

                EndPointValid _ _ ->
                    ({ model | endPoint = routePoint }, Cmd.none)

                EndPointInvalid address ->
                    ({ model | endPoint = routePoint }, mapSearchHelper address model)

        InfoUpdateRouteFocus redactedPoint ->
            ( { model | redactedRoutePoint = redactedPoint}, Cmd.none )
        -- Directions
        GeoserviceLocationReceive (Ok currentPosition) ->
            ( { model | startPoint = StartPointValid "Current Position" currentPosition }
            , Cmd.none
            )

        GeoserviceLocationReceive (Err invalidPosition) ->
            ( { model | startPoint = StartPointInvalid "Invalid Position" }
            , Cmd.none
            )

        GeoserviceLocationError err ->
            ( { model | startPoint = StartPointInvalid "" }
            , Cmd.none
            )
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


mapSearchHelper : String -> Model -> Cmd Msg
mapSearchHelper address model =
    if String.isEmpty address then
        let 
            (_, cmds) = update MapSearchResponseClear model
        in
        cmds
    else 
        mapSearch address


-- HTTP REQUESTS


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
    

view : Model -> Html Msg
view model =
    div [ id "map-page" ]
        [ viewMode model ]


viewMode : Model -> Html Msg
viewMode model =
    case model.mapStatus of
        MapLoading ->
            text "Loading"

        MapNotLoaded err ->
            text err

        MapLoaded ->
            case model.infoMode of
                Closed ->
                    text ""

                ViewDirections ->
                    viewDirection model

                ViewSummary ->
                    viewSummary model.landmarkSummary

                ViewRoute ->
                    viewRoute model


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
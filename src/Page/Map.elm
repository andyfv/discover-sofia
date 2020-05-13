port module Page.Map exposing (Model, Msg(..), init, subscriptions, update, view)

import Http
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, onMouseEnter, onMouseLeave, onFocus)
import Json.Decode exposing (Error, Value, decodeValue)
import Url.Builder as UrlBuilder exposing (crossOrigin)

import Address
    exposing
        ( Item
        , Position
        , itemListDecoder
        , positionDecoder
        , positionEncoder
        , positionToString
        , routeParamEncoder
        )

import Landmark
    exposing
        ( Landmark
        , Summary
        , SummaryType(..)
        , landmarkListDecoder
        , markerInfoEncoder
        , summaryDecoder
        )



-- Map ports
port mapLoad : () -> Cmd msg
port mapLoaded : (() -> msg) -> Sub msg
port mapLoadingFailed : (String -> msg) -> Sub msg

-- Search
port mapSearch : String -> Cmd msg
port mapSearchResponse : (Value -> msg) -> Sub msg
port mapSearchFailed : (String -> msg) -> Sub msg

port mapRoutesCalculate : Value -> Cmd msg
--port mapRoutesResponse : (Value -> msg) -> Sub msg


-- Markers
port mapMarkerAddCustom : Value -> Cmd msg
port mapMarkerOpenSummary : (Int -> msg) -> Sub msg

-- Directions ports
port geoserviceLocationGet : () -> Cmd msg
port geoserviceLocationReceive : (Value -> msg) -> Sub msg
port geoserviceLocationError : (String -> msg) -> Sub msg



-- SUBSCRIPTIONS


subscriptions : Sub Msg
subscriptions =
    Sub.batch
        [ mapLoaded (\_ -> MapLoadedOk)
        , mapLoadingFailed (\err -> MapLoadedErr err)
        , mapMarkerOpenSummary (\id -> InfoOpen id)
        , mapSearchResponse (decodeValue itemListDecoder >> MapSearchResponse)
        , mapSearchFailed (\err -> MapSearchError err)
        --, mapRoutesResponse ()

        -- Geoservices
        , geoserviceLocationReceive (decodeValue positionDecoder >> GeoserviceLocationReceive)
        , geoserviceLocationError (\message -> GeoserviceLocationError message)
        ]



-- MODEL


init : ( Model, Cmd Msg )
init =
    ( { infoMode = Closed 
      , mapStatus = MapNotLoaded ""
      , startPoint = StartPointInvalid ""
      , endPoint = EndPointInvalid ""
      , mapRoutes = RoutesUnavailable
      , transport = Car
      , landmarksList = []
      , landmarkSummaryList = Dict.empty
      , landmarkSummary = SummaryInvalid
      , addressResults = AddressResultsEmpty
      , redactedRoutePoint = StartPoint
      }
    , Cmd.batch [ mapLoad () ]
    )


type alias Model =
    { infoMode : InfoMode
    , mapStatus : MapStatus
    , startPoint : RoutePoint
    , endPoint : RoutePoint
    , mapRoutes : MapRoutes
    , transport : Transport
    , landmarksList : List Landmark
    , landmarkSummary : SummaryType
    , landmarkSummaryList : Dict Int Summary
    , addressResults : AddressResults
    , redactedRoutePoint : RedactedPoint
    }


type MapRoutes
    = RoutesUnavailable
    | RoutesCalculating
    | RoutesResponse


type Transport
    = Car
    | Walk


type InfoMode
    = Closed
    | ViewSummary
    | ViewDirections
    | ViewRoute


type MapStatus
    = MapLoaded
    | MapLoading
    | MapNotLoaded String


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



-- UPDATE


type Msg
    = NoOp
      -- MapStatus
    | MapLoadedOk
    | MapLoadedErr String
    | MapMarkerAddDefault Position
    | MapSearchResponse (Result Json.Decode.Error (List Item))
    | MapSearchResponseClear
    | MapSearchError String
      -- Info Element
    | InfoOpen Int
    | InfoOpenDirections String Position
    | InfoOpenRoute
    | InfoUpdateMapRoute RoutePoint 
    | InfoUpdateRouteFocus RedactedPoint
    | InfoClose
      -- DirectionsView
    | GeoserviceLocationReceive (Result Json.Decode.Error Position)
    | GeoserviceLocationError String
      -- Load data.json
    | LoadLandmarksList (Result Http.Error (List Landmark))
      -- Received Wikipedia summary pages
    | LoadLandmarskWiki (Result Http.Error Summary)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        MapLoadedOk ->
            ( { model | mapStatus = MapLoaded }
            , getLandmarksRequest "/../assets/data.json"
            )

        MapLoadedErr err ->
            ( { model | mapStatus = MapNotLoaded err }, Cmd.none )

        MapMarkerAddDefault position ->
            ( model, Cmd.none )

        MapSearchResponse (Ok items) ->
            ( { model | addressResults = AddressResultsLoaded items }, Cmd.none )

        MapSearchResponse (Err items) ->
            let 
                _ = Debug.log "items" items
            in
            ( { model | addressResults = AddressResultsErr "Response body is incorrect" }, Cmd.none )

        MapSearchResponseClear ->
            ( { model | addressResults = AddressResultsEmpty }, Cmd.none )

        MapSearchError err ->
            let
                _ = Debug.log "err" err
            in
            ( { model | addressResults = AddressResultsErr err }, Cmd.none )

        -- InfoView
        InfoOpen id ->
            case Dict.get id model.landmarkSummaryList of
                Just landmarkSummary ->
                    ( { model | infoMode = ViewSummary
                      , landmarkSummary = SummaryValid landmarkSummary
                      , addressResults = AddressResultsEmpty
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        InfoClose ->
            ( { model | infoMode = Closed
              , landmarkSummary = SummaryInvalid 
              , addressResults = AddressResultsEmpty
              }
            , Cmd.none
            )

        InfoOpenDirections address position ->
            ( { model
                | infoMode = ViewDirections
                , endPoint = EndPointValid address position
              }
            , geoserviceLocationGet ()
            )

        InfoOpenRoute ->
            ( { model | infoMode = ViewRoute, mapRoutes = RoutesCalculating }
            , mapRoutesHelper model
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

        -- Received data.json
        LoadLandmarksList (Ok landmarksList) ->
            ( { model | landmarksList = landmarksList }
            , Cmd.batch (List.map getLandmarkWiki landmarksList)
            )

        LoadLandmarksList (Err landmarksList) ->
            ( model, Cmd.none )

        -- Received Wikipedia summary pages
        LoadLandmarskWiki (Ok summary) ->
            ( { model
                | landmarkSummaryList =
                    model.landmarkSummaryList
                        |> Dict.insert summary.id summary
              }
            , mapMarkerAddCustom (markerInfoEncoder summary)
            )

        LoadLandmarskWiki (Err summary) ->
            ( model, Cmd.none )


mapRoutesHelper : Model -> Cmd Msg
mapRoutesHelper { startPoint, endPoint, transport }  =
    case (startPoint, endPoint ) of 
        (StartPointValid _ origin, EndPointValid _ destination ) ->
            let 
                transportMode = transportModeHelper transport
                params = routeParamEncoder origin destination transportMode
            in
            mapRoutesCalculate params

        _ ->
            Cmd.none


transportModeHelper : Transport -> String
transportModeHelper transport =
    case transport of 
        Car ->
            "car"

        Walk ->
            "pedestrian"



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
--        [ "api" ,"rest_v1", "page", "summary", wikiName]
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
        [ "https://en.wikipedia.org/api/rest_v1/page/summary", wikiName ]
        []


getLandmarkWiki : Landmark -> Cmd Msg
getLandmarkWiki landmark =
    Http.get
        { url = wikiUrlBuilder landmark.wikiName
        , expect = Http.expectJson LoadLandmarskWiki (summaryDecoder landmark.id)
        }


getLandmarksRequest : String -> Cmd Msg
getLandmarksRequest url =
    Http.get
        { url = url
        , expect = Http.expectJson LoadLandmarksList landmarkListDecoder
        }



-- VIEW


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
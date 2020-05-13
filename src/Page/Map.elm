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



-- ROUTE


viewRoute : Model -> Html Msg
viewRoute model =
    div [ class "info-container" ] 
        [ viewRouteViewControls
        , viewTransportControls model.transport
        , viewRouteResults model.mapRoutes
        ]


viewRouteViewControls : Html Msg
viewRouteViewControls =
    div [ class "info-controls-container"]
        [ button 
            [ classList 
                [ ( "info-control", True )
                , ( "close", True )
                ]
            ]
            [ text "Cancel" ]
        , button
            [ classList
                [ ( "info-control", True )
                , ( "start-navigation", True )
                , ( "button-disabled", True )
                ]
            , disabled True
            ]
            [ text "Go" ]
        ]


viewTransportControls : Transport -> Html Msg
viewTransportControls transport =
    let 
        isCarChosen = 
            case transport of
                Car ->
                    True

                Walk ->
                    False
    in
    div [ class "info-controls-container"]
        [ button 
            [ classList 
                [ ( "info-control", True )
                , ( "transport", True )
                , ( "selected-transport", not isCarChosen )
                ]
            ]
            [ text "Car" ]
        , button
            [ classList
                [ ( "info-control", True )
                , ( "transport", True )
                , ( "selected-transport", isCarChosen )
                ]
            ]
            [ text "Walk" ]
        ]

viewRouteResults : MapRoutes -> Html Msg
viewRouteResults mapRoute =
    case mapRoute of 
        RoutesUnavailable ->
            p [ style "text-align" "center" ] [ text "No Routes available" ]

        RoutesCalculating ->
            p [ style "text-align" "center" ] [ text "Calculating Routes..." ]

        RoutesResponse ->
            ul [ id "routes-results" ] []
                --(List.map (viewRouteSuggestion "" )

viewRouteSuggestion : Html Msg
viewRouteSuggestion =
    div [] []





-- DIRECTIONS


viewDirection : Model -> Html Msg
viewDirection { startPoint, endPoint, redactedRoutePoint, addressResults } =
    div [ class "info-container" ]
        [ viewDirectionsControls (startPoint, endPoint)
        , viewAddressInputs (startPoint, endPoint)
        , viewAddressResults addressResults redactedRoutePoint
        ]


viewDirectionsControls : ( RoutePoint, RoutePoint ) -> Html Msg
viewDirectionsControls ( startPoint, endPoint ) =
    case ( startPoint, endPoint ) of
        ( StartPointValid _ _, EndPointValid _ _ ) ->
            infoControlsContainer False

        ( _, _ ) ->
            infoControlsContainer True


infoControlsContainer : Bool -> Html Msg
infoControlsContainer routeAccess =
    div [ class "info-controls-container" ]
        [ button
            [ classList
                [ ( "info-control", True )
                , ( "close", True )
                ]
            , onClick InfoClose
            ]
            [ text "Cancel" ]
        , button
            [ classList
                [ ( "info-control", True )
                , ( "directions", True )
                , ( "button-disabled", routeAccess )
                ]
            , disabled routeAccess
            , onClick InfoOpenRoute
            ]
            [ text "Route" ]
        ]


viewAddressInputs : (RoutePoint, RoutePoint) -> Html Msg
viewAddressInputs ( startPoint, endPoint ) =
    div [ id "address-inputs" ]
        [ inputWrapperFrom startPoint
        , inputWrapperTo endPoint
        ]


inputWrapperFrom : RoutePoint -> Html Msg
inputWrapperFrom startPoint =
    let
        isValidAdrress = 
            case startPoint of
                StartPointValid _ _ ->
                    True

                _ ->
                    False
    in
    Html.form [ class "directions-input" ]
        [ label 
            [ classList
                [ ( "valid-address", isValidAdrress) 
                , ( "invalid-address", not isValidAdrress)
                ]
            ] 
            [ text "From" ]
        , input
            [ onInput (\text -> InfoUpdateMapRoute (StartPointInvalid text))
            , onFocus (InfoUpdateRouteFocus StartPoint)
            , autofocus True
            , placeholder "Search"
            , value (pointToString startPoint)
            , type_ "search"
            ]
            []
        ]


inputWrapperTo : RoutePoint -> Html Msg
inputWrapperTo endPoint =
    let
        isValidAdrress = 
            case endPoint of
                EndPointValid _ _ ->
                    True

                _ ->
                    False
    in
    Html.form [ class "directions-input" ]
        [ label 
            [ classList
                [ ( "valid-address", isValidAdrress) 
                , ( "invalid-address", not isValidAdrress)
                ]
            ] 
            [ text "To" ]
        , input
            [ onInput (\text -> InfoUpdateMapRoute (EndPointInvalid text))
            , onFocus (InfoUpdateRouteFocus EndPoint)
            , placeholder "Search"
            , value (pointToString endPoint)
            , type_ "search"
            ]
            []
        ]


viewAddressResults : AddressResults -> RedactedPoint -> Html Msg
viewAddressResults results redactedPoint =
    case results of
        AddressResultsLoaded items ->
            ul [ id "address-results" ]
                (List.map (viewAddressSuggestion redactedPoint) items )

        AddressResultsEmpty ->
            p [ style "text-align" "center" ] [ text "No results" ]

        AddressResultsLoading ->
            p [ style "text-align" "center" ] [ text "Loading..." ]

        AddressResultsErr err ->
            p [ style "text-align" "center" ] [ text "Fetching suggestions has failed" ]


viewAddressSuggestion : RedactedPoint -> Item -> Html Msg
viewAddressSuggestion redactedPoint item =
    let 
        _ = Debug.log "item" item
        point =
            case redactedPoint of
                StartPoint ->
                    StartPointValid item.address.label item.position

                EndPoint -> 
                    EndPointValid item.address.label item.position
    in
    li
        [ class "address-suggestion"
        , attribute "data-lan" (String.fromFloat item.position.lat)
        , attribute "data-lng" (String.fromFloat item.position.lng)
        , attribute "data-title" item.address.label
        , onClick (InfoUpdateMapRoute point)
        --, onMouseEnter (MapMarkerAddDefault item.position)
        ]
        [ p [ class "address-name" ] [ text item.address.label ]
        , p [ class "address-details" ] 
            [ text 
                ( item.address.county 
                    ++ " | "
                    ++ item.address.district
                    ++ " | "  
                    ++ item.address.countryName) ]
        ]



-- Summary


viewSummary : SummaryType -> Html Msg
viewSummary summaryType =
    case summaryType of
        SummaryValid summary ->
            div [ class "info-container" ]
                [ viewInfoControls summary
                , div [ id "summary" ]
                    [ viewTitle summary.title
                    , viewImage summary
                    , viewText summary.extract
                    , viewWikiLink summary.wikiUrl
                    ]
                ]

        SummaryInvalid ->
            div [ id "summary-container" ] [ text "No info" ]


viewInfoControls : Summary -> Html Msg
viewInfoControls landmark =
    div [ class "info-controls-container" ]
        [ button [ class "info-control", class "close", onClick InfoClose ] [ text "Close" ]
        , button
            [ class "info-control"
            , class "directions"
            , onClick (InfoOpenDirections landmark.title landmark.coordinates)
            ]
            [ text "Directions" ]
        ]


viewTitle : String -> Html msg
viewTitle title =
    h3 [ id "summary-title" ] [ text title ]


viewImage : Summary -> Html Msg
viewImage landmark =
    let
        image =
            if landmark.originalImage == "" then
                p [] [ text "No Image" ]

            else
                img
                    [ id "summary-image"
                    , alt landmark.title
                    , src landmark.thumbnail
                    ]
                    []
    in
    div [ id "summary-image" ] [ image ]


viewText : String -> Html msg
viewText summaryText =
    div [ id "summary-text" ] [ text summaryText ]


viewWikiLink : String -> Html msg
viewWikiLink url =
    a [ id "summary-wiki", href url ] [ text "Open Wiki Page" ]



-- HELPERS


pointToString : RoutePoint -> String
pointToString point =
    case point of
        StartPointInvalid title ->
            title

        StartPointValid title position ->
            title ++ ", " ++ positionToString position

        EndPointInvalid title ->
            title

        EndPointValid title position ->
            title ++ ", " ++ positionToString position
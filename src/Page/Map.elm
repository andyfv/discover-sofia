port module Page.Map exposing (Model, Msg(..), init, subscriptions, update, view)

import Http
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode exposing (Error, Value, decodeValue)
import Json.Decode.Pipeline as DecodePipe
import Url.Builder as UrlBuilder exposing (crossOrigin)

--import Page.MapView.RouteView

import MapHelper as MH exposing (Position, RouteSummary, MapRoutes)



-- Map ports
port mapLoad : () -> Cmd msg
port mapLoadingStatus : (String -> msg) -> Sub msg

-- Markers
port mapMarkerAddCustom : Value -> Cmd msg
port mapMarkerShowAll : () -> Cmd msg
port mapMarkerOpenSummary : (Int -> msg) -> Sub msg

-- Search
port mapSearch : String -> Cmd msg
port mapSearchResponse : (Value -> msg) -> Sub msg

port mapRoutesCalculate : Value -> Cmd msg
port mapRoutesResponse : (Value -> msg) -> Sub msg
port mapRoutesShowSelected : Value -> Cmd msg


-- Directions ports
port geoserviceLocationCall : () -> Cmd msg
port geoserviceLocationReceive : (Value -> msg) -> Sub msg



-- SUBSCRIPTIONS


subscriptions : Sub Msg
subscriptions =
    Sub.batch
        [ mapLoadingStatus (\mapStatus -> MapStatusMsg mapStatus)
        , mapMarkerOpenSummary (\id -> InfoOpen (Just id))
        , mapSearchResponse (decodeValue MH.itemListDecoder >> MapSearchResponse)
        , mapRoutesResponse (decodeValue MH.routeSummaryListDecoder >> MapRoutesResponse)

        -- Geoservices
        , geoserviceLocationReceive (decodeValue MH.positionDecoder >> GeoserviceLocationReceive)
        ]



-- MODEL


init : ( Model, Cmd Msg )
init =
    ( { infoMode = Closed 
      , mapStatus = MH.MapLoading
      , startPoint = MH.StartPointInvalid ""
      , endPoint = MH.EndPointInvalid ""
      , mapRoutes = MH.RoutesUnavailable
      , selectedRoute = Nothing
      , transport = MH.Car
      , landmarksList = []
      , landmarkSummaryList = Dict.empty
      , landmarkSummary = MH.SummaryInvalid
      , addressResults = MH.AddressResultsEmpty
      , redactedRoutePoint = MH.StartPoint
      }
    , Cmd.batch [ mapLoad () ]
    )


type alias Model =
    { infoMode : InfoMode
    , mapStatus : MH.MapStatus
    , startPoint : MH.RoutePoint
    , endPoint : MH.RoutePoint
    , mapRoutes : MapRoutes
    , selectedRoute : Maybe RouteSummary
    , transport : MH.Transport
    , landmarksList : List MH.Landmark
    , landmarkSummary : MH.SummaryType
    , landmarkSummaryList : Dict Int MH.Summary
    , addressResults : MH.AddressResults
    , redactedRoutePoint : MH.RedactedPoint
    }


type InfoMode
    = Closed
    | ViewSummary
    | ViewDirections MH.RoutePoint MH.RoutePoint
    | ViewRoute
    | Hide


-- UPDATE


type Msg
    = NoOp
      -- Map
    | MapStatusMsg String
    | MapSearchResponse (Result Decode.Error (List MH.Address))
    | MapSearchClear
    | MapRoutesResponse (Result Decode.Error (List RouteSummary))
    | MapRoutesUpdate MH.RoutePoint
    | MapRoutesTransport MH.Transport
    | MapRouteSelected RouteSummary

      -- Info Element
    | InfoOpen (Maybe Int)
    | InfoOpenDirections String Position
    | InfoOpenRoute
    | InfoUpdateRouteFocus MH.RedactedPoint
    | InfoClose
    | InfoHide

      -- Geoservices
    | GeoserviceLocationReceive (Result Decode.Error Position)

      -- Load data.json
    | LoadLandmarksList (Result Http.Error (List MH.Landmark))

      -- Received Wikipedia summary pages
    | LoadLandmarksWiki (Result Http.Error MH.Summary)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        MapStatusMsg status -> 
            case status of 
                "loaded" ->
                    ( { model | mapStatus = MH.MapLoaded }

                    -- Comment when deploying 
                    --, getLandmarksRequest "/../public/data.json" 

                    -- Uncomment when deploying
                    , getLandmarksRequest "/discover-sofia/public/data.json" 
                    )

                "failed" ->
                    ( { model | mapStatus = MH.MapLoadingFialed "Failed Loading the Map" }
                    , Cmd.none 
                    )

                _ ->
                    ( model, Cmd.none )

        MapSearchResponse (Ok items) ->
            ( { model | addressResults = MH.AddressResultsLoaded items }, Cmd.none )

        MapSearchResponse (Err items) ->
            case items of
                Decode.Failure _ value ->
                    case Decode.decodeValue decodeErrorValue value of 
                        Ok errString ->
                            ( { model | 
                                addressResults = MH.AddressResultsErr errString.status 
                              }
                            , Cmd.none
                            )

                        _ ->
                            ( { model | 
                                addressResults = MH.AddressResultsErr 
                                    "Response body is incorrect" 
                              }
                            , Cmd.none 
                            )

                _ ->
                    ( { model | addressResults = MH.AddressResultsErr "Response body is incorrect" }
                    , Cmd.none 
                    )

        MapSearchClear ->
            ( { model | addressResults = MH.AddressResultsEmpty }, Cmd.none )


        MapRoutesUpdate routePoint ->
            case routePoint of
                MH.StartPointValid address position ->
                    ({ model | startPoint = routePoint }, Cmd.none)

                MH.StartPointInvalid address ->
                    ({ model | startPoint = routePoint }, mapSearchHelper address model)

                MH.EndPointValid _ _ ->
                    ({ model | endPoint = routePoint }, Cmd.none)

                MH.EndPointInvalid address ->
                    ({ model | endPoint = routePoint }, mapSearchHelper address model)

        MapRoutesResponse (Ok routesList) ->
            ( { model | mapRoutes = MH.RoutesResponse routesList }
            , Cmd.none
            )

        MapRoutesResponse (Err mapRouteErr) ->
            case mapRouteErr of 
                Decode.Failure _ value ->
                    case Decode.decodeValue decodeErrorValue value of
                        Ok errString ->
                            ( { model | mapRoutes 
                                = MH.RoutesResponseErr errString.status 
                              }
                            , Cmd.none
                            )

                        _ -> 
                            ( { model | mapRoutes 
                                = MH.RoutesResponseErr "There is something wrong with the response" }
                            , Cmd.none 
                            )            

                _ ->
                    ( { model | mapRoutes 
                        = MH.RoutesResponseErr "There is something wrong with the response" }
                    , Cmd.none 
                    )

        MapRoutesTransport transport ->
            let
                newModel = { model | transport = transport }
            in
            ( newModel, mapRoutesHelper newModel )

        MapRouteSelected selectedRoute ->
            ( { model | selectedRoute = (Just selectedRoute) }
            , mapRoutesShowSelected (MH.routeSummaryEncoder selectedRoute) 
            )

        -- InfoView
        InfoOpen (Just id) ->
            case Dict.get id model.landmarkSummaryList of
                Just landmarkSummary ->
                    ( { model | infoMode = ViewSummary
                      , landmarkSummary = MH.SummaryValid landmarkSummary
                      , addressResults = MH.AddressResultsEmpty
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        InfoOpen Nothing ->
            ( { model | infoMode = ViewSummary }, Cmd.none )

        InfoClose ->
            ( { model | infoMode = Closed
              , landmarkSummary = MH.SummaryInvalid 
              , addressResults = MH.AddressResultsEmpty
              }
            , mapMarkerShowAll ()
            )

        InfoHide ->
            ( { model | infoMode = Hide }
            , Cmd.none
            )

        InfoOpenDirections address position ->
            ( { model
                | infoMode = ViewDirections 
                    (MH.StartPointInvalid "empty") 
                    (MH.EndPointValid address position)
                , endPoint = MH.EndPointValid address position
              }
            , geoserviceLocationCall ()
            )

        InfoOpenRoute ->
            ( { model | infoMode = ViewRoute, mapRoutes = MH.RoutesCalculating }
            , mapRoutesHelper model
            )

        InfoUpdateRouteFocus redactedPoint ->
            ( { model | redactedRoutePoint = redactedPoint}, Cmd.none )


        -- Directions
        GeoserviceLocationReceive (Ok currentPosition) ->
            ( { model | startPoint = MH.StartPointValid "Current Position" currentPosition
              }
            , Cmd.none
            )

        GeoserviceLocationReceive (Err invalidPosition) ->
            ( { model | addressResults = MH.AddressResultsErr "Couldn't get position" }
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
        LoadLandmarksWiki (Ok summary) ->
            ( { model
                | landmarkSummaryList =
                    model.landmarkSummaryList
                        |> Dict.insert summary.id summary
              }
            , mapMarkerAddCustom (MH.markerInfoEncoder summary)
            )

        LoadLandmarksWiki (Err summary) ->
            ( model, Cmd.none )



type alias ErrorValue =
    { status : String }



decodeErrorValue : Decode.Decoder ErrorValue
decodeErrorValue =
    Decode.succeed ErrorValue
        |> DecodePipe.optional "error" Decode.string ""





mapRoutesHelper : Model -> Cmd Msg
mapRoutesHelper { startPoint, endPoint, transport }  =
    case (startPoint, endPoint ) of 
        (MH.StartPointValid _ origin, MH.EndPointValid _ destination ) ->
            let 
                transportMode = transportModeHelper transport
                params = MH.routeParamEncoder origin destination transportMode
            in
            mapRoutesCalculate params

        _ ->
            Cmd.none


transportModeHelper : MH.Transport -> String
transportModeHelper transport =
    case transport of 
        MH.Car ->
            "car"

        MH.Walk ->
            "pedestrian"



mapSearchHelper : String -> Model -> Cmd Msg
mapSearchHelper address model =
    if String.isEmpty address then
        let 
            (_, cmds) = update MapSearchClear model
        in
        cmds
    else 
        mapSearch address


-- HTTP REQUESTS


{-
   Uncomment when deploying to Github/GitLab
   Wiki Link: https://en.wikipedia.org/api/rest_v1/page/summary/Stack_Overflow
-}
wikiUrlBuilder : String -> String
wikiUrlBuilder wikiName =
    crossOrigin
        "https://en.wikipedia.org"
        [ "api" ,"rest_v1", "page", "summary", wikiName]
        []

{-
   Comment when deploying to Github/GitLab
   With cors-anywhere (npm install cors-anywhere)
   Link: url2 = "http://localhost:8080/https://en.wikipedia.org/api/rest_v1/page/summary/Stack_Overflow"
-}
--wikiUrlBuilder : String -> String
--wikiUrlBuilder wikiName =
--    crossOrigin
--        "http://localhost:8080"
--        [ "https://en.wikipedia.org/api/rest_v1/page/summary", wikiName ]
--        []


getLandmarkWiki : MH.Landmark -> Cmd Msg
getLandmarkWiki landmark =
    Http.get
        { url = wikiUrlBuilder landmark.wikiName
        , expect = 
            Http.expectJson LoadLandmarksWiki (MH.summaryDecoder landmark.id)
        }


getLandmarksRequest : String -> Cmd Msg
getLandmarksRequest url =
    Http.get
        { url = url
        , expect = Http.expectJson LoadLandmarksList MH.landmarkListDecoder
        }



-- VIEW


view : Model -> Html Msg
view model =
    div [ id "map-page" ]
        [ viewMode model ]


viewMode : Model -> Html Msg
viewMode model =
    case model.mapStatus of
        MH.MapLoading ->
            div [ id "map-status" ] 
                [ 
                p [] [ text "Loading..." ] 
                ]

        MH.MapLoadingFialed err ->
            text err

        MH.MapLoaded ->
            case model.infoMode of
                Closed ->
                    text ""

                ViewDirections startPosition endPosition ->
                    viewDirection model

                ViewSummary ->
                    viewSummary model.landmarkSummary

                ViewRoute ->
                    viewRoute model

                Hide ->
                    button 
                        [ class "show-routes-btn"
                        , onClick InfoOpenRoute 
                        ] 
                        [ text "Show Routes" ] 




-- ROUTE


viewRoute : Model -> Html Msg
viewRoute model =
    div [ class "info-container" ] 
        [ viewRouteViewControls model.startPoint model.endPoint model.selectedRoute
        , viewTransportControls model.transport
        , hr [ style "heigth" "1px", style "width" "100%" ] []
        , viewRouteResults model.mapRoutes model.selectedRoute
        ]


viewRouteViewControls : MH.RoutePoint -> MH.RoutePoint -> Maybe RouteSummary -> Html Msg
viewRouteViewControls startPoint endPoint maybeRouteSummary =
    case ( startPoint, endPoint, maybeRouteSummary ) of 
        ( _ , MH.EndPointValid address position, Nothing ) ->
            div [ class "info-controls-container"]
                [ button 
                    [ classList 
                        [ ( "info-control", True )
                        , ( "close", True )
                        ]
                    , onClick (InfoOpenDirections address position)
                    ]
                    [ text "Back" ]
                , button
                    [ classList
                        [ ( "info-control", True )
                        , ( "start-navigation", True )
                        ]
                    , onClick InfoHide
                    ]
                    [ text "Hide" ]
                ]

        ( MH.StartPointValid _ startPosition, MH.EndPointValid endAddress endPosition, Just routeSummary ) ->
            div [ class "info-controls-container"]
                [ button 
                    [ classList 
                        [ ( "info-control", True )
                        , ( "close", True )
                        ]
                    , onClick (InfoOpenDirections endAddress endPosition)
                    ]
                    [ text "Back" ]
                , button
                    [ classList
                        [ ( "info-control", True )
                        , ( "start-navigation", True )
                        , ( "button-disabled", False )
                        ]
                    , onClick InfoHide
                    ]
                    [ text "Hide" ]
                ]

        ( _, _ , _ ) ->
            text ""


viewTransportControls : MH.Transport -> Html Msg
viewTransportControls transport =
    let 

        isCarChosen = 
            case transport of
                MH.Car ->
                    True

                MH.Walk ->
                    False

        isWalkChosen = not isCarChosen 
    in
    div [ class "info-controls-container"]
        [ button 
            [ classList 
                [ ( "info-control", True )
                , ( "transport", True )
                , ( "selected-transport", isCarChosen )
                ]
            , onClick (MapRoutesTransport MH.Car)
            ]
            [ text "Car" ]
        , button
            [ classList
                [ ( "info-control", True )
                , ( "transport", True )
                , ( "selected-transport", isWalkChosen )
                ]
            , onClick (MapRoutesTransport MH.Walk)
            ]
            [ text "Walk" ]
        ]


viewRouteResults : MapRoutes -> Maybe RouteSummary -> Html Msg
viewRouteResults mapRoute routeId =
    case mapRoute of 
        MH.RoutesUnavailable ->
            p [ style "text-align" "center" ] [ text "No Routes available" ]

        MH.RoutesCalculating ->
            p [ style "text-align" "center" ] [ text "Calculating Routes..." ]

        MH.RoutesResponseErr err ->
            p [ style "text-align" "center" ] [ text err ]

        MH.RoutesResponse routesList ->
            case routesList of
                [] ->
                    p [ style "text-align" "center" ] [ text "No Routes available" ]

                _ ->
                    div [ id "routes-results" ]
                        (List.map (viewRouteSuggestion routeId) routesList )


viewRouteSuggestion : Maybe RouteSummary -> RouteSummary ->  Html Msg
viewRouteSuggestion maybeRoute routeSummary =
    let
        isSelected =
            case maybeRoute of
                Just route ->
                    if route.id == routeSummary.id then
                        True

                    else
                        False

                Nothing ->
                    False
    in
    div 
        [ classList 
            [ ( "route-suggestion", True) 
            ]
        , onClick (MapRouteSelected routeSummary)
        ] 
        [ div 
            [ classList 
                [ ( "route-indicator", True )
                , ( "selected-route", isSelected )
                ] 
            ] 
            []
        , p [] [ text routeSummary.duration ]
        , p [] [ text routeSummary.distance ]
        ]





-- DIRECTIONS


viewDirection : Model -> Html Msg
viewDirection { startPoint, endPoint, redactedRoutePoint, addressResults } =
    div [ class "info-container" ]
        [ viewDirectionsControls (startPoint, endPoint)
        , viewAddressInputs (startPoint, endPoint)
        , hr [ style "heigth" "1px", style "width" "100%" ] []
        , viewAddressResults addressResults redactedRoutePoint
        ]


viewDirectionsControls : ( MH.RoutePoint, MH.RoutePoint ) -> Html Msg
viewDirectionsControls ( startPoint, endPoint ) =
    case ( startPoint, endPoint ) of
        ( MH.StartPointValid _ _, MH.EndPointValid _ _ ) ->
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
            , onClick (InfoOpen Nothing)
            ]
            [ text "Back" ]
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


viewAddressInputs : (MH.RoutePoint, MH.RoutePoint) -> Html Msg
viewAddressInputs ( startPoint, endPoint ) =
    div [ id "address-inputs" ]
        [ inputWrapperFrom startPoint
        , inputWrapperTo endPoint
        ]


inputWrapperFrom : MH.RoutePoint -> Html Msg
inputWrapperFrom startPoint =
    let
        isValidAdrress = 
            case startPoint of
                MH.StartPointValid _ _ ->
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
            [ onInput (\text -> MapRoutesUpdate (MH.StartPointInvalid text))
            , onFocus (InfoUpdateRouteFocus MH.StartPoint)
            , autofocus True
            , placeholder "Search"
            , value (pointToString startPoint)
            , type_ "search"
            ]
            []
        ]


inputWrapperTo : MH.RoutePoint -> Html Msg
inputWrapperTo endPoint =
    let
        isValidAdrress = 
            case endPoint of
                MH.EndPointValid _ _ ->
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
            [ onInput (\text -> MapRoutesUpdate (MH.EndPointInvalid text))
            , onFocus (InfoUpdateRouteFocus MH.EndPoint)
            , placeholder "Search"
            , value (pointToString endPoint)
            , type_ "search"
            ]
            []
        ]


viewAddressResults : MH.AddressResults -> MH.RedactedPoint -> Html Msg
viewAddressResults results redactedPoint =
    case results of
        MH.AddressResultsLoaded items ->
            case items of 
                [] ->
                    p [ style "text-align" "center" ] [ text "No results" ]

                _ ->
                    ul [ id "address-results" ]
                        (List.map (viewAddressSuggestion redactedPoint) items )

        MH.AddressResultsEmpty ->
            p [ style "text-align" "center" ] [ text "No results" ]

        MH.AddressResultsLoading ->
            p [ style "text-align" "center" ] [ text "Loading..." ]

        MH.AddressResultsErr err ->
            p [ style "text-align" "center" ] [ text err ]


viewAddressSuggestion : MH.RedactedPoint -> MH.Address -> Html Msg
viewAddressSuggestion redactedPoint item =
    let 
        point =
            case redactedPoint of
                MH.StartPoint ->
                    MH.StartPointValid item.address.label item.position

                MH.EndPoint -> 
                    MH.EndPointValid item.address.label item.position
    in
    li
        [ class "address-suggestion"
        , attribute "data-lan" (String.fromFloat item.position.lat)
        , attribute "data-lng" (String.fromFloat item.position.lng)
        , attribute "data-title" item.address.label
        , onClick (MapRoutesUpdate point)
        ]
        [ p [ class "address-name" ] [ text item.address.label ]
        , p [ class "address-details" ] 
            [ span [ class "text-with-background" ] [ text item.address.county ]
            , text " "
            , span [ class "text-with-background" ] [ text item.address.district ]
            , text " "
            , span [ class "text-with-background" ] [ text item.address.countryName ]
            ]
        ]



-- Summary


viewSummary : MH.SummaryType -> Html Msg
viewSummary summaryType =
    case summaryType of
        MH.SummaryValid summary ->
            div [ class "info-container" ]
                [ viewInfoControls summary
                , hr [ style "heigth" "1px", style "width" "100%" ] []
                , div [ id "summary" ]
                    [ viewTitle summary.title
                    , viewImage summary
                    , viewText summary.extract
                    , viewWikiLink summary.wikiUrl
                    ]
                ]

        MH.SummaryInvalid ->
            div [ id "summary-container" ] [ text "No info" ]


viewInfoControls : MH.Summary -> Html Msg
viewInfoControls landmark =
    div [ class "info-controls-container" ]
        [ button 
            [ classList
                [ ( "info-control", True )
                , ( "close", True )
                ]
            , onClick InfoClose 
            ] 
            [ text "Close" ]
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


viewImage : MH.Summary -> Html Msg
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


pointToString : MH.RoutePoint -> String
pointToString point =
    case point of
        MH.StartPointInvalid title ->
            title

        MH.StartPointValid title position ->
            title ++ ", " ++ MH.positionToString position

        MH.EndPointInvalid title ->
            title

        MH.EndPointValid title position ->
            title ++ ", " ++ MH.positionToString position
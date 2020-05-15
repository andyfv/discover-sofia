port module Page.Map exposing (Model, Msg(..), init, subscriptions, update, view)

import Http
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, onMouseEnter, onMouseLeave, onFocus)
import Json.Decode exposing (Error, Value, decodeValue)
import Url.Builder as UrlBuilder exposing (crossOrigin)

import MapValues
    exposing
        ( Item
        , Position
        , RouteSummary
        , RoutePoint
        , itemListDecoder
        , positionDecoder
        , positionEncoder
        , positionToString
        , routeSummaryListDecoder
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


import Page.MapView.RouteView as RouteView
import Page.MapView.ViewSummary as ViewSummary



-- Map ports
port mapLoad : () -> Cmd msg
port mapLoaded : (() -> msg) -> Sub msg
port mapLoadingFailed : (String -> msg) -> Sub msg

-- Search
port mapSearch : String -> Cmd msg
port mapSearchResponse : (Value -> msg) -> Sub msg
port mapSearchFailed : (String -> msg) -> Sub msg

--port mapRoutesCalculate : Value -> Cmd msg
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
        , mapMarkerOpenSummary (\id -> InfoOpen (Just id))
        , mapSearchResponse (decodeValue itemListDecoder >> MapSearchResponse)
        , mapSearchFailed (\err -> MapSearchError err)
        --, mapRoutesResponse (decodeValue routeSummaryListDecoder >> MapRoutesResponse)

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
    , landmarksList : List Landmark
    , landmarkSummary : SummaryType
    , landmarkSummaryList : Dict Int Summary
    , addressResults : AddressResults
    , redactedRoutePoint : RedactedPoint
    }


type InfoMode
    = Closed
    | ViewSummary ViewSummary.Model
    | ViewDirections
    | ViewRoute RouteView.Model


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
    | ViewRouteMsg RouteView.Msg
      -- MapStatus
    | MapLoadedOk
    | MapLoadedErr String
    | MapMarkerAddDefault Position
    | MapSearchResponse (Result Json.Decode.Error (List Item))
    | MapSearchClear
    | MapSearchError String
    --
    | MapRoutesUpdate RoutePoint
      -- Info Element
    | InfoOpen (Maybe Int)
    | InfoOpenDirections String Position
    | InfoOpenRoute
    | InfoUpdateRouteFocus RedactedPoint
    | InfoClose
      -- DirectionsView
    | GeoserviceLocationReceive (Result Json.Decode.Error Position)
    | GeoserviceLocationError String
      -- Load data.json
    | LoadLandmarksList (Result Http.Error (List Landmark))
      -- Received Wikipedia summary pages
    | LoadLandmarskWiki (Result Http.Error Summary)



processOutMsg : RouteView.OutMsg -> Model -> (Model, Cmd Msg)
processOutMsg outMsg model =
    case outMsg of 
        RouteView.NoOutMsg ->
            (model, Cmd.none)

        RouteView.BackToDirections address position ->
            ( { model
                | infoMode = ViewDirections
                , endPoint = EndPointValid address position
              }
            , geoserviceLocationGet ()
            )



update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.infoMode) of
        ( NoOp, _ ) ->
            ( model, Cmd.none )

        ( ViewRouteMsg childMsg, ViewRoute pageModel ) ->
            let 
                (newChild, childCmds, outMsg) = 
                    RouteView.update childMsg pageModel

                (newModel, cmdsFromChild) = 
                    processOutMsg outMsg { model | infoMode = ViewRoute newChild }

            in
            (newModel, Cmd.batch[ Cmd.map ViewRouteMsg childCmds, cmdsFromChild ] ) 


        ( MapLoadedOk, _ ) ->
            ( { model | mapStatus = MapLoaded }
            , getLandmarksRequest "/../assets/data.json"
            )

        ( MapLoadedErr err, _ ) ->
            ( { model | mapStatus = MapNotLoaded err }, Cmd.none )

        ( MapMarkerAddDefault position, _ ) ->
            ( model, Cmd.none )

        ( MapSearchResponse (Ok items), _ )  ->
            ( { model | addressResults = AddressResultsLoaded items }, Cmd.none )

        ( MapSearchResponse (Err items), _ ) ->
            ( { model | addressResults = AddressResultsErr "Response body is incorrect" }, Cmd.none )

        ( MapSearchClear, _ ) ->
            ( { model | addressResults = AddressResultsEmpty }, Cmd.none )

        ( MapSearchError err, _ ) ->
            let
                _ = Debug.log "err" err
                --"Fetching suggestions has failed"
            in
            ( { model | addressResults = AddressResultsErr err }, Cmd.none )

        ( MapRoutesUpdate routePoint, _ ) ->
            case routePoint of
                StartPointValid address position ->
                    ({ model | startPoint = routePoint }, Cmd.none)

                StartPointInvalid address ->
                    ({ model | startPoint = routePoint }, mapSearchHelper address model)

                EndPointValid _ _ ->
                    ({ model | endPoint = routePoint }, Cmd.none)

                EndPointInvalid address ->
                    ({ model | endPoint = routePoint }, mapSearchHelper address model)


        -- InfoView
        ( InfoOpen (Just id), _ ) ->
            case Dict.get id model.landmarkSummaryList of
                Just landmarkSummary ->
                    ( { model | infoMode = ViewSummary landmarkSummary
                      , landmarkSummary = SummaryValid landmarkSummary
                      , addressResults = AddressResultsEmpty
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( InfoOpen Nothing, _ ) ->
            ( { model | infoMode = ViewSummary }, Cmd.none )

        ( InfoClose, _ ) ->
            ( { model | infoMode = Closed
              , landmarkSummary = SummaryInvalid 
              , addressResults = AddressResultsEmpty
              }
            , Cmd.none
            )

        ( InfoOpenDirections address position, _ ) ->
            ( { model
                | infoMode = ViewDirections
                , endPoint = EndPointValid address position
              }
            , geoserviceLocationGet ()
            )

        ( InfoOpenRoute, _ ) ->
            ( model
                --{ model | 
                --infoMode = ViewRoute RouteView.
                -- mapRoutes = RoutesCalculating 
                --}
            --, mapRoutesHelper model
            , Cmd.none
            )

        ( InfoUpdateRouteFocus redactedPoint, _ ) ->
            ( { model | redactedRoutePoint = redactedPoint}, Cmd.none )


        -- Directions
        ( GeoserviceLocationReceive (Ok currentPosition), _ ) ->
            ( { model | startPoint = StartPointValid "Current Position" currentPosition }
            , Cmd.none
            )

        ( GeoserviceLocationReceive (Err invalidPosition), _ ) ->
            ( { model | addressResults = AddressResultsErr "Invalid Position" }
            , Cmd.none
            )

        ( GeoserviceLocationError err, _ ) ->
            ( { model | addressResults = AddressResultsErr err }
            , Cmd.none
            )

        -- Received data.json
        ( LoadLandmarksList (Ok landmarksList), _ )  ->
            ( { model | landmarksList = landmarksList }
            , Cmd.batch (List.map getLandmarkWiki landmarksList)
            )

        ( LoadLandmarksList (Err landmarksList), _ ) ->
            ( model, Cmd.none )

        -- Received Wikipedia summary pages
        ( LoadLandmarskWiki (Ok summary), _ ) ->
            ( { model
                | landmarkSummaryList =
                    model.landmarkSummaryList
                        |> Dict.insert summary.id summary
              }
            , mapMarkerAddCustom (markerInfoEncoder summary)
            )

        ( LoadLandmarskWiki (Err summary), _ ) ->
            ( model, Cmd.none )


        -- FALLBACK
        ( _, _ ) -> 
            ( model, Cmd.none )




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

                ViewSummary pageModel ->
                    viewSummary model.landmarkSummary

                ViewRoute pageModel ->
                    Html.map ViewRouteMsg (RouteView.view pageModel)



-- DIRECTIONS


viewDirection : Model -> Html Msg
viewDirection { startPoint, endPoint, redactedRoutePoint, addressResults } =
    div [ class "info-container" ]
        [ viewDirectionsControls (startPoint, endPoint)
        , viewAddressInputs (startPoint, endPoint)
        , hr [ style "heigth" "1px", style "width" "100%" ] []
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
            --, onClick InfoOpenRoute (model, )
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
            [ onInput (\text -> MapRoutesUpdate (StartPointInvalid text))
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
            [ onInput (\text -> MapRoutesUpdate (EndPointInvalid text))
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
            p [ style "text-align" "center" ] [ text err ]


viewAddressSuggestion : RedactedPoint -> Item -> Html Msg
viewAddressSuggestion redactedPoint item =
    let 
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
        , onClick (MapRoutesUpdate point)
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
                , hr [ style "heigth" "1px", style "width" "100%" ] []
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
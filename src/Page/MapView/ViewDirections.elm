port module Page.MapView.ViewDirections exposing (Model, Msg, OutMsg(..), view, update, init, subscriptions)


import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, onMouseEnter, onMouseLeave, onFocus)
import Json.Decode exposing (Error, Value, decodeValue)

import MapValues as MapValues


-- Directions ports

-- Geoservices
port geoserviceLocationGet : () -> Cmd msg
port geoserviceLocationReceive : (Value -> msg) -> Sub msg
port geoserviceLocationError : (String -> msg) -> Sub msg


-- Search
port mapSearch : String -> Cmd msg
port mapSearchResponse : (Value -> msg) -> Sub msg
port mapSearchFailed : (String -> msg) -> Sub msg


subscriptions : Sub Msg
subscriptions = 
    Sub.batch 
        [ geoserviceLocationReceive 
            (decodeValue MapValues.positionDecoder >> GeoserviceLocationReceive)
        , geoserviceLocationError 
            (\message -> GeoserviceLocationError message)
        ] 
    


-- MODEL

init : MapValues.RoutePoint -> ( Model, Cmd Msg, OutMsg )
init endPoint =
    ( { startPoint = MapValues.StartPointInvalid ""
      , endPoint = endPoint
      , addressResults = AddressResultsEmpty
      , redactedRoutePoint = StartPoint
      }
    , geoserviceLocationGet ()
    , NoOutMsg
    )


type alias Model =
    { startPoint : MapValues.RoutePoint
    , endPoint : MapValues.RoutePoint
    , addressResults : AddressResults
    , redactedRoutePoint : RedactedPoint
    }



type AddressResults
    = AddressResultsEmpty
    | AddressResultsLoading
    | AddressResultsLoaded (List MapValues.Item)
    | AddressResultsErr String


type RedactedPoint
    = StartPoint
    | EndPoint


-- UDPATE 

type Msg 
    = MapSearchResponse (Result Json.Decode.Error (List MapValues.Item))
    | MapSearchClear
    | MapSearchError String
    | MapAddressUpdate MapValues.RoutePoint
    | MapAddressFocusUpdate RedactedPoint
    | GeoserviceLocationReceive (Result Json.Decode.Error MapValues.Position)
    | GeoserviceLocationError String
    | GoBack (Maybe Int)



type OutMsg 
    = NoOutMsg
    | GoBackToViewSummary (Maybe Int)


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of 
        GeoserviceLocationReceive (Ok currentPosition) ->
            ( { model | startPoint = MapValues.StartPointValid "Current Position" currentPosition }
            , Cmd.none
            , NoOutMsg
            )

        GeoserviceLocationReceive (Err invalidPosition) ->
            ( { model | addressResults = AddressResultsErr "Invalid Position" }
            , Cmd.none
            , NoOutMsg
            )

        GeoserviceLocationError err ->
            ( { model | addressResults = AddressResultsErr err }
            , Cmd.none
            , NoOutMsg
            )

        MapAddressUpdate addressPoint ->
            case addressPoint of
                MapValues.StartPointValid address position ->
                    ({ model | startPoint = addressPoint }, Cmd.none, NoOutMsg)

                MapValues.StartPointInvalid address ->
                    ({ model | startPoint = addressPoint }
                    , mapSearchHelper address model
                    , NoOutMsg
                    )

                MapValues.EndPointValid _ _ ->
                    ({ model | endPoint = addressPoint }, Cmd.none, NoOutMsg)

                MapValues.EndPointInvalid address ->
                    ({ model | endPoint = addressPoint }
                    , mapSearchHelper address model
                    , NoOutMsg
                    )


        MapSearchResponse (Ok items) ->
            ( { model | addressResults = AddressResultsLoaded items }
            , Cmd.none
            , NoOutMsg
            )

        MapSearchResponse (Err items) ->
            ( { model | addressResults = AddressResultsErr "Response body is incorrect" }
            , Cmd.none
            , NoOutMsg
            )

        MapSearchClear ->
            ( { model | addressResults = AddressResultsEmpty }
            , Cmd.none
            , NoOutMsg
            )

        MapSearchError err ->
            ( { model | addressResults = AddressResultsErr err }
            , Cmd.none
            , NoOutMsg
            )

        MapAddressFocusUpdate redactedPoint ->
            ( { model | redactedRoutePoint = redactedPoint}
            , Cmd.none
            , NoOutMsg
            )

        GoBack maybeInt ->
            (model, Cmd.none, GoBackToViewSummary maybeInt)

mapSearchHelper : String -> Model -> Cmd Msg
mapSearchHelper address model =
    if String.isEmpty address then
        let 
            (_, cmds, outMsg) = update MapSearchClear model
        in
        cmds
    else 
        mapSearch address




-- VIEW

view : Model -> Html Msg
view { startPoint, endPoint, redactedRoutePoint, addressResults } =
    div [ class "info-container" ]
        [ viewDirectionsControls (startPoint, endPoint)
        , viewAddressInputs (startPoint, endPoint)
        , hr [ style "heigth" "1px", style "width" "100%" ] []
        , viewAddressResults addressResults redactedRoutePoint
        ]


viewDirectionsControls : ( MapValues.RoutePoint, MapValues.RoutePoint ) -> Html Msg
viewDirectionsControls ( startPoint, endPoint ) =
    case ( startPoint, endPoint ) of
        ( MapValues.StartPointValid _ _, MapValues.EndPointValid _ _ ) ->
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
            , onClick (GoBack Nothing)
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


viewAddressInputs : (MapValues.RoutePoint, MapValues.RoutePoint) -> Html Msg
viewAddressInputs ( startPoint, endPoint ) =
    div [ id "address-inputs" ]
        [ inputWrapperFrom startPoint
        , inputWrapperTo endPoint
        ]


inputWrapperFrom : MapValues.RoutePoint -> Html Msg
inputWrapperFrom startPoint =
    let
        isValidAdrress = 
            case startPoint of
                MapValues.StartPointValid _ _ ->
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
            [ onInput (\text -> MapAddressUpdate (MapValues.StartPointInvalid text))
            , onFocus (MapAddressFocusUpdate StartPoint)
            , autofocus True
            , placeholder "Search"
            , value (pointToString startPoint)
            , type_ "search"
            ]
            []
        ]


inputWrapperTo : MapValues.RoutePoint -> Html Msg
inputWrapperTo endPoint =
    let
        isValidAdrress = 
            case endPoint of
                MapValues.EndPointValid _ _ ->
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
            [ onInput (\text -> MapAddressUpdate (MapValues.EndPointInvalid text))
            , onFocus (MapAddressFocusUpdate EndPoint)
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


viewAddressSuggestion : RedactedPoint -> MapValues.Item -> Html Msg
viewAddressSuggestion redactedPoint item =
    let 
        point =
            case redactedPoint of
                StartPoint ->
                    MapValues.StartPointValid item.address.label item.position

                EndPoint -> 
                    MapValues.EndPointValid item.address.label item.position
    in
    li
        [ class "address-suggestion"
        , attribute "data-lan" (String.fromFloat item.position.lat)
        , attribute "data-lng" (String.fromFloat item.position.lng)
        , attribute "data-title" item.address.label
        , onClick (MapAddressUpdate point)
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



-- HELPERS


pointToString : MapValues.RoutePoint -> String
pointToString point =
    case point of
        MapValues.StartPointInvalid title ->
            title

        MapValues.StartPointValid title position ->
            title ++ ", " ++ MapValues.positionToString position

        MapValues.EndPointInvalid title ->
            title

        MapValues.EndPointValid title position ->
            title ++ ", " ++ MapValues.positionToString position
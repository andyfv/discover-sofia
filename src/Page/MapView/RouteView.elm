port module Page.MapView.RouteView exposing (Model, Msg, OutMsg(..), view, update, init, subscriptions)


import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, onMouseEnter, onMouseLeave, onFocus)
import Json.Decode as Decode exposing (Error(..), Value, decodeValue)
import Json.Decode.Pipeline as DecodePipe


import MapHelper as MH exposing (Position, RouteSummary, MapRoutes)

--import MapValues
--    exposing
--        ( Item
--        , Position
--        , RouteSummary
--        , RoutePoint(..)
--        , itemListDecoder
--        , positionDecoder
--        , positionEncoder
--        , positionToString
--        , routeSummaryListDecoder
--        , routeParamEncoder
--        )


port mapRoutesCalculate : Value -> Cmd msg
port mapRoutesResponse : (Value -> msg) -> Sub msg
port mapRoutesShowSelected : Value -> Cmd msg




-- SUBSCRIPTIONS


subscriptions : Sub Msg
subscriptions =
    Sub.batch
        [ mapRoutesResponse (decodeValue MH.routeSummaryListDecoder >> MapRoutesResponse)
        ]



-- MODEL

init : MH.RoutePoint -> MH.RoutePoint -> ( Model, Cmd Msg, OutMsg )
init startPoint endPoint =
    ( { mapRoutes = MH.RoutesUnavailable
      , selectedRoute = Nothing
      , transport = Car
      , startPoint = MH.StartPointInvalid ""
      , endPoint = MH.EndPointInvalid ""
      }
    , Cmd.none
    , NoOutMsg
    )


type alias Model = 
    { mapRoutes : MH.MapRoutes
    , selectedRoute : Maybe RouteSummary
    , transport : Transport
    , startPoint : MH.RoutePoint
    , endPoint : MH.RoutePoint
    }



--type MapRoute
--    = RouteNotSelected
--    | RouteSelected RouteSummary String



--type MapRoutesResponse
--    = RoutesUnavailable
--    | RoutesCalculating
--    | RoutesResponse (List RouteSummary)
--    | RoutesResponseErr String


type Transport
    = Car
    | Walk




-- UPDATE



type Msg 
    = NoOp
    | MapRoutesResponse (Result Decode.Error (List RouteSummary))
    | MapRoutesTransport Transport
    | MapRouteSelected MH.RouteSummary
    | PreviousPage String Position


type OutMsg
    = NoOutMsg
    | BackToDirections String Position




update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none, NoOutMsg )

        MapRoutesResponse (Ok routesList) ->
            ( { model | mapRoutes = MH.RoutesResponse routesList }
            , Cmd.none
            , NoOutMsg 
            )

        MapRoutesResponse (Err mapRoutesErr) ->
            --( { model | mapRoutes = RoutesResponseErr "There is something wrong with the resonse" }
            --, Cmd.none
            --, NoOutMsg
            --)
            case mapRoutesErr of 
                Decode.Failure _ value ->
                    case Decode.decodeValue decodeErrorValue value of
                        Ok errString ->
                            ( { model | mapRoutes 
                                = MH.RoutesResponseErr errString.status 
                              }
                            , Cmd.none
                            , NoOutMsg
                            )

                        _ -> 
                            ( { model | mapRoutes 
                                = MH.RoutesResponseErr "There is something wrong with the response" }
                            , Cmd.none
                            , NoOutMsg 
                            )            

                _ ->
                    ( { model | mapRoutes 
                        = MH.RoutesResponseErr "There is something wrong with the response" }
                    , Cmd.none 
                    , NoOutMsg
                    )

        MapRoutesTransport transport ->
            let
                newModel = { model | transport = transport }
            in
            ( newModel, mapRoutesHelper newModel, NoOutMsg )

        MapRouteSelected selectedRoute ->
            ( { model | selectedRoute = (Just selectedRoute) }
            , mapRoutesShowSelected (MH.routeSummaryEncoder selectedRoute)
            , NoOutMsg 
            )
            --case selectedRoute of 
            --    RouteSelected selectedRoute _ ->
            --        ( { model | selectedRoute = route }, Cmd.none, NoOutMsg )

            --    RouteNotSelected ->
            --        ( model, Cmd.none, NoOutMsg )

        PreviousPage address position ->
            ( model, Cmd.none, BackToDirections address position )


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




transportModeHelper : Transport -> String
transportModeHelper transport =
    case transport of 
        Car ->
            "car"

        Walk ->
            "pedestrian"



--getMapRouteId : MapRoute -> String
--getMapRouteId mapRoute =
--    case mapRoute of 
--        RouteNotSelected ->
--            ""

--        RouteSelected route id ->
--            id


-- VIEW

view : Model -> Html Msg
view model =
    div [ class "info-container" ] 
        [ viewRouteViewControls model.endPoint
        , viewTransportControls model.transport
        , hr [ style "heigth" "1px", style "width" "100%" ] []
        , viewRouteResults model.mapRoutes model.selectedRoute
        ]


viewRouteViewControls : MH.RoutePoint -> Html Msg
viewRouteViewControls routePoint =
    case routePoint of 
        MH.EndPointValid address position ->
            div [ class "info-controls-container"]
                [ button 
                    [ classList 
                        [ ( "info-control", True )
                        , ( "close", True )
                        ]
                    , onClick (PreviousPage address position)
                    ]
                    [ text "Back" ]
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

        _ ->
            text ""


viewTransportControls : Transport -> Html Msg
viewTransportControls transport =
    let 

        transportToBool = 
            case transport of
                Car ->
                    True

                Walk ->
                    False

        isCarChosen = transportToBool 
        isWalkChosen = not transportToBool 
    in
    div [ class "info-controls-container"]
        [ button 
            [ classList 
                [ ( "info-control", True )
                , ( "transport", True )
                , ( "selected-transport", isCarChosen )
                ]
            , onClick (MapRoutesTransport Car)
            ]
            [ text "Car" ]
        , button
            [ classList
                [ ( "info-control", True )
                , ( "transport", True )
                , ( "selected-transport", isWalkChosen )
                ]
            , onClick (MapRoutesTransport Walk)
            ]
            [ text "Walk" ]
        ]


viewRouteResults : MH.MapRoutes -> Maybe RouteSummary -> Html Msg
viewRouteResults response selectedRouteId =
    case response of 
        MH.RoutesUnavailable ->
            p [ style "text-align" "center" ] [ text "No Routes available" ]

        MH.RoutesCalculating ->
            p [ style "text-align" "center" ] [ text "Calculating Routes..." ]

        MH.RoutesResponseErr err ->
            p [ style "text-align" "center" ] [ text err ]

        MH.RoutesResponse routesList ->
            div [ id "routes-results" ]
                (List.map (viewRouteSuggestion selectedRouteId) routesList )


viewRouteSuggestion : Maybe RouteSummary -> RouteSummary -> Html Msg
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
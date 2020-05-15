port module Page.MapView.RouteView exposing (Model, Msg, OutMsg(..), view, update, init, subscriptions)


import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, onMouseEnter, onMouseLeave, onFocus)
import Json.Decode exposing (Error, Value, decodeValue)

--import Page.Map exposing (RoutePoint)

import MapValues
    exposing
        ( Item
        , Position
        , RouteSummary
        , RoutePoint(..)
        , itemListDecoder
        , positionDecoder
        , positionEncoder
        , positionToString
        , routeSummaryListDecoder
        , routeParamEncoder
        )


port mapRoutesCalculate : Value -> Cmd msg
port mapRoutesResponse : (Value -> msg) -> Sub msg




-- SUBSCRIPTIONS


subscriptions : Sub Msg
subscriptions =
    Sub.batch
        [ mapRoutesResponse (decodeValue routeSummaryListDecoder >> MapRoutesResponse)
        ]



-- MODEL

init : RoutePoint -> RoutePoint -> ( Model, Cmd Msg, OutMsg )
init startPoint endPoint =
    ( { mapRoutes = RoutesUnavailable
      , selectedRoute = RouteNotSelected
      , transport = Car
      , startPoint = StartPointInvalid ""
      , endPoint = EndPointInvalid ""
      }
    , Cmd.none
    , NoOutMsg
    )


type alias Model = 
    { mapRoutes : MapRoutesResponse
    , selectedRoute : MapRoute
    , transport : Transport
    , startPoint : RoutePoint
    , endPoint : RoutePoint
    }



type MapRoute
    = RouteNotSelected
    | RouteSelected RouteSummary String



type MapRoutesResponse
    = RoutesUnavailable
    | RoutesCalculating
    | RoutesResponse (List RouteSummary)
    | RoutesResponseErr String


type Transport
    = Car
    | Walk




-- UPDATE



type Msg 
    = NoOp
    | MapRoutesResponse (Result Json.Decode.Error (List RouteSummary))
    | MapRoutesTransport Transport
    | MapRouteSelected MapRoute String
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
            ( { model | mapRoutes = RoutesResponse routesList }, Cmd.none, NoOutMsg )

        MapRoutesResponse (Err routesList) ->
            ( { model | mapRoutes = RoutesResponseErr "There is something wrong with the resonse" }
            , Cmd.none
            , NoOutMsg
            )

        MapRoutesTransport transport ->
            let
                newModel = { model | transport = transport }
            in
            ( newModel, mapRoutesHelper newModel, NoOutMsg )

        MapRouteSelected route id ->
            case route of 
                RouteSelected selectedRoute _ ->
                    ( { model | selectedRoute = route }, Cmd.none, NoOutMsg )

                RouteNotSelected ->
                    ( model, Cmd.none, NoOutMsg )

        PreviousPage address position ->
            ( model, Cmd.none, BackToDirections address position )



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



getMapRouteId : MapRoute -> String
getMapRouteId mapRoute =
    case mapRoute of 
        RouteNotSelected ->
            ""

        RouteSelected route id ->
            id


-- VIEW

view : Model -> Html Msg
view model =
    div [ class "info-container" ] 
        [ viewRouteViewControls model.endPoint
        , viewTransportControls model.transport
        , hr [ style "heigth" "1px", style "width" "100%" ] []
        , viewRouteResults model.mapRoutes ( getMapRouteId model.selectedRoute )
        ]


viewRouteViewControls : RoutePoint -> Html Msg
viewRouteViewControls routePoint =
    case routePoint of 
        EndPointValid address position ->
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


viewRouteResults : MapRoutesResponse -> String -> Html Msg
viewRouteResults response selectedRouteId =
    case response of 
        RoutesUnavailable ->
            p [ style "text-align" "center" ] [ text "No Routes available" ]

        RoutesCalculating ->
            p [ style "text-align" "center" ] [ text "Calculating Routes..." ]

        RoutesResponseErr err ->
            p [ style "text-align" "center" ] [ text err ]

        RoutesResponse routesList ->
            div [ id "routes-results" ]
                (List.map (viewRouteSuggestion selectedRouteId) routesList )


viewRouteSuggestion : String -> RouteSummary -> Html Msg
viewRouteSuggestion routeId routeSummary =
    let
        isSelected = 
            if routeId == routeSummary.id then
                True

            else
                False
    in
    div 
        [ class "route-suggestion" 
        , onClick (MapRouteSelected (RouteSelected routeSummary routeSummary.id) routeSummary.id)
        ] 
        [ p [] [ text routeSummary.duration ]
        , div 
            [ classList 
                [ ( "vertical-line", True )
                , ( "selected-route", isSelected )
                ] 
            ] 
            []
        , p [] [ text routeSummary.distance ]
        ]
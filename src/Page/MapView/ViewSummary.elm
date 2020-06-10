module Page.MapView.ViewSummary exposing (Model, Msg, OutMsg(..), view, update, init)


import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput, onMouseEnter, onMouseLeave, onFocus)


import Landmark exposing ( Landmark, Summary, SummaryType(..))
import MapValues exposing ( Position )



--port mapMarkerOpenSummary : (Int -> msg) -> Sub msg





--subscriptions : Sub Msg 
--subscriptions =
--    Sub.batch 
--        [ mapMarkerOpenSummary (\id -> InfoOpen (Just id))
--        ]


-- MODEL

init : SummaryType -> (Model, Cmd Msg, OutMsg)
init summary =
    (
    { landmarkSummary = summary
    }
    , Cmd.none
    , NoOutMsg
    )


type alias Model =
    { landmarkSummary : SummaryType
    }



-- UPDATE


type Msg
    = CloseViewSummary
    | GoToDirections String Position


type OutMsg 
    = NoOutMsg
    | CloseInfo 
    | OpenDirections String Position

 

update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of 
        CloseViewSummary ->
            ( model, Cmd.none, CloseInfo )

        GoToDirections  address position ->
            ( model, Cmd.none, OpenDirections address position )




-- VIEW

view : Model -> Html Msg
view model =
    case model.landmarkSummary of
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
viewInfoControls summary =
    div [ class "info-controls-container" ]
        [ button 
            [ classList
                [ ( "info-control", True )
                , ( "close", True )
                ]
            , onClick CloseViewSummary 
            ] 
            [ text "Close" ]
        , button
            [ class "info-control"
            , class "directions"
            --, onClick (GoToDirections landmark.title landmark.coordinates)
            , onClick (GoToDirections summary.title summary.coordinates)
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



module Page.Photos exposing (Model, Msg, view, init, update, subscriptions)

import Html exposing (Html, div, input, text, button, img, p, figure, figcaption)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick)
import File exposing (File)
import File.Select as Select
import Json.Decode as D
import Task
import TensorFlow as TF 



--SUBSCRIPTIONS
subscriptions : Sub Msg
subscriptions =
    Sub.batch
        [ Sub.map TFStatusMsg (TF.tfStatus (\statusMsg -> statusMsg) )
        , Sub.map TFPrediction (TF.tfPredictResult (D.decodeValue TF.predictionDecoder))
        ]


-- MODEL


type alias Model =
    { image : Maybe File
    , imageUrl : Maybe String
    , tfStatus : TF.TFStatus
    , prediction : TF.PredictionResult
    }


init : TF.TFStatus -> (Model, Cmd msg)
init tfStatus =
    let
        (cmds, newTFStatus) = case tfStatus of
                                TF.NotLoaded ->
                                    (TF.tfLoad (), TF.Loading)

                                _ -> 
                                    (Cmd.none, tfStatus)
    in
    ( { image = Nothing
      , imageUrl = Nothing
      , tfStatus = newTFStatus
      , prediction = TF.Empty
      }
    , Cmd.batch [ cmds ]
    )



-- UPDATE


type Msg
    = NoOp
    | Pick
    | GotImage File
    | GotPreview String
    | TFStatusMsg Bool
    | TFPrediction (Result D.Error TF.PredictionResult)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        Pick ->
            ( model
            , Select.file ["image/*"] GotImage
            )

        GotImage image ->
            ( { model | image = (Just image) } 
            , Task.perform GotPreview <| File.toUrl image
            )

        GotPreview url ->
            ( { model | imageUrl = (Just url) }
            , TF.tfImagePredict (url)
            )

        TFStatusMsg statusMsg ->
            case statusMsg of 
                True ->
                    ( { model | tfStatus = TF.Loaded }, Cmd.none )

                False ->
                    ( { model | tfStatus = TF.NotLoaded}, Cmd.none )


        TFPrediction (Ok result) ->
            ( { model | prediction = result }, Cmd.none )

        TFPrediction (Err err) ->
            ( { model | prediction = TF.PredictionErr "Error parsing the prediction" }, Cmd.none)


-- VIEW


view : Model -> Html Msg
view model =
    div [ id "photo-page"]
        [ div [ id "photo-results-wrapper" ] 
            [ viewUploadButton model.tfStatus
            , viewPreview model.imageUrl model.prediction
            ]
        ]


viewUploadButton : TF.TFStatus -> Html Msg 
viewUploadButton modelStatus =
    let 
        wrapper : List (Html.Attribute Msg) -> List (Html Msg) -> Html Msg
        wrapper listAttr listHtml = 
            div [ id "upload-button" ]
                [ button listAttr listHtml
                ]
    in
    case modelStatus of 
        TF.Loaded ->
            wrapper 
                [ class "btn-upload", onClick Pick ] 
                [ text "Upload Photo" ]

        TF.Loading ->
            wrapper 
                [ classList  
                    [ ("btn-upload", True)
                    , ("button-disabled", True)
                    ]
                , disabled True 
                ] 
                [ text "Loading model" ]

        TF.NotLoaded ->
            wrapper
                [ classList  
                    [ ("btn-upload", True) 
                    , ("button-disabled", True)
                    ]
                , disabled True 
                ]
                [ text "Model Not Loaded" ]


viewPreview : Maybe String -> TF.PredictionResult -> Html Msg
viewPreview maybeUrl result =
    case (maybeUrl, result) of
        (Just url, TF.Prediction data) ->
            figure [ id "photo-preview-wrapper" ]
                [ img 
                    [ id "photo-to-predict"
                    , src url
                    , alt "Selected Photo" 
                    ] 
                    []
                , figcaption [] 
                    [ p [] [ text (data.className) ]
                    , p [] 
                        [ text ("Accuracy: " ++ data.percentage)
                        ]
                    ]
                ]

        (Just url, TF.PredictionErr err) ->
            figure [ id "photo-preview-wrapper" ]
                [ img 
                    [ id "photo-to-predict"
                    , src url
                    , alt "Selected Photo" 
                    ] 
                    []
                , figcaption [] 
                    [ text err ]
                ]

        (_, _) ->
            text ""


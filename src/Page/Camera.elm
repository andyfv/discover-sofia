module Page.Camera exposing (Model, Msg, view, init, update, subscriptions)

import Html exposing (Html, div, video, p, text)
import Html.Attributes exposing (..)
import Html.Events
import Json.Decode as D
import TensorFlow as TF 



-- SUBSCRIPTIONS

subscriptions : Sub Msg
subscriptions =
    Sub.batch
        [ Sub.map TFStatusMsg (TF.tfStatus (\statusMsg -> statusMsg))
        , Sub.map TFPrediction (TF.tfPredictResult (D.decodeValue TF.predictionDecoder))
        ]


-- MODEL

type alias Model =
    { tfStatus : TF.TFStatus
    , prediction : TF.PredictionResult
    }


init : TF.TFStatus ->  (Model, Cmd msg)
init tfStatus =

    let 
        (cmds, newTFStatus) = case tfStatus of
                            TF.NotLoaded ->
                                (TF.tfLoad (), TF.Loading)

                            TF.Loaded -> 
                                (TF.tfVideoPredict (), tfStatus)

                            _ ->
                                (Cmd.none, tfStatus)

    in
    ( { tfStatus = newTFStatus
      , prediction = TF.Empty
      }
    , Cmd.batch [ cmds ]  
    )


-- UPDATE


type Msg
    = NoOp
    | TFStatusMsg Bool
    | TFPrediction (Result D.Error TF.PredictionResult)


update : Msg -> Model -> (Model, Cmd msg)
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)

        TFStatusMsg statusMsg ->
            case statusMsg of 
                True ->
                    ( { model | tfStatus = TF.Loaded }, TF.tfVideoPredict ())

                False ->
                    ( { model | tfStatus = TF.NotLoaded}, Cmd.none )

        TFPrediction (Ok result) ->
            ( { model | prediction = result }, Cmd.none )

        TFPrediction (Err err) ->
            ( { model | prediction = TF.PredictionErr "Error parsing the prediction" }, Cmd.none)


-- VIEW


view : Model -> Html Msg
view model  =
    div [ id "camera-page"]
        [ div [ id "camera-results-wrapper" ] 
            [ viewCamera
            , viewPrediction model.prediction
            , viewTFStatus model.tfStatus
            ]
        ]


viewCamera : Html Msg
viewCamera =
    video 
        [ id "video"
        , autoplay True
        , attribute "playsinline" "true"
        , attribute "muted" "true"
        ]
        []


viewPrediction : TF.PredictionResult -> Html Msg
viewPrediction result =
    case result of
        TF.Prediction data ->
            div [ style "text-align" "center"] 
                [ p [] [ text (data.className) ]
                , p [] 
                    [ text ("Accuracy: " ++ data.percentage)
                    ]
                ]

        TF.PredictionErr err ->
            div [ style "text-align" "center" ] 
                [ text err ]

        _ ->
            text ""

viewTFStatus : TF.TFStatus -> Html Msg
viewTFStatus tfStatus =
    case tfStatus of 
        TF.Loading ->
            div [ style "text-align" "center" ]
                [ text "Loading..."
                ]

        TF.NotLoaded ->
            div [ style "text-align" "center" ]
                [ text "Unable to load model"
                ]

        TF.Loaded ->
            div [ style "text-align" "center" ]
                [ text ""
                ]

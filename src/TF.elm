port module TF exposing 
    ( TFStatus(..)
    , PredictionResult(..)
    , tfLoad
    , tfStatus
    , tfImagePredict
    , tfVideoPredict
    , tfPredictResult
    , predictionDecoder
    )

import Json.Encode as Encode exposing (Value, object)
import Json.Decode as Decode exposing (Decoder, bool, int, string, list, float, decodeValue)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, requiredAt, hardcoded)



-- PORTS

-- Loading the TF libraries and model
port tfLoad : () -> Cmd msg
port tfStatus : ((Bool) -> msg) -> Sub msg

-- Predict Video Feed
port tfVideoPredict : () -> Cmd msg

-- Predict Image Feed
port tfImagePredict : (String) -> Cmd msg

-- Receive Prediction Results
port tfPredictResult : ((Value) -> msg) -> Sub msg



-- TYPES

type TFStatus
    = NotLoaded
    | Loaded
    | Loading 


type alias Data =
    { className : String
    , percentage : String 
    }


--type alias Err = String


type PredictionResult
    = Prediction Data
    | PredictionErr String
    | Empty



-- DECODERS


predictionDecoder =
    Decode.oneOf 
        [ Decode.map Prediction dataDecoder
        , Decode.map PredictionErr errorDecoder
        ]


dataDecoder : Decoder Data
dataDecoder =
    Decode.succeed Data
        |> requiredAt [ "result", "className" ] string
        |> requiredAt [ "result", "percentage" ] string


errorDecoder : Decoder String
errorDecoder =
    Decode.field "error" string


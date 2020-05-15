module MapValues exposing 
    ( Item
    , Address
    , Position
    , RouteSummary
    , RoutePoint(..)
    , itemListDecoder
    , itemDecoder
    , addressDecoder
    , positionDecoder
    , positionEncoder
    , positionToString
    , routeSummaryListDecoder
    , routeParamEncoder
    )

import Json.Encode as Encode exposing (Value, object)
import Json.Decode as Decode exposing (Decoder, bool, int, string, list, float, decodeValue)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, requiredAt, hardcoded)



type alias RouteSummary =
    { id : String
    , polyline : String
    , actions : List String
    , mode : String
    , distance : String
    , duration : String
    }


type alias RouteSummaryObject =
    { baseDuration : Int
    , duration : Int
    , length : Int
    }



type RoutePoint
    = StartPointValid String Position
    | StartPointInvalid String
    | EndPointValid String Position
    | EndPointInvalid String



type alias Item = 
    { address : Address
    , position : Position
    }


type alias Address = 
    { city : String
    , countryName : String
    , county : String
    , district : String
    , label : String
    , postalCode : String
    }

type alias Position = 
    { lat : Float
    , lng : Float
    }



-- DECODERS

itemListDecoder : Decoder (List Item)
itemListDecoder = 
    Decode.list itemDecoder


itemDecoder : Decoder Item 
itemDecoder =
    Decode.succeed Item
        |> required "address" addressDecoder
        |> required "position" positionDecoder 


addressDecoder : Decoder Address
addressDecoder =
    Decode.succeed Address
        |> optional "city" string ""
        |> optional "countryName" string ""
        |> optional "county" string ""
        |> optional "district" string ""
        |> optional "label" string ""
        |> optional "postalCode" string ""


positionDecoder : Decoder Position 
positionDecoder = 
    Decode.succeed Position
        |> required "lat" float
        |> required "lng" float


positionEncoder : Float -> Float -> Encode.Value
positionEncoder lat lng =
    Encode.object
        [ ("lat", Encode.float lat)
        , ("lng", Encode.float lng)
        ]


routeParamEncoder : Position -> Position -> String -> Encode.Value
routeParamEncoder origin destination transportMode = 
    Encode.object
        [ ("origin", positionEncoder origin.lat origin.lng)
        , ("destination", positionEncoder destination.lat destination.lng)
        , ("transportMode", Encode.string transportMode)
        ]


routeSummaryListDecoder : Decoder (List RouteSummary)
routeSummaryListDecoder =
    Decode.list routeSummaryDecoder



routeSummaryDecoder : Decoder RouteSummary
routeSummaryDecoder =
    Decode.succeed RouteSummary
        |> required "id" string
        |> required "polyline" string
        |> optional "actions" actionListDecoder []
        |> optional "mode" string ""
        |> optional "distance" string "Distance not available"
        |> optional "duration" string "Duration not available"


actionListDecoder : Decoder (List String)
actionListDecoder =
    Decode.list string


--routeSummaryObjectDecoder : Decoder RouteSummaryObject
--routeSummaryObjectDecoder =
--    Decode.succeed RouteSummaryObject
--        |> required "baseDuration" int
--        |> required "duration" int
--        |> required "length" int


-- HELPERS

positionToString : Position -> String
positionToString pos = 
    "( " ++ String.fromFloat pos.lat ++ ", " ++ String.fromFloat pos.lng ++ " )"
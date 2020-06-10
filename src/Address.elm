module Address exposing 
    ( Item
    , Address
    , Position
    , AddressResults(..)
    , itemListDecoder
    , itemDecoder
    , addressDecoder
    , positionDecoder
    , positionEncoder
    , positionToString
    , routeParamEncoder
    )

import Json.Encode as Encode exposing (Value, object)
import Json.Decode as Decode exposing (Decoder,  int, string, list, float, decodeValue)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, requiredAt, hardcoded)


type AddressResults
    = AddressResultsEmpty
    | AddressResultsLoading
    | AddressResultsLoaded (List Address)
    | AddressResultsErr String


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


-- HELPERS

positionToString : Position -> String
positionToString pos = 
    "( " ++ String.fromFloat pos.lat ++ ", " ++ String.fromFloat pos.lng ++ " )"
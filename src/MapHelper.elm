module MapHelper exposing 
    ( Address
    , FullAddress
    , Position
    , RouteSummary
    , RoutePoint(..)
    , MapRoutes(..)
    , Transport(..)
    , MapStatus(..)
    , AddressResults(..)
    , RedactedPoint(..)
    , itemListDecoder
    , itemDecoder
    , addressDecoder
    , positionDecoder
    , positionEncoder
    , positionToString
    , routeSummaryListDecoder
    , routeParamEncoder
    , routeSummaryEncoder
    )

import Json.Encode as Encode exposing (Value, object)
import Json.Decode as Decode exposing (Decoder, bool, int, string, list, float, decodeValue)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, requiredAt, hardcoded)



type RedactedPoint
    = StartPoint
    | EndPoint


type AddressResults
    = AddressResultsEmpty
    | AddressResultsLoading
    | AddressResultsLoaded (List Address)
    | AddressResultsErr String


type MapStatus
    = MapLoaded
    | MapLoading
    | MapLoadingFialed String


type Transport
    = Car
    | Walk


type MapRoutes
    = RoutesUnavailable
    | RoutesCalculating
    | RoutesResponse (List RouteSummary)
    | RoutesResponseErr String


type alias RouteSummary =
    { id : String
    , polyline : String
    , actions : List String
    , mode : String
    , distance : String
    , duration : String
    , departure : Position
    , arrival : Position
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



--type RoutePoint
--    = StartPointValid String Position
--    | StartPointInvalid String
--    | EndPointValid String Position
--    | EndPointInvalid String


type alias Address = 
    { address : FullAddress
    , position : Position
    }


type alias FullAddress = 
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

itemListDecoder : Decoder (List Address)
itemListDecoder = 
    Decode.list itemDecoder


itemDecoder : Decoder Address 
itemDecoder =
    Decode.succeed Address
        |> required "address" addressDecoder
        |> required "position" positionDecoder 


addressDecoder : Decoder FullAddress
addressDecoder =
    Decode.succeed FullAddress
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


positionEncoder : Position -> Encode.Value
positionEncoder position =
    Encode.object
        [ ("lat", Encode.float position.lat)
        , ("lng", Encode.float position.lng)
        ]


routeParamEncoder : Position -> Position -> String -> Encode.Value
routeParamEncoder origin destination transportMode = 
    Encode.object
        [ ("origin", positionEncoder origin)
        , ("destination", positionEncoder destination)
        , ("transportMode", Encode.string transportMode)
        ]


--routeSummaryResponseDecoder : Decoder 


routeSummaryListDecoder : Decoder (List RouteSummary)
routeSummaryListDecoder =
    Decode.list routeSummaryDecoder
    --Decode.succeed 



routeSummaryDecoder : Decoder RouteSummary
routeSummaryDecoder =
    Decode.succeed RouteSummary
        |> required "id" string
        |> required "polyline" string
        |> optional "actions" actionListDecoder []
        |> optional "mode" string ""
        |> optional "distance" string "Distance not available"
        |> optional "duration" string "Duration not available"
        |> required "departure" positionDecoder
        |> required "arrival" positionDecoder


actionListDecoder : Decoder (List String)
actionListDecoder =
    Decode.list string




routeSummaryEncoder : RouteSummary -> Encode.Value
routeSummaryEncoder routeSummary =
    Encode.object
        [ ( "polyline", Encode.string routeSummary.polyline )
        , ( "departure", positionEncoder routeSummary.departure)
        , ( "arrival", positionEncoder routeSummary.arrival)
        ]

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
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
    , Landmark
    , Summary
    , SummaryType(..)
    , itemListDecoder
    , itemDecoder
    , addressDecoder
    , positionDecoder
    , positionEncoder
    , positionToString
    , routeSummaryListDecoder
    , routeParamEncoder
    , routeSummaryEncoder
    , routeSummaryDecoder
    , summaryDecoder
    , landmarkListDecoder
    , markerInfoEncoder
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


type RoutePoint
    = StartPointValid String Position
    | StartPointInvalid String
    | EndPointValid String Position
    | EndPointInvalid String



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



type alias Landmark =
    { id : Int
    , wikiPage : String
    , wikiName : String
    }


type alias Summary =
    { id : Int
    , title : String
    , extract : String
    , thumbnail : String
    , originalImage : String
    , wikiUrl : String
    , coordinates : Position
    }


type SummaryType
    = SummaryValid Summary
    | SummaryInvalid



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


positionEncoder : Float -> Float -> Encode.Value
positionEncoder lat lng =
    Encode.object
        [ ("lat", Encode.float lat)
        , ("lng", Encode.float lng)
        ]


routeParamEncoder : Position -> Position -> String -> Encode.Value
routeParamEncoder origin destination transportMode = 
    Encode.object
        [ ("origin", (positionEncoder origin.lat origin.lng))
        , ("destination", (positionEncoder destination.lat destination.lng))
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
        |> requiredAt ["departure"] positionDecoder
        |> requiredAt ["arrival"] positionDecoder


actionListDecoder : Decoder (List String)
actionListDecoder =
    Decode.list string




routeSummaryEncoder : RouteSummary -> Encode.Value
routeSummaryEncoder routeSummary =
    Encode.object
        [ ( "polyline", Encode.string routeSummary.polyline )
        , ( "departure", (positionEncoder routeSummary.departure.lat routeSummary.departure.lng))
        , ( "arrival", (positionEncoder routeSummary.arrival.lat routeSummary.arrival.lng))
        ]



markerInfoEncoder : Summary -> Value
markerInfoEncoder summary =
    let 
        encodedCoord = positionEncoder summary.coordinates.lat summary.coordinates.lng
    in
    Encode.object
        [ ( "id", Encode.int summary.id )
        , ( "title", Encode.string summary.title)
        , ( "thumbnail", Encode.string summary.thumbnail )
        , ( "coords", encodedCoord ) 
        ]


-- DECODERS


-- Summary Decoder
summaryDecoder : Int -> Decoder Summary
summaryDecoder id =
    Decode.succeed Summary
        |> hardcoded id
        |> required "title" string
        |> required "extract" string
        |> optionalAt [ "thumbnail", "source" ] string ""
        |> optionalAt [ "originalimage", "source" ] string ""
        |> requiredAt [ "content_urls", "desktop", "page" ] string
        |> required "coordinates" coordinateDecoder 



coordinateDecoder : Decoder Position
coordinateDecoder =
    Decode.succeed Position
        |> required "lat" float
        |> required "lon" float



-- Landmark Decoder
landmarkListDecoder : Decoder (List Landmark)
landmarkListDecoder =
    Decode.list landmarkDecoder
        |> Decode.field "landmarks"


landmarkDecoder : Decoder Landmark
landmarkDecoder =
    Decode.succeed Landmark
        |> required "id" int
        |> required "wikipage" string
        |> required "wikiname" string




-- HELPERS

positionToString : Position -> String
positionToString pos = 
    "( " ++ String.fromFloat pos.lat ++ ", " ++ String.fromFloat pos.lng ++ " )"
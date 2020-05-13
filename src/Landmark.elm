module Landmark exposing 
    ( Landmark
    , Summary
    , SummaryType(..)
    , summaryDecoder
    , landmarkListDecoder
    , markerInfoEncoder
    )


import Json.Encode as Encode exposing (Value, object)
import Json.Decode as Decode exposing (Decoder, int, string, list, float)
import Json.Decode.Pipeline exposing (optional, optionalAt, required, requiredAt, hardcoded)

import Address exposing (Position, positionEncoder)

-- TYPES

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


-- HELPERS

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

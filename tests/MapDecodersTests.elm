module MapDecodersTests exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string, float)
import Test exposing (..)
import Json.Decode exposing (decodeString, decodeValue)
import Json.Encode as Encode

import MapHelper as MH


-- summaryDecoder Tests


testSummaryJSON =
    """
    { "title" : "National Palace of Culture"
    , "extract" : "The National Palace of Culture, located in Sofia, the capital of Bulgaria, is the largest, multifunctional conference and exhibition centre in south-eastern Europe. It was opened in 1981 in celebration of Bulgaria's 1300th anniversary."
    , "content_urls" :
        { "desktop" : 
            { "page" : "https://en.wikipedia.org/wiki/National_Palace_of_Culture"
            , "revisions" : "https://en.wikipedia.org/wiki/National_Palace_of_Culture?action=history"
            , "edit" : "https://en.wikipedia.org/wiki/National_Palace_of_Culture?action=edit"
            , "talk" : "https://en.wikipedia.org/wiki/Talk:National_Palace_of_Culture"
            }
            , "mobile" : 
                { "page" : "https://en.m.wikipedia.org/wiki/National_Palace_of_Culture"
                , "revisions" : "https://en.m.wikipedia.org/wiki/Special:History/National_Palace_of_Culture"
                , "edit" : "https://en.m.wikipedia.org/wiki/National_Palace_of_Culture?action=edit"
                , "talk" : "https://en.m.wikipedia.org/wiki/Talk:National_Palace_of_Culture"
                }
        }
    , "coordinates" : 
        { "lat" : 42.68472222
        , "lon" : 23.31888889
        }
    }
    """


thumbnailTest : Test
thumbnailTest =
    test "thumbnail defaults to empty string" <|
    \_ ->
        decodeString (MH.summaryDecoder 1) testSummaryJSON
        |> Result.map .thumbnail
        |> Expect.equal (Ok "")
    

originalImageTest : Test
originalImageTest = 
    test "originalImage defaults to empty string" <|
        \_ ->
            decodeString (MH.summaryDecoder 1) testSummaryJSON
            |> Result.map .originalImage
            |> Expect.equal (Ok "")




-- routeSummaryDecoder 


testRouteSummaryJSON =
    """
    {
          "id": "b8a36621-3ce3-408d-8d74-ea1748d0e49f",
          "type": "vehicle",
          "departure": {
            "place": {
              "type": "place",
              "location": {
                "lat": 42.6247944,
                "lng": 23.3764627
              },
              "originalLocation": {
                "lat": 42.6244899,
                "lng": 23.37644
              }
            }
          },
          "arrival": {
            "place": {
              "type": "place",
              "location": {
                "lat": 42.6896682,
                "lng": 23.327853
              },
              "originalLocation": {
                "lat": 42.6897222,
                "lng": 23.3277777
              }
            }
          },
          "summary": {
            "duration": 1252,
            "length": 11499,
            "baseDuration": 1062
          },
          "polyline": "BG0xzpxC-k5ysBvBqlBrnBrE_JnBzK7BUvM8BjwB8BnkBUvM8BnBgP_OwH3D4SjSwgBrYwM3IkS7LgejNsdrJkmB_Eo9B7BkNA4NAgFrJ8QT8GnB0F7B8G3DwWAoQAsdAgZA8QTgoB7BwqBnBgrCTwvBTkNAsTAgjBA8aAsOAwWAwWTwgBnBolD7Bw0BnB0UA0tBAkSUkSkD8Q0FkIwC4IkDgKsEkI4D4IsEkIsEsJgF4IgFkIgFkIgF4I0FwqB0ZgoBgZ4SoLsnB4X8Q0KoL8G4N4IkXsO0ZoQ0P0KsJoG8LwH4NkIwbgP0KoGkIgF4I0FkIgF8QoLoQ0K8Q0K4S8LsJoGsTwM0PgKkSoL4NsJoL8G0oBoawMkIoG4DgZ0PkSoL8VsOwMwHwMkIsTkNoLwHwMkIoBUkI0F4I0FoGkI0FgFoGgF8G0F4N8L4NkN4IsJkIsJ4IoLsJwM4IkNwH8L8G8LkIoQkIwRkI4SgKwWkI4SwC0FwC0FwMkcoGkNwHsOwC8G8BoGoB8GAgFTgFnB4D7BkDvCkDjDwCjD8BrEoBnGoB7VkDnLoBzFArEnBjD7BvCvCvC3D7BrEnB_ETzFA_EoBjI8B3IgUvb4NrTwC3DwCjDsE7G0F7G4IjNkc3mB4S7aoLzPwWnfwbjmB4S7a0PvWwCjDoG3IwCjD8BvC4IjNsO_T4IvMoG3IkNjSsEnG8GrJoLnQoV_doVze8LnQwMjSsJvMwMjSwHzK0FjIoLnQsJvM4N_T4I7LgU3coGjI8L7QoLnQ4I7L0PvWsJvM8BvCoLnQoQ3XwH_J4IvM4I7LkD_E4InLoLnQsEzF4NrToG3I0FjIwC3D4IvMkN3SoLzPwHzKoG3I4SnakSzZsOzUsT7aoG3IkDrEkD3DgUjcgUjcgU3coGjIkN3SkN3S0FjIkD_EkS_Y8L7Q8L7QwH_JsO_T0PnVkI7LsTjc8QjXwRrY4XjhBsO_TsTvb0KrOoV_doQjX4Sna8Q3XgZzjBwWnfoQvWgKrOgPnVsTnakNrTgF7G0K_Oge7pB0ZzjBgZ_iBwWnfgK3NgK3N8ajmBsJjN8avlB0P7VwRzZ8zB7nC4wBjkCoLnQwHzKgF7GsJvMgtB3_BkN3SgF7G0FjIwHnL4N3Sge7pBoLnQ4N3SsOnV0Uze8uBvjCgFvHgrC7qDkhB7uB0ZnkBoL7QwMvR4X3hBgFvH8B3DkDrJ4N7V4IvM4IjN0ZjmBkSrYoBnBwCjD8BjDsEzF4I7LjI7Q3I_OjXvlBvC3DvR7a3I3N3rB3kCnQjcsOna4N3XoL3S0F_J8Q3csO_YoQna3XjcnQ_TjD3DjD3DjhBzoBjD3DzUzZzU7aA_JoBnL4InlDkD_nB0UsE4I8LsiB84BoTmZ",
          "language": "en-us",
          "transport": {
            "mode": "car"
          }
        }
    """


modeTest : Test 
modeTest = 
    test "mode defaults to empty string" <|
        \_ -> 
            decodeString MH.routeSummaryDecoder testRouteSummaryJSON
            |> Result.map .mode
            |> Expect.equal (Ok "")


actionsTest : Test
actionsTest = 
    test "actions defaults to empty list" <|
        \_ -> 
            decodeString MH.routeSummaryDecoder testRouteSummaryJSON
            |> Result.map .actions
            |> Expect.equal (Ok [])



distanceTest : Test
distanceTest = 
    test "distance defaults to hardcoded string" <|
        \_ -> 
            decodeString MH.routeSummaryDecoder testRouteSummaryJSON
            |> Result.map .distance
            |> Expect.equal (Ok "Distance not available")



durationTest : Test 
durationTest =
    test "duration defaults to hardcoded string" <|
        \_ -> 
            decodeString MH.routeSummaryDecoder testRouteSummaryJSON
            |> Result.map .duration
            |> Expect.equal (Ok "Duration not available")




-- positionDecoder

positionDecoderOkTest : Test 
positionDecoderOkTest =
    fuzz2 float float "returns Ok Result if both values are floats"
        <| \lat lng ->
            [ ( "lat", Encode.float lat)
            , ( "lng", Encode.float lng)
            ]
            |> Encode.object
            |> decodeValue MH.positionDecoder
            |> Expect.ok



positionDecoderErrTest : Test 
positionDecoderErrTest =
    fuzz2 float string "returns Err Result if both values are not floats"
        <| \lat lng ->
            [ ( "lat", Encode.float lat)
            , ( "lng", Encode.string lng)
            ]
            |> Encode.object
            |> decodeValue MH.positionDecoder
            |> Expect.err

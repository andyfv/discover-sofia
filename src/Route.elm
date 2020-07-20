module Route exposing (Route(..), fromUrl, internalLink, absoluteLink, routeToString)

import Url exposing (Url)
import Url.Builder exposing (relative, absolute)
import Url.Parser as Parser exposing ((</>), Parser, oneOf, s, string)
import Browser.Navigation as Nav


type Route
    = Map
    | MapLandmark String
    | Camera
    | Photos 
    | NotFound


gitHubBase : String
gitHubBase =
    "discover-sofia-deployment"


-- Ucomment when deploying to Github/Gitlab
matchRoute : Parser (Route -> a) a
matchRoute =
    oneOf
        [ Parser.map Map Parser.top
        , Parser.map Map (s gitHubBase)
        , Parser.map MapLandmark (s gitHubBase </> s "map" </> string)
        , Parser.map Map (s gitHubBase </> s "map")
        , Parser.map Camera (s gitHubBase </> s "camera")
        , Parser.map Photos (s gitHubBase </> s "photos")
        ]




-- Comment when deploying to Github/Gitlab
--matchRoute : Parser (Route -> a) a
--matchRoute =
--    oneOf
--        [ Parser.map Map Parser.top
--        , Parser.map Map (s "map")
--        , Parser.map MapLandmark (s "map" </> string)
--        , Parser.map Camera (s "camera")
--        , Parser.map Photos (s "photos")
--        ]


fromUrl : Url -> Route
fromUrl url =
    case Parser.parse matchRoute url of
        Just route ->
            route

        Nothing ->
            NotFound


pushUrl : Route -> Nav.Key -> Cmd msg
pushUrl route navKey =
    routeToString route
        |> Nav.pushUrl navKey


routeToPieces : Route -> String
routeToPieces route =
    case route of 
        Map ->
            ""

        MapLandmark landmark -> 
            "/map/" ++ landmark

        Camera ->
            "/camera"

        Photos ->
            "/photos"

        NotFound -> 
            "/not-found"


routeToString : Route -> String
routeToString page =
    "#/" ++ (routeToPieces page)


-- LINKS

-- Uncomment when deploying to Github/Gitlab
internalLink : String -> String
internalLink path =
    absolute [ gitHubBase, String.dropLeft 1 path ] []


-- Comment when deploying to GitHub/GitLab
--internalLink : String -> String
--internalLink path =
--    absolute [ String.dropLeft 1 path ] []


absoluteLink : String -> String
absoluteLink path =
    absolute [ path ] []

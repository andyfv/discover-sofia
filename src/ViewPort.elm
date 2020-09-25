module Viewport exposing 
    ( view
    , viewNotFound
    , viewContent
    , Config
    )

import Browser 
import Html exposing (..)
import Html.Attributes exposing (..)
import Route exposing (Route(..), internalLink)
--import Article exposing (Article, ArticleCard, Image)


type alias Config msg =
    { route : Route
    , content : Html msg
    , header : Html msg
    }


view : Config msg -> Browser.Document msg
view ({ route, content, header }) = 
    { title = "Discover Sofia"
    , body = 
        header
        :: viewContent content route
        :: [ viewFooter ]
    }


viewNotFound : Html msg
viewNotFound =
    div [ id "page-not-found" ] 
        [ h1 [] [ text "Page Not Found"] 
        , a [ href (internalLink "/") ] [ text "Go to Home Page"]
        ]


{- CONTENT -}

viewContent : Html msg -> Route -> Html msg
viewContent content route =
        div [ id "content" ]
            [ content ]



{- FOOTER -}

viewFooter : Html msg
viewFooter = 
    div [ id "footer" ]
        [ ]
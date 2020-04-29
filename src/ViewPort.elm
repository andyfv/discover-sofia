module Viewport exposing 
    ( view
    , viewNotFound
    , viewContent
    --, viewCards
    --, viewCard
    --, viewCardImage
    --, viewCardInfo
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



--viewCards :  List ArticleCard -> Html msg
--viewCards articles =
--    div [ id "view-cards" ] ( List.map viewCard articles )


--viewCard : ArticleCard -> Html msg
--viewCard article =
--    a 
--        [ class "view-card"
--        , href article.href
--        ]
--        [ viewCardImage article.image
--        , viewCardInfo article
--        ]


--viewCardImage : Image -> Html msg
--viewCardImage image =
--    div [ class "card-image-wrapper" ]
--        [ img 
--            [ class "card-image" 
--            , src image.src
--            , alt image.description
--            ]
--            []
--        ]


--viewCardInfo : ArticleCard -> Html msg
--viewCardInfo article =
--    div [ class "card-info" ]
--        [ h3 [ class "card-info-header" ] [ text article.title ] 
--        , div [ class "card-info-date" ] [ text article.date ]
--        ]
    

--{- Article Template -}

--viewArticle : Article -> Html msg
--viewArticle article =
--    div [ class "article" ]
--        [ h1 [] [ text (Article.getTitle article) ]
--        , h3 [] [ text (Article.getSubtitle article) ]
--        , h5 [] [ text (Article.getDate article) ]
--        ]


--{- FOOTER -}

--viewFooter : Html msg
--viewFooter = 
--    div [ id "footer" ]
--        [ a [ href "https://github.com/andyfv/z-context" ] [ text "This site source code" ]
--        ]


{- FOOTER -}

viewFooter : Html msg
viewFooter = 
    div [ id "footer" ]
        [ ]
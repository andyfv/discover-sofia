module NavBar exposing (Model, Msg(..), init, update, view )

import Task
import Browser.Dom exposing (Viewport, getViewport)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Route exposing (Route(..), internalLink)

-- MODEL

type alias Model =
    { viewport : Viewport
    , isMenuOpen : Bool
    }


init : (Model, Cmd Msg)
init =
    (
    { viewport = 
        { scene = { width = toFloat 0, height = toFloat 0 }
        , viewport = 
            { x = toFloat 0
            , y = toFloat 0
            , width = toFloat 0
            , height = toFloat 0
            }
        }
    , isMenuOpen = False
    }
    , Cmd.batch [ Task.perform ViewportSize getViewport ]
    )



-- UPDATE

type Msg
    = MenuButtonClicked
    | CloseNavMenu

    -- VIEWPORT
    | ViewportSize Viewport
    | ViewportChanged



update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        MenuButtonClicked ->
            ({ model | isMenuOpen = not model.isMenuOpen }, Cmd.none)

        CloseNavMenu ->
            ({ model | isMenuOpen = False }, Cmd.none)

        ViewportChanged ->
            ( model
            , Cmd.batch [ Task.perform ViewportSize getViewport ]
            )

        ViewportSize vp ->
            ({ model | viewport = vp }, Cmd.none)



-- VIEW

view : Route -> Model -> Html Msg
view route ({ viewport, isMenuOpen }) =
    case isMenuOpen of
        True ->
            showMenu route
        False ->
            if viewport.viewport.width > 650 
            then viewDesktopHeader route
            else viewMobileHeader route


-- MOBILE

viewMobileHeader : Route -> Html Msg
viewMobileHeader route =
    div [ class "header" ]
        [ logo
        , viewMenuButton
        ]

viewMenuButton : Html Msg
viewMenuButton =
    button 
        [ id "menu-button"
        , onClick MenuButtonClicked 
        ]
        [ img [ src "/z-context/img/menu_icon_dark.svg", id "menu-icon" ] []
        ]


-- DESKTOP

viewDesktopHeader : Route -> Html msg
viewDesktopHeader route =
    div 
        [ classList 
            [ ("header-wrapper", True)
            --, ("header-bg-scroll", True)
            ] 
        ]
        [ viewNavBar route ]


viewHeader : Route -> Html msg
viewHeader route = 
    div [ class "header"] 
        [ viewNavBar route ]


logo : Html msg
logo =
    a [ href (internalLink "/")]
        [ node "picture" [ id "header-icon" ]
            [ source 
                [ media "(max-width: 750px)"
                , attribute "srcset" "/z-context/img/icon_mobile_dark.svg"
                ] 
                []
            , source 
                [ media "(min-width: 751px)"
                , attribute "srcset" "/z-context/img/blog_desktop_dark.svg"
                ] 
                []
            , img [ src "/z-context/img/icon_mobile_dark.svg", alt "logo"] []
            ] 
        ]


viewNavBar : Route -> Html msg
viewNavBar route =
    nav [ id "nav-links" ]
        [ ul []
            [ viewLink route Map "Map" "/"
            , viewLink route Camera "Camera" "/camera"
            , viewLink route Photos "Photos" "/photos"
            ]
        ]


-- COMMON

showMenu : Route -> Html Msg
showMenu route =
    div [ id "menu" ]
        [ viewNavBar route
        , viewCloseButton
        ]

viewCloseButton : Html Msg
viewCloseButton =
    button 
        [ id "close-button"
        , onClick CloseNavMenu
        ]
        [ text "Close"
        ]


viewLink : Route -> Route -> String -> String -> Html msg
viewLink currentTab targetTab name link =
    let 
        attrs =
            if currentTab == targetTab then
                [ class "selected-nav-link" ]
            else
                []
    in
    li [] 
        [ a 
            ( href (internalLink link) 
            :: attrs 
            )
            [ text name ] 
        ]



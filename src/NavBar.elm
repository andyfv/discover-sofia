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
    viewDesktopHeader route


-- DESKTOP

viewDesktopHeader : Route -> Html msg
viewDesktopHeader route =
    div 
        [ classList 
            [ ("header-wrapper", True)
            ] 
        ]
        [ viewNavBar route ]


viewHeader : Route -> Html msg
viewHeader route = 
    div [ class "header"] 
        [ viewNavBar route ]



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
    li ( attrs )
        [ a 
            [ href (internalLink link) 
            ]
            [ text name ] 
        ]



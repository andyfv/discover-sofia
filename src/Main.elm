module Main exposing (main)

import Html 
import Dict exposing (Dict)
import Url exposing (Url)
import Browser.Navigation as Nav
import Browser.Events exposing (onResize)
import Browser exposing (UrlRequest, Document)
--
import Route as Route exposing (Route)
import Viewport as Viewport exposing (view, viewNotFound)
import NavBar as NavBar
--
import Page.Map as Map
import Page.Camera as Camera
import Page.Photos as Photos


--port mapInitialized : (map) -> Sub msg



-- MAIN

main : Program () Model Msg
main =
    Browser.application
        { init = init 
        , view = view
        , update = update 
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


type alias Model =
    { route : Route
    , page : Page
    , navKey : Nav.Key
    , navBarModel : NavBar.Model
    , initiatedPages : Dict String Page
    }


type Page
    = NotFoundPage 
    | MapPage Map.Model
    | CameraPage Camera.Model
    | PhotosPage Photos.Model


type Msg
    = MapMsg Map.Msg
    | CameraMsg Camera.Msg
    | PhotosMsg Photos.Msg

    -- URL    
    | LinkClicked UrlRequest
    | UrlChanged Url

    -- HEADER
    | HeaderMsg NavBar.Msg



-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch 
        [ onResize (\_ _ -> NavBarMsg NavBar.ViewportChanged) 
        --, mapInitialized (\_ -> (MapMsg Map.MapInitialized))
        , Sub.map MapMsg Map.subscriptions
        ]



-- INIT

init : () -> Url -> Nav.Key -> (Model, Cmd Msg)
init flags url navKey =
    let 
        route = Route.fromUrl url
        (navBarModel, headerCmds) = NavBar.init
        model =
            { route = route
            , initiatedPages = Dict.empty
            , page = NotFoundPage
            , navKey = navKey
            , navBarModel = navBarModel
            }
    in
    initCurrentPage (model, Cmd.batch [ Cmd.map HeaderMsg headerCmds ])



initCurrentPage : (Model, Cmd Msg) -> (Model, Cmd Msg)
initCurrentPage (model, existingCmds) =
    let 
        (currentPage, mappedPageCmds) = 
            case model.route of
                Route.NotFound ->
                    ( NotFoundPage, Cmd.none )

                Route.Map ->
                    updateWith MapPage MapMsg Map.init

                Route.Camera ->
                    updateWith CameraPage CameraMsg Camera.init

                Route.Photos ->
                    updateWith PhotosPage PhotosMsg Photos.init

                Route.MapLandmark landmark ->
                    updateWith MapPage MapMsg Map.init

    in
    ( { model | page = currentPage
    , initiatedPages = Dict.insert (Route.routeToString model.route) currentPage model.initiatedPages }
    , Cmd.batch [ existingCmds, mappedPageCmds ]
    )



-- VIEW 

view : Model -> Document Msg
view model =
    let 
        viewPage route content =
            let 
                header = Html.map HeaderMsg (NavBar.view route model.navBarModel)
                config = 
                    { route = route
                    , content = content
                    , header = header
                    }
            in
            Viewport.view config
    in
    case model.page of
        NotFoundPage ->
            viewPage Route.NotFound Viewport.viewNotFound

        MapPage pageModel ->
            Html.map MapMsg (Map.view pageModel)
            |> viewPage Route.Map

        CameraPage pageModel ->
            Html.map CameraMsg (Camera.view pageModel)
            |> viewPage Route.Camera

        PhotosPage pageModel ->
            Html.map PhotosMsg (Photos.view pageModel)
            |> viewPage Route.Photos



-- UPDATE

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case ( model.page, msg ) of 
        ( MapPage pageModel, MapMsg subMsg ) ->
            (Map.update subMsg pageModel)
            |> updateWithModel MapPage MapMsg model


        -- HEADER
        ( _ , HeaderMsg subMsg) ->
            let 
                (navBarModel, subCmds) = NavBar.update subMsg model.navBarModel
            in
            ( { model | navBarModel = navBarModel }
            , Cmd.map HeaderMsg subCmds)



        -- URL UPDATES
        ( _ , UrlChanged url ) ->
            let 
                route = Route.fromUrl url
            in
                if Dict.member (Route.routeToString route) model.initiatedPages then
                    case Dict.get (Route.routeToString route) model.initiatedPages of
                        Just page ->
                            ({ model | page = page }, Cmd.none) 

                        Nothing ->
                            ({ model | page = NotFoundPage }, Cmd.none)

                else 
                    initCurrentPage 
                        ( { model | route = route }, Cmd.none)

        ( _ , LinkClicked urlRequest ) ->
            case urlRequest of 
                Browser.Internal url ->
                    ( model
                    , Nav.pushUrl model.navKey (Url.toString url)
                    )

                Browser.External url ->
                    ( model, Nav.load url )

        -- FALLBACK
        ( _, _ ) -> 
            ( model, Cmd.none )



updateWith : (subModel -> Page) -> (subMsg -> Msg) -> (subModel, Cmd subMsg) -> (Page, Cmd Msg)
updateWith toModel toMsg (subModel, subCmd) =
    (toModel subModel, Cmd.map toMsg subCmd)



updateWithModel : (subModel -> Page) -> (subMsg -> Msg) -> Model -> (subModel, Cmd subMsg) -> (Model, Cmd Msg)
updateWithModel toModel toMsg model (subModel, subCmd) =
    ( { model | page = toModel subModel }
    , Cmd.map toMsg subCmd
    )






module Main exposing (main)

import Html
import Url exposing (Url)
import Browser.Navigation as Nav
import Browser.Events exposing (onResize)
import Browser exposing (UrlRequest, Document)
--
import TensorFlow as TF
import Route as Route exposing (Route)
import Viewport as Viewport exposing (view, viewNotFound)
import NavBar as NavBar
--
import Page.Map as Map
import Page.Camera as Camera
import Page.Photos as Photos



-- MAIN

main : Program () Model Msg
main =
    Browser.application
        { init = init 
        , view = view
        , update = update 
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        , subscriptions = subscriptions
        }


type alias Model =
    { page : Page
    , route : Route
    , navKey : Nav.Key
    , navBarModel : NavBar.Model
    , tfStatus : TF.TFStatus
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
    | UrlChanged Url
    | LinkClicked UrlRequest

    -- HEADER
    | NavBarMsg NavBar.Msg

    -- 
    | TFStatusMsg Bool



-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch 
        [ onResize (\_ _ -> NavBarMsg NavBar.ViewportChanged)
        , Sub.map TFStatusMsg (TF.tfStatus (\statusMsg -> statusMsg) )
        , Sub.map MapMsg Map.subscriptions
        , Sub.map PhotosMsg Photos.subscriptions
        , Sub.map CameraMsg Camera.subscriptions
        ]



-- INIT

init : () -> Url -> Nav.Key -> (Model, Cmd Msg)
init flags url navKey =
    let 
        route = Route.fromUrl url
        (navBarModel, headerCmds) = NavBar.init
        model =
            { route = route
            , page = NotFoundPage
            , navKey = navKey
            , navBarModel = navBarModel
            , tfStatus = TF.NotLoaded
            }
    in
    initCurrentPage (model, Cmd.batch [ Cmd.map NavBarMsg headerCmds ])



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
                    updateWith CameraPage CameraMsg (Camera.init model.tfStatus)

                Route.Photos ->
                    updateWith PhotosPage PhotosMsg (Photos.init model.tfStatus)

                Route.MapLandmark landmark ->
                    updateWith MapPage MapMsg Map.init

    in
    ( { model | page = currentPage }
    , Cmd.batch [ existingCmds, mappedPageCmds ]
    )



-- VIEW 

view : Model -> Document Msg
view model =
    let 
        viewPage route content =
            let 
                header = Html.map NavBarMsg (NavBar.view route model.navBarModel)
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
            ( Map.update subMsg pageModel )
            |> updateWithModel MapPage MapMsg model

        ( PhotosPage pageModel, PhotosMsg subMsg ) ->
            ( Photos.update subMsg pageModel )
            |> updateWithModel PhotosPage PhotosMsg model

        ( CameraPage pageModel, CameraMsg subMsg ) ->
            ( Camera.update subMsg pageModel )
            |> updateWithModel CameraPage CameraMsg model


        -- NAVBAR
        ( _ , NavBarMsg subMsg) ->
            let 
                (navBarModel, subCmds) = NavBar.update subMsg model.navBarModel
            in
            ( { model | navBarModel = navBarModel }
            , Cmd.map NavBarMsg subCmds)



        -- TF Status 
        ( _ , TFStatusMsg statusMsg ) ->
            case statusMsg of 
                True ->
                    ( { model | tfStatus = TF.Loaded }, Cmd.none )

                False ->
                    ( { model | tfStatus = TF.NotLoaded}, Cmd.none )


        -- URL UPDATES
        ( _ , UrlChanged url ) ->
            let 
                route = Route.fromUrl url
            in
            initCurrentPage ({ model | route = route }, Cmd.none)

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


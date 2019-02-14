module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, height, property, width)
import Html.Events exposing (onClick, onMouseOver)
import Json.Encode as Encode
import Media exposing (..)
import Media.Capture as Capture
import Media.Source as Source
import Ports


type alias Model =
    { playback : Maybe Media.Playback, media : Maybe Key }


type Msg
    = Play
    | Pause
    | MediaCreated (Result Never Key)
    | StateUpdate State


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        MediaCreated m ->
            case m of
                Ok k ->
                    ( { model | media = Just k }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        Play ->
            case model.media of
                Nothing ->
                    ( model, Cmd.none )

                Just m ->
                    ( model, play m )

        Pause ->
            case model.media of
                Nothing ->
                    ( model, Cmd.none )

                Just m ->
                    ( model, pause m )

        StateUpdate s ->
            ( { model | playback = Just s.playback }, Cmd.none )


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.media of
        Nothing ->
            created MediaCreated

        Just _ ->
            state StateUpdate


init : () -> ( Model, Cmd msg )
init _ =
    ( { playback = Nothing, media = Nothing }
    , Media.create
        { source = Source.source <| Source.url "/oslo.mp4"
        , loop = False
        , muted = False
        , volume = Just 1.0
        , eventSubs = [ "timeupdate", "error", "durationchanged", "paused", "ended", "playing" ]
        }
    )


view : Model -> Html Msg
view model =
    let
        vid =
            case model.media of
                Nothing ->
                    []

                Just m ->
                    [ Media.video m [ width 720, height 480, class "video" ] ]
    in
    div [ class "main" ]
        [ div [ class "row" ] vid
        , div [ class "row controls" ]
            [ button [ onClick Play ] [ text "Play" ]
            , button [ onClick Pause ] [ text "Pause" ]
            ]
        ]

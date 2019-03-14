module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, height, property, width)
import Html.Events exposing (onClick)
import Json.Encode as Encode
import Media exposing (..)
import Media.Capture as Capture
import Media.Source as Source
import Ports


type alias Model =
    { playback : Maybe Media.Playback
    , media : Maybe Key
    , width : Int
    , height : Int
    , mediaError : Maybe Error
    }


type Msg
    = Play
    | Pause
    | MediaCreated (Result Error Key)
    | StateUpdate (Result Error State)


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        MediaCreated m ->
            case m of
                Ok k ->
                    ( { model | media = Just k }, Cmd.none )

                Err e ->
                    ( { model | mediaError = Just e }, Cmd.none )

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

        StateUpdate newState ->
            case newState of
                Ok s ->
                    ( { model | playback = Just s.playback, width = s.width, height = s.height }, Cmd.none )

                Err e ->
                    ( { model | mediaError = Just e }, Cmd.none )


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


request =
    { width = 1280, height = 1280 }


init : () -> ( Model, Cmd msg )
init _ =
    ( { playback = Nothing, media = Nothing, width = 0, height = 0, mediaError = Nothing }
    , Media.create
        { source = Source.capture <| Capture.Settings { audio = Nothing, video = Just [ Capture.width (Capture.range |> Capture.ideal request.width), Capture.height (Capture.range |> Capture.ideal request.height) ] }
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
                    [ Media.video m [ class "video" ] ]

        actualRes =
            if model.width /= 0 && model.height /= 0 then
                "Camera: " ++ String.fromInt model.width ++ "x" ++ String.fromInt model.height

            else
                "Requested: " ++ String.fromInt request.width ++ "x" ++ String.fromInt request.height

        errorRow =
            case model.mediaError of
                Just CaptureOverConstrained ->
                    div [ class "row error" ] [ text "Error: Cannot Capture With Those Settings" ]

                _ ->
                    div [] []
    in
    div [ class "main" ]
        [ div [ class "row" ] vid
        , div [ class "row" ]
            [ text actualRes
            ]
        , errorRow
        ]

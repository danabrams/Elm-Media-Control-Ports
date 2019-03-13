module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, property)
import Html.Events exposing (onClick)
import Json.Encode as Encode
import Media exposing (..)
import Media.Capture as Capture
import Media.Source as Source
import Ports


type alias Model =
    { playback : Maybe Media.Playback, media : Maybe Key, playing : Bool, alreadyPlayed : Bool, fastPlay : Bool, played : List Media.TimeRange }


type Msg
    = Play
    | Pause
    | MediaCreated (Result Error Key)
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
                    ( { model | alreadyPlayed = True }, play m )

        Pause ->
            case model.media of
                Nothing ->
                    ( model, Cmd.none )

                Just m ->
                    ( model, pause m )

        StateUpdate s ->
            ( { model | playback = Just s.playback, played = s.played }, Cmd.none )


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
    ( { playback = Nothing, media = Nothing, playing = False, alreadyPlayed = False, fastPlay = False, played = [] }
    , Media.create
        { source = Source.source <| Source.url "applause3.wav"
        , loop = True
        , muted = False
        , volume = Just 1.0
        , eventSubs = [ "timeupdate", "error", "durationchanged", "paused", "ended", "playing" ]
        }
    )


view : Model -> Html Msg
view model =
    let
        blinkClass =
            case model.playback of
                Just Playing ->
                    "blink"

                _ ->
                    "off"

        pauseClass =
            case model.playback of
                Just Playing ->
                    "blink"

                Just Paused ->
                    if model.alreadyPlayed then
                        "paused"

                    else
                        "off"

                _ ->
                    "off"
    in
    div [ class "main" ]
        [ div [ class "applause" ]
            [ span [ class blinkClass ] [ text "AP" ]
            , span [ class pauseClass ] [ text "P" ]
            , span [ class blinkClass ] [ text "L" ]
            , span [ class pauseClass ] [ text "AUSE" ]
            ]
        , button [ onClick Play ] [ text "Play" ]
        , button [ onClick Pause ] [ text "Pause" ]
        ]

module Media exposing
    ( create, state, State, Error, TimeRange
    , play, pause, seek, volume, muted, loop
    , video
    , Config, Key, Playback(..), created, encodeConfig, encodeKey, playbackRate
    )

{-|


# Media

@docs Id, create, state, State, Error, TimeRange


# Settings

@docs play, pause, seek, volume, muted, loop, autoplay


# Dom

@docs video

-}

import Html exposing (Attribute, Html, node)
import Html.Attributes exposing (property)
import Json.Decode as Decode
import Json.Encode as Encode
import Media.Capture exposing (..)
import Media.Source exposing (..)
import Ports exposing (..)
import Set exposing (Set)
import Task exposing (Task)


type Key
    = Key Decode.Value


encodeKey : Key -> Encode.Value
encodeKey (Key k) =
    k


{-| Create a new piece of media that you can then play or otherwise manipulate.
-}
create : Config -> Cmd msg
create config =
    toJs { ref = "This", command = "CREATE", data = encodeConfig config }


toKeyResult : { result : String, data : Decode.Value } -> Result Never Key
toKeyResult rs =
    case rs.result of
        _ ->
            Ok <| Key rs.data


created : (Result Never Key -> msg) -> Sub msg
created keyMsg =
    Sub.map keyMsg
        (mediaCreated toKeyResult)


{-| Change a setting on your media, like changing the Volume or Pausing it.
-}
changeSetting : Key -> Setting -> Cmd msg
changeSetting mediaId setting =
    toJs { ref = "This", command = "CHANGE_SETTING", data = encodeSetting mediaId setting }


getState : Key -> Cmd msg
getState (Key mediaId) =
    toJs { ref = "This", command = "GET_STATE", data = mediaId }


{-| A subscription to the current State of your media. NOTE: In final implementation, we'll probably need to make a "WithOptions" version for some advanced use-cases.
-}
state : (State -> msg) -> Sub msg
state msg =
    Sub.map msg (Ports.stateUpdate decodeState)


{-| Create a visible Html Dom node using your video Id.
-}
video : Key -> List (Html.Attribute msg) -> Html msg
video (Key mediaId) attrs =
    node "video-element" (property "media" mediaId :: attrs) []



-- SETTING FUNCTIONS


{-| Play your media.
-}
play : Key -> Cmd msg
play id =
    changeSetting id Play


{-| Pause your media.
-}
pause : Key -> Cmd msg
pause id =
    changeSetting id Pause


{-| Set the playback time to a new one
-}
seek : Key -> Float -> Cmd msg
seek id time =
    changeSetting id <| Seek time


{-| Change the source of your media. Use this to switch to a new song or video or other source.
-}
setSource : Key -> Source -> Cmd msg
setSource id src =
    changeSetting id <| SetSource src


{-| Set the volume of your media. Represented by a float 0.0 - 100.0
-}
volume : Key -> Float -> Cmd msg
volume id vol =
    changeSetting id <| Volume <| clamp 0.0 100.0 vol


{-| Should the media be muted or not
-}
muted : Key -> Bool -> Cmd msg
muted id value =
    changeSetting id <| Mute value


{-| Toggle whether the media loops at the end.
-}
loop : Key -> Bool -> Cmd msg
loop id value =
    changeSetting id <| Loop value


playbackRate : Key -> Float -> Cmd msg
playbackRate id value =
    changeSetting id <| PlaybackRate value


{-| This is the key type. It stores a reference to your media that you pass to the Tasks in this package. You need to create it before you can do anything.
-}
type Id
    = Id Int


{-| A work in progress enumeration of all the possible errors
-}
type Error
    = InvalidSetting
    | InvalidSource
    | SettingAgainstBrowserPolicy
    | NetworkConnectivity


{-| An example of what a State record might look like
-}
type alias State =
    { currentTime : Float
    , duration : Float
    , playback : Playback
    , source : String
    , loop : Bool
    , muted : Bool
    , volume : Float
    , buffered : List TimeRange
    , seekable : List TimeRange
    , played : List TimeRange
    , playbackRate : Float
    , readyState : ReadyState
    , networkState : NetworkState
    , width : Int
    , height : Int
    }


{-| A time range is a range of time withing the media, for instance, 0:03 to 0:15.
-}
type alias TimeRange =
    { start : Float, end : Float }


{-| Current status of media playback
-}
type Playback
    = Playing
    | Paused
    | Ended
    | Loading
    | Buffering
    | PlaybackError String


type ReadyState
    = NoData
    | Metadata
    | CurrentData
    | FutureData
    | EnoughData


type NetworkState
    = Empty
    | Idle
    | DataLoading
    | NoSource


decodeState : PortState -> State
decodeState prt =
    let
        pback =
            case prt.playback of
                "PLAYING" ->
                    Playing

                "PAUSED" ->
                    Paused

                "ENDED" ->
                    Ended

                "LOADING" ->
                    Loading

                "BUFFERING" ->
                    Buffering

                _ ->
                    PlaybackError prt.playback

        network =
            case prt.networkState of
                0 ->
                    Empty

                1 ->
                    Idle

                2 ->
                    DataLoading

                _ ->
                    NoSource

        ready =
            case prt.readyState of
                0 ->
                    NoData

                1 ->
                    Metadata

                2 ->
                    CurrentData

                3 ->
                    FutureData

                _ ->
                    EnoughData
    in
    { currentTime = prt.currentTime
    , duration = prt.duration
    , playback = pback
    , source = prt.source
    , loop = prt.loop
    , muted = prt.muted
    , volume = prt.volume
    , buffered = prt.buffered
    , seekable = prt.seekable
    , played = prt.played
    , playbackRate = prt.playbackRate
    , networkState = network
    , readyState = ready
    , width = prt.width
    , height = prt.height
    }



{- This is how you configure your media when you create it. It takes a list of sources because best practice to include fallback versions using different codecs. NOTE: You would probably also define things like TextTracks (subtitles) in here. -}


type alias Config =
    { source : Source
    , loop : Bool
    , muted : Bool
    , volume : Maybe Float
    , eventSubs : List String
    }


encodeConfig : Config -> Encode.Value
encodeConfig config =
    Encode.object <|
        [ ( "source", encodeSource config.source )
        , ( "loop", Encode.bool config.loop )
        , ( "muted", Encode.bool config.muted )
        , ( "volume", Encode.float <| Maybe.withDefault -1.0 config.volume )
        , ( "eventSubs", Encode.list Encode.string config.eventSubs )
        ]


type alias TextTrack =
    { track : String }


type alias TextTrackSrc =
    String


{-| These are the settings you can (attempt to) change the state of media. NOTE: This is a simple set, there are some more dealing with things like TextTracks, but I think these give the idea.
-}
type Setting
    = Play
    | Pause
    | Seek Float
    | SetSource Source
    | Mute Bool
    | Volume Float
    | Loop Bool
    | HideTextTrack TextTrack
    | DisableTextTrack TextTrack
    | ShowTextTrack TextTrack
    | PlaybackRate Float


encodeSetting : Key -> Setting -> Encode.Value
encodeSetting (Key mediaKey) stt =
    let
        encd s v =
            Encode.object
                [ ( "mediaObj", mediaKey )
                , ( "setting", Encode.string s )
                , ( "value", v )
                ]
    in
    case stt of
        Play ->
            encd "PLAY" Encode.null

        Pause ->
            encd "PAUSE" Encode.null

        Seek f ->
            encd "currentTime" <| Encode.float f

        Mute b ->
            encd "muted" <| Encode.bool b

        Volume f ->
            encd "volume" <| Encode.float f

        Loop b ->
            encd "loop" <| Encode.bool b

        PlaybackRate f ->
            encd "playbackRate" <| Encode.float f

        _ ->
            encd "_notImplemented" <| Encode.null

module Media.Source exposing
    ( Source(..), source, url, codec, fallbacks
    , Mime(..), Url, aac, capture, customMime, encodeMime, encodeSource, encodeUrl, mime, mp3, mp4, oggAudio, oggVideo, wav
    )

{-|


# Source

@docs Source, source, url, mimeType, codec, fallbacks

-}

import Json.Encode as Encode
import Media.Capture as Capture exposing (encodeCaptureSettings)
import Set exposing (Set)


{-| Where is the media file you want to play. In the future, we can add other source types, like webcams, or webRTC video chats, etc.
-}
type Source
    = SourceUrl Url
    | Fallbacks (List Source)
    | MediaCapture Capture.Settings


encodeSource : Source -> Encode.Value
encodeSource srce =
    case srce of
        SourceUrl ur ->
            encodeUrl ur

        Fallbacks urs ->
            Encode.object [ ( "urls", Encode.list encodeSource urs ) ]

        MediaCapture capSettings ->
            Encode.object [ ( "captureStream", encodeCaptureSettings capSettings ) ]


capture : Capture.Settings -> Source
capture setts =
    MediaCapture setts


type alias Url =
    { url : String, mime : Maybe Mime, codecs : Set String }


encodeUrl : Url -> Encode.Value
encodeUrl ur =
    let
        u =
            [ ( "url", Encode.string ur.url ) ]

        m =
            case ur.mime of
                Nothing ->
                    []

                Just mm ->
                    [ ( "type", encodeMime mm ) ]

        c =
            case ( ur.mime, ur.codecs ) of
                ( Nothing, _ ) ->
                    []

                ( _, cs ) ->
                    if Set.isEmpty cs then
                        []

                    else
                        [ ( "codecs", Encode.set Encode.string cs ) ]
    in
    Encode.object <| u ++ m ++ c


type Mime
    = Mp4
    | Mp3
    | OggAudio
    | OggVideo
    | Aac
    | Wav
    | Mime String


encodeMime : Mime -> Encode.Value
encodeMime mim =
    case mim of
        Mp4 ->
            Encode.string "video/mp4"

        Mp3 ->
            Encode.string "audio/mpeg"

        OggAudio ->
            Encode.string "audio/ogg"

        OggVideo ->
            Encode.string "video/ogg"

        Aac ->
            Encode.string "audio/aac"

        Wav ->
            Encode.string "audio/wav"

        Mime str ->
            Encode.string str


{-| -}
source : Url -> Source
source =
    SourceUrl


{-| Create a source from a url string
-}
url : String -> Url
url uri =
    { url = uri, mime = Nothing, codecs = Set.empty }


mime : Mime -> Url -> Url
mime m ur =
    { ur | mime = Just m }


{-| -}
mp4 : Url -> Url
mp4 =
    mime Mp4


{-| -}
mp3 : Url -> Url
mp3 ur =
    ur |> mime Mp3 |> codec "mp3"


{-| -}
wav : Url -> Url
wav ur =
    ur |> mime Wav |> codec "1"


{-| -}
oggAudio : Url -> Url
oggAudio =
    mime OggAudio


{-| -}
oggVideo : Url -> Url
oggVideo =
    mime OggVideo


{-| -}
aac : Url -> Url
aac =
    mime Aac


{-| -}
customMime : String -> Url -> Url
customMime m =
    mime <| Mime m


{-| Specify a codec for your source. Adds onto any codecs already specified. Only works if you've also specified a mimeTyp.
-}
codec : String -> Url -> Url
codec cdc ur =
    { ur | codecs = Set.insert cdc ur.codecs }


{-| Specify a list of sources. This is really useful if you want to provide backup urls using different types of media for different browsers.
For instance, AAC is usually preferable to MP3, but it's not supported on every browser. You could do this:

    fallbacks [ source (url "myfile.aac" |> aac), source (url "myfile.mp3" |> mp3) ]

I highly recommend adding mime type and codec information if you have it when using fallbacks.
An older browser, for instance, may only suppoer "Baseline" profile MP4s, but you probaby want to provide more efficient "High" profile files for most browsers, like so:

    fallbacks
        [ source (url "myvideo.mp4" |> mp4 |> codec "avc1.64002a")
        , source (url "myvideo.mp4" |> mp4 |> codec "avc1.42E00c")
        ]

I know the codecs are confusing, you can use an application like [MediaInfo](https://mediaarea.net/en/MediaInfo) to figure out what a given file is.
This lets the package figure out whether a given source can be played without downloading any of it.

-}
fallbacks : List Source -> Source
fallbacks sources =
    Fallbacks sources

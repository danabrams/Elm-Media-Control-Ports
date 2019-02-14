module Media.Capture exposing (Settings(..), aspectRatio, autoGain, back, captureVolume, encodeCaptureSettings, exact, frameRate, front, height, ideal, latency, max, min, noiseCancel, range, sampleRate, sampleSize, width)

import Json.Encode as Encode


type Settings
    = Settings
        { audio : Maybe (List AudioCaptureSetting)
        , video : Maybe (List VideoCaptureSetting)
        }


encodeCaptureSettings : Settings -> Encode.Value
encodeCaptureSettings setts =
    case setts of
        Settings css ->
            let
                audSets =
                    case css.audio of
                        Just [] ->
                            [ ( "audio", Encode.bool True ) ]

                        Just audioSets ->
                            [ ( "audio", Encode.object <| List.map encodeAudioSetting audioSets ) ]

                        Nothing ->
                            [ ( "audio", Encode.bool False ) ]

                vidSets =
                    case css.video of
                        Just [] ->
                            [ ( "video", Encode.bool True ) ]

                        Just videoSets ->
                            [ ( "video", Encode.object <| List.map encodeVideoSetting videoSets ) ]

                        Nothing ->
                            [ ( "video", Encode.bool False ) ]
            in
            Encode.object <| audSets ++ vidSets


type VideoCaptureSetting
    = Width ConstraintInt
    | Height ConstraintInt
    | Front
    | Back
    | AspectRatio Float
    | FrameRate ConstraintInt


encodeVideoSetting : VideoCaptureSetting -> ( String, Encode.Value )
encodeVideoSetting vcs =
    case vcs of
        Width cstr ->
            ( "width", encodeConstraint cstr )

        Height cstr ->
            ( "height", encodeConstraint cstr )

        Front ->
            ( "facingMode", Encode.string "user" )

        Back ->
            ( "facingMode", Encode.string "environment" )

        AspectRatio f ->
            ( "aspectRatio", Encode.float f )

        FrameRate cstr ->
            ( "frameRate", encodeConstraint cstr )


type AudioCaptureSetting
    = AutoGain Bool
    | CaptureVolume Float
    | NoiseCancel Bool
    | EchoCancel Bool
    | Latency ConstraintInt
    | SampleRate ConstraintInt
    | SampleSize ConstraintInt


encodeAudioSetting : AudioCaptureSetting -> ( String, Encode.Value )
encodeAudioSetting acs =
    case acs of
        AutoGain b ->
            ( "autoGainControl", Encode.bool b )

        CaptureVolume f ->
            ( "volume", Encode.float f )

        NoiseCancel b ->
            ( "noiseSuppression", Encode.bool b )

        EchoCancel b ->
            ( "echoCancellation", Encode.bool b )

        Latency cns ->
            ( "latency", encodeConstraint cns )

        SampleRate cns ->
            ( "sampleRate", encodeConstraint cns )

        SampleSize cns ->
            ( "sampleSize", encodeConstraint cns )


type ConstraintInt
    = Exact Int
    | Range ConstraintRange


encodeConstraint : ConstraintInt -> Encode.Value
encodeConstraint constr =
    case constr of
        Exact v ->
            Encode.object [ ( "exact", Encode.int v ) ]

        Range crs ->
            encodeConstraintRange crs


type alias ConstraintRange =
    { ideal : Maybe Int, min : Maybe Int, max : Maybe Int }


encodeConstraintRange : ConstraintRange -> Encode.Value
encodeConstraintRange crs =
    let
        idl =
            case crs.ideal of
                Nothing ->
                    []

                Just i ->
                    [ ( "ideal", Encode.int i ) ]

        mn =
            case crs.min of
                Nothing ->
                    []

                Just m ->
                    [ ( "min", Encode.int m ) ]

        mx =
            case crs.max of
                Nothing ->
                    []

                Just m ->
                    [ ( "max", Encode.int m ) ]
    in
    Encode.object <| idl ++ mn ++ mx


{-| Set an exact value for a Caputre Options
-}
exact : Int -> ConstraintInt
exact val =
    Exact val


ideal : Int -> ConstraintInt -> ConstraintInt
ideal val inp =
    case inp of
        Exact _ ->
            Range { ideal = Just val, min = Nothing, max = Nothing }

        Range rng ->
            Range { rng | ideal = Just val }


min : Int -> ConstraintInt -> ConstraintInt
min val inp =
    case inp of
        Exact _ ->
            Range { ideal = Nothing, min = Just val, max = Nothing }

        Range rng ->
            Range { rng | min = Just val }


range : ConstraintInt
range =
    Range { ideal = Nothing, min = Nothing, max = Nothing }


max : Int -> ConstraintInt -> ConstraintInt
max val inp =
    case inp of
        Exact _ ->
            Range { ideal = Nothing, min = Nothing, max = Just val }

        Range rng ->
            Range { rng | max = Just val }


width : ConstraintInt -> VideoCaptureSetting
width =
    Width


height : ConstraintInt -> VideoCaptureSetting
height =
    Height


front : VideoCaptureSetting
front =
    Front


back : VideoCaptureSetting
back =
    Back


frameRate : ConstraintInt -> VideoCaptureSetting
frameRate =
    FrameRate


aspectRatio : Float -> VideoCaptureSetting
aspectRatio =
    AspectRatio


autoGain : Bool -> AudioCaptureSetting
autoGain =
    AutoGain


noiseCancel : Bool -> AudioCaptureSetting
noiseCancel =
    NoiseCancel


captureVolume : Float -> AudioCaptureSetting
captureVolume =
    CaptureVolume


sampleSize : ConstraintInt -> AudioCaptureSetting
sampleSize =
    SampleSize


sampleRate : ConstraintInt -> AudioCaptureSetting
sampleRate =
    SampleRate


latency : ConstraintInt -> AudioCaptureSetting
latency =
    Latency

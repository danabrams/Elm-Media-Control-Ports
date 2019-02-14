port module Ports exposing (OutboundMsg, PortState, analyserCreated, analyserTimeData, audioContextCreated, bufferCreated, mediaCreated, stateUpdate, toJs)

import Array exposing (Array)
import Json.Decode as Decode
import Json.Encode as Encode


type alias OutboundMsg =
    { ref : String
    , command : String
    , data : Encode.Value
    }


port toJs : OutboundMsg -> Cmd msg


port mediaCreated : ({ result : String, data : Decode.Value } -> msg) -> Sub msg


port stateUpdate : (PortState -> msg) -> Sub msg


port audioContextCreated : ({ result : String, data : Decode.Value } -> msg) -> Sub msg


port bufferCreated : ({ result : String, data : Decode.Value } -> msg) -> Sub msg


port analyserCreated : ({ result : String, data : Decode.Value } -> msg) -> Sub msg


port analyserTimeData : (List Int -> msg) -> Sub msg


type alias PortState =
    { currentTime : Float
    , duration : Float
    , playback : String
    , source : String
    , loop : Bool
    , muted : Bool
    , volume : Float
    , buffered : List TimeRange
    , seekable : List TimeRange
    , played : List TimeRange
    , playbackRate : Float
    , networkState : Int
    , readyState : Int
    , width : Int
    , height : Int
    }


type alias TimeRange =
    { start : Float, end : Float }

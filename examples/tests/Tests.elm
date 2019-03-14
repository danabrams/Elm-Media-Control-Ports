module Tests exposing (errorDecoding)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Media
import Test exposing (..)


errorDecoding : Test
errorDecoding =
    describe "Error Decoding"
        [ test "'Invalid constraint' -> CaptureOverConstrained" <|
            \_ ->
                Expect.equal (Media.decodeError "Invalid constraint") Media.CaptureOverConstrained
        , fuzz (string) "'Random String' -> Other \"Random String\"" <|
            \randomString ->
                Expect.equal (Media.decodeError randomString) (Media.Other randomString)

        ]

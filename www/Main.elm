port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Debug exposing (log)


port openEditor : String -> Cmd msg

port editorContents : () -> Cmd msg


main =
    Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


type alias Model =
    { script : String
    , output : Result Http.Error String
    }


type Msg
    = UpdateScript String
    | RunScript
    | ScriptResult (Result Http.Error String)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        UpdateScript script ->
            ({ model | script = script }, runScript script)

        RunScript ->
            (model, editorContents ())

        ScriptResult output ->
            ({ model | output = output}, Cmd.none)


view : Model -> Html Msg
view model =
    div [class "container"] [
        div [class "buttons"] [
            div [class "button", onClick RunScript] [ text "Run" ]
        ],
        div [class "editorContainer"] [
            div [id "editorID", class "editor"] []
        ],
        div [class "outputContainer"] [
            outputView model
        ]
    ]


errorPage : String -> List (String, String) -> Html Msg
errorPage name suffixes =
    div [id "outputID", class "output"] [
        h1 [] [text "HTTP Error"],
        dl []
            <| List.concat
                <| List.map (\(k, v) -> [dt [] [text k], dd [] [text v]])
                <| ("Type", name) :: suffixes
    ]


outputView : Model -> Html Msg
outputView model =
    let
        keyValues s =
            Decode.decodeString (Decode.keyValuePairs Decode.string) s
    in
        case model.output of
            Ok s ->
                case keyValues s of
                    Ok lst ->
                        div [id "outputID", class "output"] [
                            dl [] <| List.concatMap (\(k, v) -> [dt [] [text k], dd [] [text  v]]) lst
                        ]

                    Err e ->
                        div [id "outputID", class "output"] [ text e ]

            Err e ->
                viewHttpError e


viewHttpError : Http.Error -> Html Msg
viewHttpError err =
    let
        responseToString response =
            Encode.encode 4 <|
                Encode.object [
                    ("url", Encode.string response.url),
                    ("status", Encode.object [
                        ("code", Encode.int response.status.code),
                        ("message", Encode.string response.status.message)
                    ]),
                    ("body", Encode.string response.body)
                ]
    in
        case err of
            Http.BadUrl u ->
                errorPage "Bad URL" [("URL", u)]

            Http.Timeout ->
                errorPage "Timeout" []

            Http.NetworkError ->
                errorPage "Network Error" []

            Http.BadStatus response ->
                errorPage "Bad Status" [("Response", responseToString response)]

            Http.BadPayload reason response ->
                errorPage "Bad Payload" [("Reason", reason), ("Response", responseToString response)]




port contents : (String -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions model =
    contents UpdateScript


init : (Model, Cmd Msg)
init =
    ({script = "", output = Result.Ok "" }, openEditor "")


runScript : String -> Cmd Msg
runScript script =
    let
        url =
--            "https://boiling-stream-77584.herokuapp.com/process"
            "http://localhost:5000/api/process"

        put url body =
            Http.request
                { method = "PUT"
                , headers = []
                , url = log ("URL: " ++ url) url
                , body = body
                , expect = Http.expectString
                , timeout = Nothing
                , withCredentials = False
                }

        payload =
            Encode.encode 4 <|
                Encode.object [
                    ("type", Encode.string "JavaScript"),
                    ("script", Encode.string script)
                ]
    in
        Http.send ScriptResult <|
            put url (Http.stringBody "text/plain" payload)

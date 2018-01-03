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
    , output : Result ErrorModel SuccessModel
    }


type alias ErrorModel =
    { title : String
    , properties: List (String, String)
    }


type alias SuccessModel =
    { result : List (String, String)
    , currentTab : Maybe String
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
            ({ model | output = parseScriptResult output}, Cmd.none)


parseScriptResult : Result Http.Error String -> Result ErrorModel SuccessModel
parseScriptResult output =
    let
        keyValues =
            Decode.decodeString (Decode.keyValuePairs Decode.string)

        parseHttpError : Http.Error -> ErrorModel
        parseHttpError err =
            let
                httpErrorPage t properties =
                    ErrorModel "HTTP Error" <| ("Type", t) :: properties

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
                        httpErrorPage "Bad URL" [("URL", u)]

                    Http.Timeout ->
                        httpErrorPage "Timeout" []

                    Http.NetworkError ->
                        httpErrorPage "Network Error" []

                    Http.BadStatus response ->
                        httpErrorPage "Bad Status" [("Response", responseToString response)]

                    Http.BadPayload reason response ->
                        httpErrorPage "Bad Payload" [("Reason", reason), ("Response", responseToString response)]

    in
        case output of
            Ok s ->
                keyValues s
                    |> Result.mapError (\e -> ErrorModel "HTTP Error" [("Type", "JSON Parsing Error"), ("Message", e)])
                    |> Result.map (\s -> SuccessModel s Nothing)

            Err e ->
                Err <| parseHttpError e



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


outputView : Model -> Html Msg
outputView model =
    case model.output of
        Ok lst ->
            successPage lst

        Err e ->
            errorPage e


successPage : SuccessModel -> Html Msg
successPage model =
            div [id "outputID", class "output"] [
                dl [] <| List.concatMap (\(k, v) -> [dt [] [text k], dd [] [text  v]]) model.result
            ]


errorPage : ErrorModel -> Html Msg
errorPage model =
    div [id "outputID", class "output"] [
        h1 [] [text model.title],
        dl []
            <| List.concat
                <| List.map (\(k, v) -> [dt [] [text k], dd [] [text v]])
                <| model.properties
    ]


port contents : (String -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions model =
    contents UpdateScript


init : (Model, Cmd Msg)
init =
    (Model "" (Result.Ok (SuccessModel [] Nothing)), openEditor "")


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

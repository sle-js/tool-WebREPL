port module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Task
import Navigation
import Window

import Debug exposing (log)


port openEditor : String -> Cmd msg

port editorContents : () -> Cmd msg

port editorHeight : Int -> Cmd msg


main =
    Navigation.program (\l -> LocationChanged l)
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


type alias Model =
    { loc : Navigation.Location
    , script : String
    , height: Int
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
    | SelectOutput String
    | WindowResize Int
    | LocationChanged Navigation.Location


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        UpdateScript script ->
            ({ model | script = script }, runScript model.loc.href script)

        RunScript ->
            (model, editorContents ())

        ScriptResult output ->
            ({ model | output = parseScriptResult output }, Cmd.none)

        SelectOutput tabName ->
            ({ model | output = Result.map (\s -> {s | currentTab = Just tabName }) model.output }, Cmd.none)

        WindowResize height ->
            ({ model | height = height }, editorHeight (height - 40))

        LocationChanged l ->
            (model, Cmd.none)


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
                    |> Result.map (\s -> SuccessModel s (Just "stdout"))

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
            successPage model.height lst

        Err e ->
            errorPage model.height e


successPage : Int -> SuccessModel -> Html Msg
successPage height model =
    let
        currentTab =
            Maybe.withDefault "" model.currentTab

        content s =
            List.map (\t -> p [] [text t]) (String.split "\n" s)
    in
        div [id "outputID", class "output", style [("height", (toString (height - 40)) ++ "px")]]
            <| (div [class "tabs"] (List.map (\(k, v) -> div [class (if k == currentTab then "tab active" else "tab"), onClick (SelectOutput k)] [text k]) model.result))
                    :: (List.map (\(k, v) -> div [class "tabcontent", style [("height", (toString (height - 99) ++ "px"))]] (content v)) (List.filter (\(k, v) -> k == currentTab) model.result))


errorPage : Int -> ErrorModel -> Html Msg
errorPage height model =
    div [id "outputID", class "output", style [("height", (toString (height - 40)) ++ "px")]] [
        h1 [] [text model.title],
        dl []
            <| List.concat
                <| List.map (\(k, v) -> [dt [] [text k], dd [] [text v]])
                <| model.properties
    ]


port contents : (String -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [
        contents UpdateScript,
        Window.resizes (\size -> WindowResize size.height)
    ]


init : Navigation.Location -> (Model, Cmd Msg)
init l =
    let
        initialScript =
            "for (let lp = 0; lp < 10; lp += 1)\n\tconsole.log(lp);"

        initialBatch =
            Cmd.batch [
                openEditor initialScript,
                Task.perform (\size -> WindowResize size.height) Window.size
            ]

    in
        log (toString l) (Model l "" 0 (Result.Ok (SuccessModel [] Nothing)), initialBatch)


runScript : String -> String -> Cmd Msg
runScript href script =
    let
        url =
--            "https://boiling-stream-77584.herokuapp.com/process"
            href ++ "api/process"

        put url body =
            Http.request
                { method = "PUT"
                , headers = []
                , url = url
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

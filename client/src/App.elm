module App exposing (main, view)

import Browser exposing (element)
import Html exposing (Html, button, div, h1, h2, img, input, text, textarea)
import Html.Attributes as Attr exposing (checked, class, classList, disabled, for, href, id, name, rows, src, type_, value)
import Html.Events exposing (onClick, onInput)
import Http exposing (Body, Expect, expectJson, request)
import Json.Decode as Decode exposing (Decoder, Value, bool, int, list, maybe, string, succeed)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode as Encode exposing (encode)
import Url exposing (percentEncode)



-- MAIN


main : Program Flags Model Msg
main =
    element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Word =
    { words : List String
    , count : Int
    }


type alias Model =
    { popup : Bool
    , input : String
    , list : List Word
    , message : String
    , serverHost : String
    , success : Bool
    }


type alias Flags =
    { serverHost : String }


type alias WordCloundRes =
    { success : Bool
    , data : List Word
    , message : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { popup = False
      , input = ""
      , list = []
      , message = ""
      , success = True
      , serverHost = flags.serverHost
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = SeePopup
    | HidePopup
    | FetchWordCloud
    | InputText String
    | GotWordCloud (Result Http.Error WordCloundRes)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        { input } =
            model
    in
    case msg of
        SeePopup ->
            ( { model | popup = True }, Cmd.none )

        HidePopup ->
            ( { model | popup = False }, Cmd.none )

        FetchWordCloud ->
            if String.isEmpty input then
                ( { model | message = "Nothing to analyze", success = False }
                , Cmd.none
                )

            else
                let
                    body =
                        "text=" ++ percentEncode input

                    path =
                        "/wordcloud"

                    url =
                        model.serverHost ++ path

                    cmd =
                        Http.expectJson GotWordCloud wordCloudDecoder
                            |> post url (Http.stringBody "application/x-www-form-urlencoded" body)
                in
                ( { model | list = [] }, cmd )

        GotWordCloud (Ok { data, message, success }) ->
            ( { model | list = data, message = message, success = success }
            , Cmd.none
            )

        GotWordCloud (Err err) ->
            ( { model | message = httpErrToStr err, success = False }
            , Cmd.none
            )

        InputText text ->
            ( { model | input = text }, Cmd.none )



-- VIEW


viewWordCloud : List Word -> Html Msg
viewWordCloud list =
    let
        counts = 
            list
                |> List.map (\word -> word.count)
                
    in
    list
        |> List.map (\{ words, count } -> div [] [ text (String.join "|" words) ])
        |> div []


view : Model -> Html Msg
view { message, list, success } =
    div [ class "container" ]
        [ h2 [] [ text "Input a paragraph" ]
        , textarea [ onInput InputText, class "input__textarea" ] []
        , button [ class "button__submit", onClick FetchWordCloud ] [ text "Generate Word Cloud" ]
        , div [ class "message", classList [ ( "message__error", not success ), ( "message__success", success ) ] ] [ text message ]
        , viewWordCloud list
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        []



-- DATA FETCHING


wordDecoder : Decoder Word
wordDecoder =
    succeed Word
        |> required "words" (list string)
        |> required "count" int


wordCloudDecoder : Decoder WordCloundRes
wordCloudDecoder =
    succeed WordCloundRes
        |> required "success" bool
        |> optional "data" (list wordDecoder) []
        |> optional "message" string ""


post : String -> Body -> Expect Msg -> Cmd Msg
post url body expect =
    request
        { method = "POST"
        , headers = []
        , url = url
        , body = body
        , expect = expect
        , timeout = Nothing
        , tracker = Nothing
        }


httpErrToStr : Http.Error -> String
httpErrToStr error =
    case error of
        Http.BadUrl url ->
            "The URL " ++ url ++ " was invalid"

        Http.Timeout ->
            "Unable to reach the server, try again"

        Http.NetworkError ->
            "Unable to reach the server, check your network connection"

        Http.BadStatus 500 ->
            "The server had a problem, try again later"

        Http.BadStatus 404 ->
            "Page not found"

        Http.BadStatus _ ->
            "Unknown error"

        Http.BadBody errorMessage ->
            errorMessage

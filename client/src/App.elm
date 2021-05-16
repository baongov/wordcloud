module App exposing (main, view)

import Browser exposing (element)
import Html exposing (Html, button, div, h1, h2, h3, img, input, option, select, span, text, textarea)
import Html.Attributes as Attr exposing (checked, class, classList, disabled, for, href, id, name, rows, src, style, type_, value)
import Html.Events exposing (on, onClick, onInput, onMouseOver)
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


type alias Config =
    { limitCount : Int
    }


type alias Model =
    { popup : Bool
    , input : String
    , list : List Word
    , message : String
    , serverHost : String
    , success : Bool
    , hoveredText : String
    , countValues : List Int
    , config : Config
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
      , hoveredText = ""
      , countValues = []
      , config =
            { limitCount = 0
            }
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
    | WordHovering String
    | EditLimitCount String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        { input, list, config } =
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
            let
                countValues =
                    data
                        |> List.map .count
                        |> List.foldr
                            (\count result ->
                                if List.member count result then
                                    result

                                else
                                    List.append result [ count ]
                            )
                            []
            in
            ( { model | list = data, message = message, success = success, countValues = countValues }
            , Cmd.none
            )

        GotWordCloud (Err err) ->
            ( { model | message = httpErrToStr err, success = False }
            , Cmd.none
            )

        InputText text ->
            ( { model | input = text }, Cmd.none )

        WordHovering string ->
            ( { model | hoveredText = string }, Cmd.none )

        EditLimitCount limit ->
            let
                newConfig =
                    { config | limitCount = String.toInt limit |> Maybe.withDefault 0 }
            in
            ( { model | config = newConfig }, Cmd.none )



-- VIEW


viewWord : Word -> ( Int, Int ) -> Model -> Html Msg
viewWord { words, count } ( maxCount, minCount ) { hoveredText } =
    case words of
        head :: tail ->
            let
                maxSize =
                    64

                minSize =
                    16

                wordSize =
                    if maxCount <= minCount then
                        8

                    else
                        toFloat (count - minCount) / toFloat (maxCount - minCount) * (maxSize - minSize) + minSize

                opacity =
                    if maxCount <= minCount then
                        1

                    else
                        toFloat (count - minCount) / toFloat (maxCount - minCount) * (1 - 0.5) + 0.5

                isHovering =
                    head == hoveredText
            in
            div
                [ onMouseOver (WordHovering head)
                , class "word__item-container"
                ]
                [ span
                    [ class "word__item"
                    , style "opacity" (String.fromFloat opacity)
                    , style "font-size" (String.fromFloat wordSize ++ "px")
                    ]
                    [ text head ]
                , if isHovering then
                    let
                        similarWords =
                            "Similar words: " ++ (tail |> String.join ", ")

                        countString =
                            "Count: " ++ (count |> String.fromInt)
                    in
                    div [ class "word__tooltip" ] [ div [] [ text similarWords ], div [] [ text countString ] ]

                  else
                    text ""
                ]

        _ ->
            text ""


viewWordCloud : List Word -> Model -> Html Msg
viewWordCloud list model =
    let
        counts =
            List.map (\word -> .count word) list

        max =
            counts
                |> List.maximum
                |> Maybe.withDefault 0

        min =
            counts
                |> List.minimum
                |> Maybe.withDefault 0

        { config } =
            model

        { limitCount } =
            config
    in
    list
        |> List.map
            (\word ->
                if word.count <= limitCount then
                    text ""

                else
                    viewWord word ( max, min ) model
            )
        |> div [ class "word__items" ]


durationOption : Int -> Html Msg
durationOption duration =
    option [ value (String.fromInt duration) ] [ text (String.fromInt duration) ]


view : Model -> Html Msg
view ({ message, list, success, countValues } as model) =
    div [ class "container" ]
        [ div [ class "section__input" ]
            [ h2 [] [ text "Input a paragraph" ]
            , textarea [ onInput InputText, class "input__textarea" ] []
            , button [ class "button__submit", onClick FetchWordCloud ] [ text "Generate Word Cloud" ]
            , div [ class "message", classList [ ( "message__error", not success ), ( "message__success", success ) ] ] [ text message ]
            , viewWordCloud list model
            ]
        , div [ class "section__config" ]
            [ h2 [] [ text "Configuration" ]
            , h3 [] [ text "Limit count" ]
            , div [] [ text "Word count that is smaller that this value won't show" ]
            , countValues
                |> List.map durationOption
                |> select [ class "section__config-limitCount", on "change" (Decode.map EditLimitCount (Decode.at [ "target", "value" ] Decode.string)) ]
            ]
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

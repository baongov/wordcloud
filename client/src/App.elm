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
    , sentances : List String
    , message : String
    , serverHost : String
    , success : Bool
    , hoveredText : String
    , clickedText : String
    , countValues : List Int
    , config : Config
    }


type alias Flags =
    { serverHost : String }


type alias WordCloundData =
    { wordCount : List Word, sentances : List String }


type alias WordCloundRes =
    { success : Bool
    , data : WordCloundData
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
      , clickedText = ""
      , sentances = []
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
    | WordClicked String
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
                    data.wordCount
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
            ( { model
                | list = data.wordCount
                , sentances = data.sentances
                , message = message
                , success = success
                , countValues = countValues
              }
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

        WordClicked string ->
            ( { model | clickedText = string }, Cmd.none )

        EditLimitCount limit ->
            let
                newConfig =
                    { config | limitCount = String.toInt limit |> Maybe.withDefault 0 }
            in
            ( { model | config = newConfig }, Cmd.none )



-- VIEW


viewWord : Word -> ( Int, Int ) -> Model -> Html Msg
viewWord { words, count } ( maxCount, minCount ) { hoveredText, clickedText } =
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

                isClicked =
                    clickedText == head
            in
            div
                [ onMouseOver (WordHovering head)
                , onClick (WordClicked head)
                , class "word__item-container"
                ]
                [ span
                    [ class "word__item"
                    , classList [ ( "clicked", isClicked ) ]
                    , style "opacity" (String.fromFloat opacity)
                    , style "font-size" (String.fromFloat wordSize ++ "px")
                    ]
                    [ text head ]
                , if isHovering then
                    let
                        similarWords =
                            [ span [] [ text "Similar words: " ]
                            , span [ class "text__highlight" ] [ tail |> String.join ", " |> text ]
                            ]

                        countString =
                            [ span [] [ text "Count: " ]
                            , span [ class "text__highlight" ] [ count |> String.fromInt |> text ]
                            ]
                    in
                    div [ class "word__tooltip" ] [ div [] similarWords, div [] countString ]

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
                if word.count < limitCount then
                    text ""

                else
                    viewWord word ( max, min ) model
            )
        |> div [ class "word__items" ]


durationOption : Int -> Html Msg
durationOption duration =
    option [ value (String.fromInt duration) ] [ text (String.fromInt duration) ]


viewSentances : Model -> Html Msg
viewSentances { sentances, clickedText, list } =
    if String.isEmpty clickedText then
        text ""

    else
        let
            relatedWords =
                list
                    |> List.filter
                        (\word ->
                            (word.words |> List.head |> Maybe.withDefault "") == clickedText
                        )
                    |> List.head
                    |> Maybe.withDefault { words = [], count = 0 }
                    |> .words

            firstWord =
                relatedWords |> List.head |> Maybe.withDefault ""

            title =
                [ span [] [ text "Word " ], span [ class "text__highlight" ] [ text firstWord ], span [] [ text " is mentioned at following sentances:" ] ]
        in
        (h3 [ class "section__detail-title" ] title
            :: (sentances
                    |> List.filter
                        (\sentance ->
                            let
                                lowerSentance =
                                    String.toLower sentance
                            in
                            relatedWords
                                |> List.map (\word -> String.contains (String.toLower word) lowerSentance)
                                |> List.foldr (||) False
                        )
                    |> List.indexedMap
                        (\index sentance ->
                            let
                                indexStr =
                                    index + 1 |> String.fromInt
                            in
                            div [ class "section__detail-sentance" ]
                                [ text (indexStr ++ ".  " ++ sentance) ]
                        )
               )
        )
            |> div []


view : Model -> Html Msg
view ({ message, list, success, countValues } as model) =
    div []
        [ div [ class "container" ]
            [ div [ class "section__input" ]
                [ h2 [] [ text "Input a paragraph" ]
                , textarea [ onInput InputText, class "input__textarea" ] []
                , button [ class "button__submit", onClick FetchWordCloud ] [ text "Generate Word Cloud" ]
                , div [ class "message", classList [ ( "message__error", not success ), ( "message__success", success ) ] ] [ text message ]
                ]
            , div [ class "section__config" ]
                [ h2 [] [ text "Configuration" ]
                , h3 [] [ text "Limit count" ]
                , div [] [ text "Word count that is smaller than this value won't show. Therefore, just important words will show." ]
                , countValues
                    |> List.map durationOption
                    |> select [ class "section__config-limitCount", on "change" (Decode.map EditLimitCount (Decode.at [ "target", "value" ] Decode.string)) ]
                ]
            ]
        , div [ class "container" ]
            [ div [ class "section__ouput" ]
                [ viewWordCloud list model
                ]
            , div [ class "section__detail" ]
                [ viewSentances model
                ]
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


wordCloudDataDecoder : Decoder WordCloundData
wordCloudDataDecoder =
    succeed WordCloundData
        |> optional "wordCount" (list wordDecoder) []
        |> optional "sentances" (list string) []


wordCloudDecoder : Decoder WordCloundRes
wordCloudDecoder =
    succeed WordCloundRes
        |> required "success" bool
        |> optional "data" wordCloudDataDecoder { wordCount = [], sentances = [] }
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

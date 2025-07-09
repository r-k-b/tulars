module View exposing (view)

import Browser exposing (Document)
import Html
    exposing
        ( Html
        , div
        )
import Html.Attributes as HA
import Html.Events
import Types
    exposing
        ( Model
        , Msg(..)
        )


view : Model -> Document Msg
view model =
    let
        body : Html Msg
        body =
            div []
                [ Html.button [ Html.Events.onClick ToggleDemoClicked ] [ Html.text "Toggle Demo Enabled/Disabled" ]
                , Html.p []
                    [ Html.text <|
                        if model.demoButtonsEnabled then
                            "Demo State: Currently Enabled"

                        else
                            "Demo State: Currently Disabled"
                    ]
                , Html.p [] [ Html.text "this button works after being re-enabled:" ]
                , demoButton model DemoBtn1Clicked { setFalseAttrs = True }
                , Html.p [] [ Html.text "this button is unexpectedly still disabled after being re-enabled:" ]
                , demoButton model DemoBtn2Clicked { setFalseAttrs = False }
                ]
    in
    { title = "Tulars", body = [ body ] }


demoButton : Model -> msg -> { setFalseAttrs : Bool } -> Html msg
demoButton model n { setFalseAttrs } =
    Html.p []
        [ Html.button
            ([ Html.Events.onClick n ]
                ++ (if model.demoButtonsEnabled then
                        if setFalseAttrs then
                            [ HA.disabled False ]

                        else
                            []

                    else
                        [ HA.disabled True ]
                   )
            )
            [ if model.demoButtonsEnabled then
                Html.text "Clicking this button should increment the counter ->"

              else
                Html.text "Clicking this button should NOT increment the counter"
            ]
        , Html.text <| String.fromInt model.demoCounter
        ]

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root

    property string cfg_aiProvider: "groq"
    property alias cfg_aiApiKey: apiKeyField.text
    property alias cfg_aiGroqModel: groqModelField.text
    property alias cfg_aiOpenaiModel: openaiModelField.text
    property alias cfg_aiGeminiModel: geminiModelField.text
    property alias cfg_aiOpenrouterModel: openrouterModelField.text
    property alias cfg_aiMemory: memoryArea.text

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        ComboBox {
            id: providerCombo
            Kirigami.FormData.label: "AI Provider:"
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ListModel {
                ListElement { value: "groq";        label: "Groq  —  Free & blazing fast (Llama)" }
                ListElement { value: "openai";      label: "OpenAI  (GPT-4o, GPT-4o-mini…)" }
                ListElement { value: "gemini";      label: "Google Gemini" }
                ListElement { value: "openrouter";  label: "OpenRouter  (100+ models)" }
            }

            currentIndex: {
                if (root.cfg_aiProvider === "openai") return 1;
                if (root.cfg_aiProvider === "gemini") return 2;
                if (root.cfg_aiProvider === "openrouter") return 3;
                return 0;
            }

            onActivated: {
                if (currentIndex === 0) root.cfg_aiProvider = "groq";
                else if (currentIndex === 1) root.cfg_aiProvider = "openai";
                else if (currentIndex === 2) root.cfg_aiProvider = "gemini";
                else if (currentIndex === 3) root.cfg_aiProvider = "openrouter";
            }
        }

        // API Key — TextField with overlaid show/hide button
        TextField {
            id: apiKeyField
            Kirigami.FormData.label: "API Key:"
            Layout.fillWidth: true
            placeholderText: "Paste your API key here…"
            echoMode: TextInput.Password
            rightPadding: showBtn.width + 4

            Button {
                id: showBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 2
                width: implicitHeight
                checkable: true
                icon.name: checked ? "view-hidden" : "view-visible"
                flat: true
                ToolTip.text: checked ? "Hide" : "Show"
                ToolTip.visible: hovered
                onCheckedChanged: {
                    apiKeyField.echoMode = checked ? TextInput.Normal : TextInput.Password
                }
            }
        }

        TextField {
            id: groqModelField
            Kirigami.FormData.label: "Groq Model:"
            Layout.fillWidth: true
            visible: providerCombo.currentIndex === 0
            placeholderText: "llama-3.3-70b-versatile"
        }

        TextField {
            id: openaiModelField
            Kirigami.FormData.label: "OpenAI Model:"
            Layout.fillWidth: true
            visible: providerCombo.currentIndex === 1
            placeholderText: "gpt-4o-mini"
        }

        TextField {
            id: geminiModelField
            Kirigami.FormData.label: "Gemini Model:"
            Layout.fillWidth: true
            visible: providerCombo.currentIndex === 2
            placeholderText: "gemini-2.0-flash"
        }

        TextField {
            id: openrouterModelField
            Kirigami.FormData.label: "OpenRouter Model:"
            Layout.fillWidth: true
            visible: providerCombo.currentIndex === 3
            placeholderText: "openai/gpt-4o-mini"
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 4
        }

        Label {
            Kirigami.FormData.label: "User Memory:"
            text: "Context or facts you want the AI to remember:"
            font.pixelSize: 11
            opacity: 0.65
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            clip: true

            TextArea {
                id: memoryArea
                placeholderText: "e.g. My name is Abhinav and I prefer concise responses in Python..."
                wrapMode: TextArea.Wrap
                font.pixelSize: 12
            }
        }
    }
}

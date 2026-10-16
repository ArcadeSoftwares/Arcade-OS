import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami as Kirigami

Item {
    id: root
    height: 46

    signal searchTextChanged(string text)

    function clear() {
        input.text = ""
    }

    function forceActiveFocus() {
        input.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: 11
        color: Qt.rgba(1, 1, 1, 0.10)
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 10

            Kirigami.Icon {
                source: "search"
                width: 18
                height: 18
                color: Qt.rgba(1, 1, 1, 0.5)
                Layout.alignment: Qt.AlignVCenter
            }

            TextField {
                id: input
                Layout.fillWidth: true
                placeholderText: "Search apps, files, commands"
                color: "white"
                font.pixelSize: 14

                background: Rectangle { color: "transparent" }

                onTextChanged: root.searchTextChanged(text)

                Keys.onEscapePressed: {
                    if (text !== "") {
                        text = ""
                    } else {
                        var dialog = root.parent
                        while (dialog && !dialog.hasOwnProperty("visible")) {
                            dialog = dialog.parent
                        }
                        if (dialog) {
                            dialog.visible = false
                        }
                    }
                }
            }
        }
    }
}

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var appsRootModel: null
    property var favoritesModel: null
    property string filterText: ""

    signal appActivated

    property var allAppsModel: null

    function reloadModels() {
        if (appsRootModel && appsRootModel.count > 2) {
            allAppsModel = appsRootModel.modelForRow(2)
        } else {
            allAppsModel = null
        }
    }

    Component.onCompleted: reloadModels()

    readonly property bool searching: filterText.trim() !== ""

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: plasmoid
        favoritesModel: root.favoritesModel
        mergeResults: true
        query: root.filterText
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Text {
            visible: !root.searching
            text: "PINNED APPS"
            color: Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: 10
            font.letterSpacing: 1.1
        }

        GridView {
            id: pinnedGrid
            visible: !root.searching
            Layout.fillWidth: true
            Layout.preferredHeight: 164
            cellWidth: Math.floor(width / 6)
            cellHeight: 82
            model: root.favoritesModel
            clip: true
            interactive: false

            delegate: Item {
                width: pinnedGrid.cellWidth
                height: pinnedGrid.cellHeight

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            source: model.decoration
                        }
                    }

                    Text {
                        text: model.display
                        width: pinnedGrid.cellWidth - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.82)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.favoritesModel && root.favoritesModel.trigger) {
                            root.favoritesModel.trigger(index, "", null)
                            root.appActivated()
                        }
                    }
                }
            }
        }

        Text {
            visible: !root.searching
            text: "ALL APPS"
            color: Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: 10
            font.letterSpacing: 1.1
        }

        ListView {
            id: allAppsList
            visible: !root.searching
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.allAppsModel

            delegate: Rectangle {
                width: allAppsList.width
                height: 38
                radius: 8
                color: appMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 10

                    Kirigami.Icon {
                        width: 20
                        height: 20
                        source: model.decoration
                    }

                    Text {
                        text: model.display
                        color: Qt.rgba(1, 1, 1, 0.84)
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: appMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.allAppsModel && root.allAppsModel.trigger) {
                            root.allAppsModel.trigger(index, "", null)
                            root.appActivated()
                        }
                    }
                }
            }
        }

        Text {
            visible: root.searching
            text: "SEARCH RESULTS"
            color: Qt.rgba(1, 1, 1, 0.38)
            font.pixelSize: 10
            font.letterSpacing: 1.1
        }

        ListView {
            id: resultsList
            visible: root.searching
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
            currentIndex: count > 0 ? 0 : -1
            focus: true

            delegate: Rectangle {
                width: resultsList.width
                height: 40
                radius: 8
                color: (resultsList.currentIndex === index || resultMouse.containsMouse)
                    ? Qt.rgba(0.23, 0.39, 0.62, 0.35)
                    : "transparent"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 10

                    Kirigami.Icon {
                        width: 20
                        height: 20
                        source: model.decoration
                    }

                    Text {
                        text: model.display
                        color: Qt.rgba(1, 1, 1, 0.90)
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: resultMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: resultsList.currentIndex = index
                    onClicked: {
                        if (resultsList.model && resultsList.model.trigger) {
                            resultsList.model.trigger(index, "", null)
                            root.appActivated()
                        }
                    }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down && currentIndex < count - 1) {
                    currentIndex += 1
                    event.accepted = true
                } else if (event.key === Qt.Key_Up && currentIndex > 0) {
                    currentIndex -= 1
                    event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && currentIndex >= 0) {
                    if (model && model.trigger) {
                        model.trigger(currentIndex, "", null)
                        root.appActivated()
                    }
                    event.accepted = true
                }
            }
        }
    }
}

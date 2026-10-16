import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core as PlasmaCore

PlasmaCore.Dialog {
    id: root

    property var appsRootModel: null
    property var favoritesModel: null

    objectName: "arcadeLauncherPopup"
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    location: PlasmaCore.Types.Floating
    hideOnWindowDeactivate: true
    backgroundHints: PlasmaCore.Dialog.NoBackground

    property int popupWidth: 760
    property int popupHeight: 560

    width: popupWidth
    height: popupHeight

    onVisibleChanged: {
        if (visible) {
            positionWindow()
            searchBar.clear()
            searchBar.forceActiveFocus()
            if (appGrid) {
                appGrid.reloadModels()
            }
        }
    }

    function positionWindow() {
        var screen = Qt.application.screens[0]
        x = Math.round((screen.width - popupWidth) / 2)
        y = Math.round((screen.height - popupHeight) / 2)
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(0.08, 0.10, 0.16, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Header {
                    Layout.fillWidth: true
                }

                SearchBar {
                    id: searchBar
                    Layout.fillWidth: true
                    onSearchTextChanged: appGrid.filterText = text
                }

                AppGrid {
                    id: appGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    appsRootModel: root.appsRootModel
                    favoritesModel: root.favoritesModel
                    onAppActivated: root.visible = false
                }
            }
        }

        Keys.onEscapePressed: root.visible = false
    }
}

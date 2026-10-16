import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami as Kirigami

Item {
    id: root

    function showLauncher() {
        if (launcherPopup && !launcherPopup.visible) {
            launcherPopup.visible = true
        }
    }

    function toggleLauncher() {
        if (launcherPopup) {
            launcherPopup.visible = !launcherPopup.visible
        }
    }

    MenuRepresentation {
        id: launcherPopup
        visible: false
        appsRootModel: rootModel
        favoritesModel: globalFavorites
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.72
        height: width
        source: (Plasmoid.configuration.useCustomButtonImage && Plasmoid.configuration.customButtonImage !== "")
            ? Plasmoid.configuration.customButtonImage
            : Plasmoid.configuration.icon
        active: mouseArea.containsMouse
        smooth: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.toggleLauncher()
    }
}

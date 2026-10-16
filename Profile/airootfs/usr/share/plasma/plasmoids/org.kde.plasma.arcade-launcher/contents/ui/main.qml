
import QtQuick 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker 0.1 as Kicker
PlasmoidItem {
    id: root

    anchors.fill: parent

    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactRepresentation {}
    fullRepresentation: Item {}

    property QtObject globalFavorites: rootModel.favoritesModel

    Plasmoid.icon: Plasmoid.configuration.useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Plasmoid.configuration.icon

    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        flat: true
        sorted: true
        showSeparators: false
        appletInterface: root

        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: true
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false

        Component.onCompleted: {
            favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id)
            if (!Plasmoid.configuration.favoritesPortedToKAstats) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favoriteApps);
                }
                Plasmoid.configuration.favoritesPortedToKAstats = true;
            }
        }
    }

    Connections {
        target: globalFavorites

        function onFavoritesChanged() {
            Plasmoid.configuration.favoriteApps = target.favorites;
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onFavoriteAppsChanged() {
            globalFavorites.favorites = Plasmoid.configuration.favoriteApps;
        }
    }

    Component.onCompleted: {
        rootModel.refresh();
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            if (root.compactRepresentationItem) {
                root.compactRepresentationItem.showLauncher()
            }
        }
    }
}

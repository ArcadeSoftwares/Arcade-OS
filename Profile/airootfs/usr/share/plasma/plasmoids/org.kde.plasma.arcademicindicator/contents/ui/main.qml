import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property bool micActive: false
    property string micApps: ""
    readonly property color indicatorColor: Qt.rgba(1.0, 0.58, 0.15, 1.0)
    readonly property string checkCommand: "sh -c 'if ! command -v pactl >/dev/null 2>&1; then echo \"idle|\"; exit 0; fi; apps=$(pactl list source-outputs 2>/dev/null | sed -n \"s/.*application.name = \\\"\\(.*\\)\\\".*/\\1/p\" | sort -u | tr \"\\n\" \",\" | sed \"s/,$//\"); if [ -n \"$apps\" ]; then echo \"active|$apps\"; else echo \"idle|\"; fi'"

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: micActive ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus

    toolTipMainText: i18n("Microphone")
    toolTipSubText: micActive ? (micApps.length > 0 ? i18n("In use by: %1", micApps) : i18n("Microphone is in use")) : i18n("Microphone is idle")

    function refreshMicState() {
        execSource.disconnectSource(checkCommand)
        execSource.connectSource(checkCommand)
    }

    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            if (sourceName !== root.checkCommand) {
                return
            }

            const stdoutText = data["stdout"] ? data["stdout"].toString().trim() : ""
            const parts = stdoutText.split("|")
            root.micActive = parts.length > 0 && parts[0] === "active"
            root.micApps = parts.length > 1 ? parts[1] : ""
            execSource.disconnectSource(sourceName)
        }
    }

    Timer {
        id: pollTimer
        interval: 1200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshMicState()
    }

    fullRepresentation: Item {
        id: indicatorContainer

        readonly property real indicatorSize: parent ? Math.min(parent.height, 11) : 11

        Layout.preferredWidth: root.micActive ? indicatorSize : 0
        Layout.preferredHeight: indicatorSize
        Layout.minimumWidth: root.micActive ? indicatorSize : 0
        Layout.minimumHeight: indicatorSize

        visible: root.micActive

        Rectangle {
            id: dot
            anchors.centerIn: parent
            width: indicatorContainer.indicatorSize
            height: indicatorContainer.indicatorSize
            radius: width / 2
            color: root.indicatorColor
            opacity: 0.95
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            active: root.micActive
            mainText: i18n("Microphone")
            subText: root.micApps.length > 0 ? i18n("In use by: %1", root.micApps) : i18n("Microphone is in use")
        }

        SequentialAnimation {
            running: root.micActive
            loops: Animation.Infinite

            NumberAnimation {
                target: dot
                property: "opacity"
                from: 0.95
                to: 0.35
                duration: 380
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                target: dot
                property: "opacity"
                from: 0.35
                to: 0.95
                duration: 380
                easing.type: Easing.InOutSine
            }
        }
    }
}

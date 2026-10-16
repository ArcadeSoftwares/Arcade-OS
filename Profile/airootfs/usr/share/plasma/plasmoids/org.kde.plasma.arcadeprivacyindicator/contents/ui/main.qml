import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property bool cameraActive: false
    property bool micActive: false
    property string cameraApps: ""
    property string micApps: ""

    readonly property color cameraColor: Qt.rgba(0.18, 0.86, 0.42, 1.0)
    readonly property color micColor: Qt.rgba(1.0, 0.58, 0.15, 1.0)

    readonly property bool anyActive: cameraActive || micActive
    readonly property string cameraCommand: "sh -c 'pids=\"\"; for dev in /dev/video*; do [ -e \"$dev\" ] || continue; devpids=$(fuser \"$dev\" 2>/dev/null | sed \"s/[^0-9[:space:]]/ /g\"); [ -n \"$devpids\" ] && pids=\"$pids $devpids\"; done; if [ -n \"$pids\" ]; then uniqpids=$(printf \"%s\\n\" $pids | tr \" \" \"\\n\" | sed \"/^$/d\" | sort -u); pidcsv=$(echo \"$uniqpids\" | tr \"\\n\" \",\" | sed \"s/,$//\"); apps=$(ps -p \"$pidcsv\" -o comm= 2>/dev/null | sed \"/^$/d\" | sort -u | tr \"\\n\" \",\" | sed \"s/,$//\"); echo \"active|$apps\"; else echo \"idle|\"; fi'"
    readonly property string micCommand: "sh -c 'if ! command -v pactl >/dev/null 2>&1; then echo \"idle|\"; exit 0; fi; apps=$(pactl list source-outputs 2>/dev/null | sed -n \"s/.*application.name = \\\"\\(.*\\)\\\".*/\\1/p\" | sort -u | tr \"\\n\" \",\" | sed \"s/,$//\"); if [ -n \"$apps\" ]; then echo \"active|$apps\"; else echo \"idle|\"; fi'"

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: anyActive ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus

    toolTipMainText: i18n("Privacy")
    toolTipSubText: {
        const details = []
        if (cameraActive) {
            details.push(cameraApps.length > 0 ? i18n("Camera: %1", cameraApps) : i18n("Camera active"))
        }
        if (micActive) {
            details.push(micApps.length > 0 ? i18n("Microphone: %1", micApps) : i18n("Microphone active"))
        }
        return details.join("\n")
    }

    function refreshState() {
        execSource.disconnectSource(cameraCommand)
        execSource.disconnectSource(micCommand)
        execSource.connectSource(cameraCommand)
        execSource.connectSource(micCommand)
    }

    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            const stdoutText = data["stdout"] ? data["stdout"].toString().trim() : ""
            const parts = stdoutText.split("|")
            const active = parts.length > 0 && parts[0] === "active"
            const apps = parts.length > 1 ? parts[1] : ""

            if (sourceName === root.cameraCommand) {
                root.cameraActive = active
                root.cameraApps = apps
            } else if (sourceName === root.micCommand) {
                root.micActive = active
                root.micApps = apps
            }

            execSource.disconnectSource(sourceName)
        }
    }

    Timer {
        id: pollTimer
        interval: 1200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshState()
    }

    fullRepresentation: Item {
        id: indicatorContainer

        readonly property real dotSize: parent ? Math.min(parent.height, 14) : 14
        property real pulseOpacity: 0.95

        Layout.preferredWidth: root.anyActive ? dotSize : 0
        Layout.minimumWidth: Layout.preferredWidth
        Layout.preferredHeight: dotSize
        Layout.minimumHeight: dotSize

        visible: root.anyActive

        Canvas {
            id: privacyDot
            anchors.centerIn: parent
            width: indicatorContainer.dotSize
            height: indicatorContainer.dotSize
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                const centerX = width / 2
                const centerY = height / 2
                const radius = width / 2

                if (root.cameraActive && root.micActive) {
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY)
                    ctx.arc(centerX, centerY, radius, Math.PI / 2, Math.PI * 1.5, false)
                    ctx.closePath()
                    ctx.fillStyle = root.cameraColor
                    ctx.globalAlpha = indicatorContainer.pulseOpacity
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY)
                    ctx.arc(centerX, centerY, radius, -Math.PI / 2, Math.PI / 2, false)
                    ctx.closePath()
                    ctx.fillStyle = root.micColor
                    ctx.globalAlpha = indicatorContainer.pulseOpacity
                    ctx.fill()

                    ctx.globalAlpha = 0.28
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 1)
                    ctx.lineWidth = 0.8
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY - radius)
                    ctx.lineTo(centerX, centerY + radius)
                    ctx.stroke()
                } else {
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, radius, 0, Math.PI * 2)
                    ctx.closePath()
                    ctx.fillStyle = root.cameraActive ? root.cameraColor : root.micColor
                    ctx.globalAlpha = indicatorContainer.pulseOpacity
                    ctx.fill()
                }
            }
        }

        Connections {
            target: root
            function onCameraActiveChanged() { privacyDot.requestPaint() }
            function onMicActiveChanged() { privacyDot.requestPaint() }
        }

        Connections {
            target: indicatorContainer
            function onPulseOpacityChanged() { privacyDot.requestPaint() }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            active: root.anyActive
            mainText: i18n("Privacy")
            subText: root.toolTipSubText
        }

        SequentialAnimation {
            running: root.anyActive
            loops: Animation.Infinite

            NumberAnimation {
                target: indicatorContainer
                property: "pulseOpacity"
                from: 0.95
                to: 0.55
                duration: 360
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: indicatorContainer
                property: "pulseOpacity"
                from: 0.55
                to: 0.95
                duration: 360
                easing.type: Easing.InOutSine
            }
        }
    }
}

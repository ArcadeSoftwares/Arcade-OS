import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    readonly property bool isHovered: clickArea.containsMouse
    readonly property real bgLuma: (PlasmaCore.Theme.backgroundColor.r * 0.2126) + (PlasmaCore.Theme.backgroundColor.g * 0.7152) + (PlasmaCore.Theme.backgroundColor.b * 0.0722)
    readonly property bool darkPanel: bgLuma < 0.52
    readonly property color baseIconColor: darkPanel ? "#FFFFFF" : "#0F1115"
    readonly property color iconColor: isHovered ? "#1D7CFF" : baseIconColor

    property bool sheetOpen: false
    property string connectedSsid: ""
    property string scanCommand: "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto"

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    toolTipMainText: i18n("Wi‑Fi")
    toolTipSubText: connectedSsid.length > 0 ? connectedSsid : i18n("Not connected")

    ListModel {
        id: networksModel
    }

    function refreshNetworks() {
        networksModel.clear()
        connectedSsid = ""
        execSource.disconnectSource(scanCommand)
        execSource.connectSource(scanCommand)
    }

    function parseNetworks(outputText) {
        networksModel.clear()
        connectedSsid = ""

        const rows = outputText.split("\n")
        for (let i = 0; i < rows.length; i++) {
            const line = rows[i].trim()
            if (line.length === 0) {
                continue
            }

            const parts = line.split(":")
            if (parts.length < 4) {
                continue
            }

            const activeFlag = parts[0]
            const signalValue = parseInt(parts[parts.length - 2])
            const security = parts[parts.length - 1]
            let ssid = parts.slice(1, parts.length - 2).join(":")
            ssid = ssid.replace(/\\:/g, ":")
            if (ssid.length === 0) {
                ssid = i18n("Hidden Network")
            }

            const connected = activeFlag === "yes"
            if (connected) {
                connectedSsid = ssid
            }

            networksModel.append({
                "ssid": ssid,
                "signal": isNaN(signalValue) ? 0 : signalValue,
                "security": security,
                "connected": connected
            })
        }
    }

    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            if (sourceName === root.scanCommand) {
                const stdoutText = data["stdout"] ? data["stdout"].toString() : ""
                root.parseNetworks(stdoutText)
                execSource.disconnectSource(sourceName)
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 12000
        repeat: true
        running: root.sheetOpen
        onTriggered: root.refreshNetworks()
    }

    onSheetOpenChanged: {
        if (sheetOpen) {
            refreshNetworks()
        }
    }

    fullRepresentation: Item {
        id: iconContainer

        Layout.preferredWidth: iconSize
        Layout.preferredHeight: iconSize
        Layout.minimumWidth: 20
        Layout.minimumHeight: 20

        readonly property real iconSize: parent ? Math.min(parent.height, 24) : 24

        Canvas {
            id: signalCanvas
            anchors.centerIn: parent
            width: iconContainer.iconSize
            height: iconContainer.iconSize
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                const centerX = width / 2
                const centerY = height * 0.73
                const stroke = Math.max(2.0, width * 0.105)

                function drawArc(radius, alpha) {
                    ctx.beginPath()
                    ctx.lineCap = "round"
                    ctx.lineWidth = stroke
                    ctx.strokeStyle = Qt.rgba(iconColor.r, iconColor.g, iconColor.b, alpha)
                    ctx.arc(centerX, centerY, radius, Math.PI * 1.15, Math.PI * 1.85)
                    ctx.stroke()
                }

                drawArc(width * 0.35, 0.5)
                drawArc(width * 0.26, 0.78)
                drawArc(width * 0.17, 1.0)

                ctx.fillStyle = iconColor
                ctx.beginPath()
                ctx.arc(centerX, centerY, Math.max(2.0, width * 0.078), 0, Math.PI * 2)
                ctx.fill()
            }

            Connections {
                target: root
                function onIconColorChanged() { signalCanvas.requestPaint() }
                function onDarkPanelChanged() { signalCanvas.requestPaint() }
            }
        }

        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sheetOpen = !root.sheetOpen
        }
    }

    Rectangle {
        id: sheet
        parent: root
        z: 999
        width: 340
        height: 290
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.985)
        border.width: 1
        border.color: "#D8DDE3"
        opacity: root.sheetOpen ? 1 : 0

        anchors.horizontalCenter: root.horizontalCenter
        y: root.sheetOpen ? root.height + 8 : -height - 24

        Behavior on y {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: i18n("Wi‑Fi")
                    color: "#111317"
                    font.pixelSize: 15
                    font.bold: true
                    Layout.fillWidth: true
                }

                Button {
                    text: "×"
                    flat: true
                    onClicked: root.sheetOpen = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#E8ECF1"
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: networksModel
                spacing: 6
                clip: true

                delegate: Rectangle {
                    required property string ssid
                    required property int signal
                    required property string security
                    required property bool connected

                    width: ListView.view.width
                    height: 42
                    radius: 9
                    color: connected ? "#EAF3FF" : "#F6F8FB"
                    border.width: connected ? 1 : 0
                    border.color: connected ? "#9CC2FF" : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: connected ? "●" : ""
                            color: "#1D7CFF"
                            font.pixelSize: 10
                            Layout.preferredWidth: 8
                        }

                        Text {
                            text: ssid
                            color: "#121418"
                            font.pixelSize: 12
                            font.bold: connected
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: signal + "%"
                            color: "#4B5563"
                            font.pixelSize: 11
                        }

                        Text {
                            text: security.length > 0 && security !== "--" ? "🔒" : ""
                            font.pixelSize: 11
                        }
                    }
                }

                footer: Item {
                    width: ListView.view.width
                    height: networksModel.count === 0 ? 40 : 0

                    Text {
                        anchors.centerIn: parent
                        visible: networksModel.count === 0
                        text: i18n("No networks found")
                        color: "#6B7280"
                        font.pixelSize: 11
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: i18n("Open Network Settings")
                onClicked: {
                    execSource.connectSource("plasmawindowed org.kde.plasma.networkmanagement")
                    root.sheetOpen = false
                }
            }
        }
    }
}

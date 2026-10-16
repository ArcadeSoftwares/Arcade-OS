/*
 * Arcade Battery - KDE Plasma 6 Plasmoid
 * A sleek modern battery indicator with percentage display
 * 
 * Copyright 2024 Arcade Softwares
 * License: GPL-3.0+
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    readonly property int batteryPercent: {
        var start = pmSource.data["Battery"] || {};
        var pct = start["Percent"];
        return (pct !== undefined) ? pct : 100;
    }

    property bool warned30: false
    property bool warned20: false
    property bool warned10: false
    property bool notifiedFull: false

    onBatteryPercentChanged: {
        if (!isCharging) {
            if (batteryPercent <= 10 && !warned10) {
                warned10 = true;
                queueNotification("Battery Critical", "Battery is at " + batteryPercent + "%. Please plug in immediately!", "critical");
            } else if (batteryPercent <= 20 && batteryPercent > 10 && !warned20) {
                warned20 = true;
                queueNotification("Battery Low", "Battery dropped to " + batteryPercent + "%.", "critical");
            } else if (batteryPercent <= 30 && batteryPercent > 20 && !warned30) {
                warned30 = true;
                queueNotification("Battery Notice", "Battery at " + batteryPercent + "%.", "normal");
            }
        } else {
            if (batteryPercent === 100 && !notifiedFull) {
                notifiedFull = true;
                queueNotification("Battery Full", "Battery is fully charged.", "normal");
            }
            if (batteryPercent > 10) warned10 = false;
            if (batteryPercent > 20) warned20 = false;
            if (batteryPercent > 30) warned30 = false;
        }
        if (!isCharging && batteryPercent < 100) notifiedFull = false;
    }

    onIsChargingChanged: {
        if (isCharging) {
            if (batteryPercent > 10) warned10 = false;
            if (batteryPercent > 20) warned20 = false;
            if (batteryPercent > 30) warned30 = false;
        } else {
            if (batteryPercent < 100) notifiedFull = false;
        }
    }

    property string timeToFull: ""
    property string timeToEmpty: ""

    readonly property bool isCharging: {
        var acData = pmSource.data["AC Adapter"] || {};
        return acData["Plugged in"] === true;
    }

    readonly property bool hasBattery: {
        var batData = pmSource.data["Battery"] || {};
        return batData["Has Battery"] === true || batData["Percent"] !== undefined;
    }
    
    readonly property string batteryState: {
        var batData = pmSource.data["Battery"] || {};
        var state = batData["State"];
        if (state === "Charging") return "Charging";
        if (state === "Discharging") return "Discharging";
        if (state === "FullyCharged") return "Fully Charged";
        if (isCharging) return "Charging";
        return "Discharging";
    }

    readonly property color batteryColor: {
        return "#ffffff";
    }

    preferredRepresentation: Plasmoid.compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Plasma5Support.DataSource {
        id: pmSource
        engine: "powermanagement"
        interval: 1000
        
        Component.onCompleted: {
            connectSource("Battery");
            connectSource("AC Adapter");
        }
        
        onSourcesChanged: {
            for (var i = 0; i < sources.length; ++i) {
                var s = sources[i];
                if (s !== "Sleep States" && s !== "PowerDevil") {
                    connectSource(s);
                }
            }
        }
    }
    
    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        
        function notify(title, msg, icon, urgency) {
            var cmd = "notify-send '" + title + "' '" + msg + "' -i " + icon;
            if (urgency) cmd += " -u " + urgency;
            connectSource(cmd);
        }
        
        function openSettings() {
            var cmd = "kcmshell6 kcm_powerdevilprofilesconfig";
            connectSource(cmd);
        }
        
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
        }
    }
    
    ListModel {
        id: btDevices
    }

    Plasma5Support.DataSource {
        id: upowerSource
        engine: "executable"
        interval: 2000 // Poll every 2 seconds for realtime updates
        
        Component.onCompleted: {
            connectSource("upower -d");
        }
        
        property bool firstRun: true
        
        onNewData: function(sourceName, data) {
            if (sourceName !== "upower -d") return;
            var out = data["stdout"] || "";
            var blocks = out.split("Device: ");
            
            var newDevices = [];
            
            for (var i = 1; i < blocks.length; i++) {
                var block = blocks[i];
                var lines = block.split("\n");
                var path = lines[0].trim();
                
                if (path.indexOf("battery_BAT") !== -1) {
                    var ttf = "";
                    var tte = "";
                    for (var k = 1; k < lines.length; k++) {
                        var bline = lines[k].trim();
                        if (bline.indexOf("time to full:") === 0) {
                            ttf = bline.substring(13).trim();
                        } else if (bline.indexOf("time to empty:") === 0) {
                            tte = bline.substring(14).trim();
                        }
                    }
                    root.timeToFull = ttf;
                    root.timeToEmpty = tte;
                    continue;
                }

                if (path.indexOf("DisplayDevice") !== -1 || path.indexOf("line_power") !== -1) {
                    continue;
                }
                
                var devName = "Bluetooth Device";
                var devPct = -1;
                
                for (var j = 1; j < lines.length; j++) {
                    var line = lines[j].trim();
                    if (line.indexOf("model:") === 0) {
                        devName = line.substring(6).trim();
                    } else if (line.indexOf("percentage:") === 0) {
                        var pStr = line.substring(11).trim().replace("%", "");
                        devPct = parseInt(pStr);
                    }
                }
                
                if (devPct !== -1) {
                    newDevices.push({ "name": devName, "percent": devPct });
                }
            }
            
            var currentDeviceNames = [];
            for (var m = 0; m < btDevices.count; m++) {
                currentDeviceNames.push(btDevices.get(m).prettyName);
            }
            
            var newDeviceNames = [];
            for (var n = 0; n < newDevices.length; n++) {
                newDeviceNames.push(newDevices[n].name);
                if (!firstRun && currentDeviceNames.indexOf(newDevices[n].name) === -1) {
                    execSource.notify("Device Connected", newDevices[n].name + " is connected (" + newDevices[n].percent + "%)", "bluetooth-active", "normal");
                }
            }
            
            if (!firstRun) {
                for (var o = 0; o < currentDeviceNames.length; o++) {
                    if (newDeviceNames.indexOf(currentDeviceNames[o]) === -1) {
                        execSource.notify("Device Disconnected", currentDeviceNames[o] + " disconnected", "bluetooth-inactive", "normal");
                    }
                }
            }
            
            btDevices.clear();
            for (var p = 0; p < newDevices.length; p++) {
                btDevices.append({ "prettyName": newDevices[p].name, "percent": newDevices[p].percent });
            }
            
            firstRun = false;
        }
    }
    
    property string pendingNotifyTitle: ""
    property string pendingNotifyMsg: ""
    property string pendingNotifyUrgency: ""

    function queueNotification(title, msg, urgency) {
        pendingNotifyTitle = title;
        pendingNotifyMsg = msg;
        pendingNotifyUrgency = urgency;
        if (compactRoot && compactRoot.grabTimerRef) {
            compactRoot.grabTimerRef.restart();
        } else {
            execSource.notify(title, msg, "dialog-warning", urgency);
        }
    }

    // --- PANEL CAPSULE ---
    compactRepresentation: Item {
        id: compactRoot
        
        readonly property real dynHeight: Math.max(18, Math.round(height * 0.60))
        readonly property real dynWidth: (root.isCharging || root.batteryPercent <= 30) ? dynHeight * 2.5 : dynHeight * 2.2
        
        implicitWidth: dynWidth + 8
        Layout.preferredWidth: implicitWidth
        Layout.minimumWidth: implicitWidth
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }

        PillBattery {
            anchors.centerIn: parent
            height: compactRoot.dynHeight
            width: compactRoot.dynWidth
            batteryPercent: root.batteryPercent
            isCharging: root.isCharging
            batteryColor: root.batteryColor
            hasBattery: root.hasBattery
        }
        
        // Tooltip intentionally left out
        
        property alias grabTimerRef: grabTimer

        Connections {
            target: root
            function onIsChargingChanged() {
                if (root.isCharging) {
                    root.queueNotification("Battery Status", "Charging Connected", "normal");
                }
            }
        }
        
        Timer {
            id: grabTimer
            interval: 900 // Wait for the 800ms sweep animation to finish
            repeat: false
            onTriggered: {
                compactRoot.grabToImage(function(result) {
                    var path = "/tmp/arcade_battery_icon_" + Date.now() + ".png";
                    result.saveToFile(path);
                    execSource.notify(root.pendingNotifyTitle, root.pendingNotifyMsg, path, root.pendingNotifyUrgency);
                }, Qt.size(compactRoot.width * 3, compactRoot.height * 3));
            }
        }
    }

    // --- POPUP MENU (macOS style) ---
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 300
        spacing: 12

        RowLayout {
            spacing: 12
            Layout.margins: 12
            Layout.bottomMargin: 0
            
            PillBattery {
                Layout.alignment: Qt.AlignVCenter
                height: 24
                width: 48
                batteryPercent: root.batteryPercent
                isCharging: root.isCharging
                batteryColor: root.batteryColor
                hasBattery: root.hasBattery
            }
            
            ColumnLayout {
                spacing: 0
                Text {
                    text: "Battery: " + root.batteryPercent + "%"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#ffffff" // Force white text to contrast dark background
                }
                Text {
                    text: "Power Source: " + (root.isCharging ? "Power Adapter" : "Battery")
                    font.pixelSize: 12
                    color: "#cccccc" // Force light gray for subtitle
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            height: 1
            color: Qt.rgba(1, 1, 1, 0.2) // Force white line
            visible: btDevices.count > 0
        }
        
        // Connected Devices (Bluetooth, Mouse, etc.)
        Repeater {
            model: btDevices
            delegate: Item {
                id: deviceDelegate
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                implicitHeight: 32

                RowLayout {
                    anchors.fill: parent
                    spacing: 8
                    
                    PillBattery {
                        Layout.alignment: Qt.AlignVCenter
                        height: 24
                        width: 48
                        batteryPercent: model.percent
                        isCharging: false
                        batteryColor: "#888888"
                        hasBattery: true
                    }
                    
                    Text {
                        text: model.prettyName
                        font.pixelSize: 14
                        color: "#ffffff" // Force white text
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    
                    Text {
                        text: model.percent + "%"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff" // Force white text
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            height: 1
            color: Qt.rgba(1, 1, 1, 0.2) // Force white line
            visible: pmSource.connectedSources.length > 2
        }

        Button {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.topMargin: 0
            text: "Battery Settings..."
            icon.name: "preferences-system-power-management"
            onClicked: {
                execSource.openSettings();
                root.expanded = false;
            }
        }
    }
}

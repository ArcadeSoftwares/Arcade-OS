import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.coreaddons 1.0 as KCoreAddons

RowLayout {
    id: root
    spacing: 12

    KCoreAddons.KUser {
        id: kuser
    }

    property string userName: kuser.fullName !== "" ? kuser.fullName.split(" ")[0] : kuser.loginName
    property string greeting: {
        var hour = new Date().getHours()
        if (hour < 12) return "Good morning"
        if (hour < 17) return "Good afternoon"
        return "Good evening"
    }

    Rectangle {
        width: 42
        height: 42
        radius: 21
        color: Qt.rgba(0.11, 0.62, 0.46, 1.0)

        Text {
            anchors.centerIn: parent
            text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "A"
            color: "white"
            font.pixelSize: 17
            font.bold: true
        }
    }

    ColumnLayout {
        spacing: 2

        Text {
            text: root.greeting + ", " + root.userName
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }

        Text {
            text: Qt.formatDate(new Date(), "dddd, MMM d")
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 12
        }
    }

    Item { Layout.fillWidth: true }
}

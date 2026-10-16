import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: root
    
    property string cfg_textColor: "#000000"
    property string cfg_chargingTextColor: "#000000"
    property alias cfg_showPercentage: showPercentageField.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        RowLayout {
            Kirigami.FormData.label: "Standard Text Color:"
            spacing: 8
            
            Rectangle {
                width: 24
                height: 24
                color: root.cfg_textColor
                border.color: Kirigami.Theme.textColor
                radius: 4
            }
            Button {
                text: "Choose Color..."
                onClicked: colorDialog1.open()
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Charging Text Color:"
            spacing: 8
            
            Rectangle {
                width: 24
                height: 24
                color: root.cfg_chargingTextColor
                border.color: Kirigami.Theme.textColor
                radius: 4
            }
            Button {
                text: "Choose Color..."
                onClicked: colorDialog2.open()
            }
        }
        
        CheckBox {
            id: showPercentageField
            Kirigami.FormData.label: "Percentage:"
            text: "Show percentage text inside battery"
        }
    }

    ColorDialog {
        id: colorDialog1
        title: "Select Standard Text Color"
        selectedColor: root.cfg_textColor
        onAccepted: root.cfg_textColor = selectedColor
    }

    ColorDialog {
        id: colorDialog2
        title: "Select Charging Text Color"
        selectedColor: root.cfg_chargingTextColor
        onAccepted: root.cfg_chargingTextColor = selectedColor
    }
}
